import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/story_gallery_dialog.dart';
import 'package:how_predictable/views/screens/intro_story_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Story Memories Cleanup & Legacy Asset Removal', () {
    testWidgets(
      'Royal Castle Library Story Memories displays only #1 Prologue (1 / 1) even with all artifacts unlocked and opens 5-slide carousel',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'animationsEnabled': false,
          'musicEnabled': false,
          'soundEnabled': false,
          // Unlock all 8 shop artifacts to confirm no legacy chapters reappear
          'unlockedReset': true,
          'unlockedPredictability': true,
          'unlockedRandom': true,
          'unlockedAlgorithm': true,
          'unlockedYourPrediction': true,
          'unlockedNextMove': true,
          'unlockedSuggestion': true,
          'unlockedCrystalBall': true,
        });

        final storage = StorageService();
        await storage.init();
        final localization = LocalizationService();
        await tester.runAsync(() => localization.load());

        final controller = GameController(
          storage: storage,
          localization: localization,
          audio: AudioService(),
        );
        addTearDown(controller.dispose);

        expect(StoryChapter.values, const [StoryChapter.intro]);
        expect(controller.totalStoryMemoriesCount, 1);
        expect(controller.unlockedStoryMemoriesCount, 1);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) =>
                            RoyalCastleDialog(controller: controller),
                      );
                    },
                    child: const Text('Open Castle'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Castle'));
        await tester.pumpAndSettle();
        expect(find.byType(RoyalCastleDialog), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('castle_tab_library')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('castle_wing_library')), findsOneWidget);

        // Header counter displays 1 / 1 (not 9 / 9 or 1 / 9)
        final counterBadge = find.byKey(
          const ValueKey('library_story_memories_counter'),
        );
        await tester.ensureVisible(counterBadge);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: counterBadge, matching: find.text('1 / 1')),
          findsOneWidget,
        );
        expect(find.text('9 / 9'), findsNothing);
        expect(find.text('1 / 9'), findsNothing);

        // Exactly 1 StoryChapterCard rendered: #1 Prologue: The Metal Wizard's Plot
        expect(find.byType(StoryChapterCard), findsOneWidget);
        final introItem = find.byKey(
          const ValueKey('story_gallery_item_intro'),
        );
        await tester.ensureVisible(introItem);
        await tester.pumpAndSettle();
        expect(introItem, findsOneWidget);
        expect(find.text('#1'), findsOneWidget);
        expect(find.text("Prologue: The Metal Wizard's Plot"), findsOneWidget);
        expect(find.text('5 Scenes'), findsOneWidget);

        final thumbImage = tester.widget<Image>(
          find.descendant(
            of: find.byKey(const ValueKey('story_gallery_thumb_intro')),
            matching: find.byType(Image),
          ),
        );
        expect(
          (thumbImage.image as AssetImage).assetName,
          'assets/images/story/intro_3.jpeg',
        );

        // Verify none of the 8 removed legacy chapters appear
        for (final removedId in const [
          'reset',
          'predictability',
          'random',
          'algorithm',
          'your_prediction',
          'pc_next_move',
          'suggestion',
          'crystal_ball',
        ]) {
          expect(
            find.byKey(ValueKey('story_gallery_item_$removedId')),
            findsNothing,
          );
          expect(
            find.byKey(ValueKey('story_gallery_locked_$removedId')),
            findsNothing,
          );
        }
        for (int n = 2; n <= 9; n++) {
          expect(find.text('#$n'), findsNothing);
        }

        // Tapping the #1 Prologue card launches the 5-slide prologue carousel
        await tester.tap(introItem);
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('The Royal Garden'), findsOneWidget);
      },
    );

    test(
      'Obsolete legacy memory keys in local SharedPreferences and Cloud Save JSON are safely ignored and pruned on load',
      () async {
        // 1. Seed local SharedPreferences with all 8 obsolete legacy story keys
        SharedPreferences.setMockInitialValues({
          'has_seen_story_intro': true,
          'has_seen_story_reset': true,
          'has_seen_story_predictability': true,
          'has_seen_story_random': true,
          'has_seen_story_algorithm': true,
          'has_seen_story_your_prediction': true,
          'has_seen_story_pc_next_move': true,
          'has_seen_story_suggestion': true,
          'has_seen_story_crystal_ball': true,
          'unlockedReset': true,
          'unlockedCrystalBall': true,
          'musicEnabled': false,
        });

        final storage = StorageService();
        await storage.init();

        // Active Prologue flag and shop artifact unlocks survive intact
        expect(storage.hasSeenStoryIntro, isTrue);
        expect(storage.unlockedReset, isTrue);
        expect(storage.unlockedCrystalBall, isTrue);

        // All 8 obsolete legacy story preference keys were pruned on init()
        final prefs = await SharedPreferences.getInstance();
        for (final key in StorageService.obsoleteLegacyStoryPrefsKeys) {
          expect(
            prefs.containsKey(key),
            isFalse,
            reason: 'Expected obsolete key $key to be pruned on init()',
          );
        }

        // 2. Deserialize a legacy Google Play Games Cloud Save JSON containing all 8 obsolete fields
        final legacyCloudPayload = jsonEncode({
          'version': 1,
          'fireOrbs': 250,
          'waterOrbs': 200,
          'woodOrbs': 150,
          'unlockedReset': true,
          'unlockedPredictability': true,
          'unlockedCrystalBall': true,
          'hasSeenStoryIntro': true,
          'hasSeenStoryReset': true,
          'hasSeenStoryPredictability': true,
          'hasSeenStoryRandom': true,
          'hasSeenStoryAlgorithm': true,
          'hasSeenStoryYourPrediction': true,
          'hasSeenStoryPcNextMove': true,
          'hasSeenStorySuggestion': true,
          'hasSeenStoryCrystalBall': true,
          'unlockedStoryMemories': [
            'intro',
            'reset',
            'predictability',
            'crystal_ball',
          ],
        });

        final parsed = CloudSaveData.tryParse(legacyCloudPayload);
        expect(parsed, isNotNull);
        expect(parsed!.hasSeenStoryIntro, isTrue);
        expect(parsed.unlockedReset, isTrue);
        expect(parsed.unlockedPredictability, isTrue);
        expect(parsed.unlockedCrystalBall, isTrue);
        expect(parsed.fireOrbs, 250);

        // Re-serializing omits all obsolete legacy comic keys
        final reserializedMap = parsed.toJson();
        expect(reserializedMap['hasSeenStoryIntro'], isTrue);
        for (final obsoleteCloudKey in const [
          'hasSeenStoryReset',
          'hasSeenStoryPredictability',
          'hasSeenStoryRandom',
          'hasSeenStoryAlgorithm',
          'hasSeenStoryYourPrediction',
          'hasSeenStoryPcNextMove',
          'hasSeenStorySuggestion',
          'hasSeenStoryCrystalBall',
        ]) {
          expect(
            reserializedMap.containsKey(obsoleteCloudKey),
            isFalse,
            reason: 'Obsolete cloud key $obsoleteCloudKey must not be emitted',
          );
        }

        // Applying legacy cloud data to storage keeps active state and prunes stale keys
        await parsed.applyToStorage(storage);
        final controller = GameController(
          storage: storage,
          localization: LocalizationService(),
          audio: AudioService(),
        );
        addTearDown(controller.dispose);
        expect(controller.hasSeenStoryIntro, isTrue);
        expect(controller.unlockedReset, isTrue);
        expect(controller.unlockedPredictability, isTrue);
        expect(controller.unlockedCrystalBall, isTrue);
        expect(controller.totalStoryMemoriesCount, 1);
        expect(controller.unlockedStoryMemoriesCount, 1);
      },
    );

    test(
      'All assets declared in pubspec.yaml and referenced in lib/ exist on disk, legacy comic assets are deleted, and localization keys are clean',
      () {
        // 1. Verify every declared asset file/directory in pubspec.yaml exists on disk
        final pubspecLines = File('pubspec.yaml').readAsLinesSync();
        bool inAssetsBlock = false;
        final declaredAssets = <String>[];
        for (final rawLine in pubspecLines) {
          final trimmed = rawLine.trim();
          if (trimmed == 'assets:') {
            inAssetsBlock = true;
            continue;
          }
          if (inAssetsBlock) {
            if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
            if (!rawLine.startsWith('    ') && !trimmed.startsWith('- ')) {
              inAssetsBlock = false;
              continue;
            }
            if (trimmed.startsWith('- ')) {
              declaredAssets.add(trimmed.substring(2).trim());
            }
          }
        }
        expect(declaredAssets, isNotEmpty);
        for (final entry in declaredAssets) {
          if (entry.endsWith('/')) {
            expect(
              Directory(entry).existsSync(),
              isTrue,
              reason: 'Declared asset directory $entry does not exist on disk',
            );
          } else {
            final f = File(entry);
            expect(
              f.existsSync(),
              isTrue,
              reason: 'Declared asset file $entry does not exist on disk',
            );
            expect(
              f.lengthSync(),
              greaterThan(0),
              reason: 'Declared asset file $entry is empty',
            );
          }
        }

        // 2. Verify every literal assets/images/... path in lib/**/*.dart exists on disk
        final assetPattern = RegExp(
          r'''['"](assets/images/[A-Za-z0-9_./-]+\.(?:png|jpe?g|webp|gif))['"]''',
        );
        final referencedImages = <String>{};
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            final content = entity.readAsStringSync();
            for (final match in assetPattern.allMatches(content)) {
              referencedImages.add(match.group(1)!);
            }
          }
        }
        expect(referencedImages, isNotEmpty);
        for (final imgPath in referencedImages) {
          final f = File(imgPath);
          expect(
            f.existsSync(),
            isTrue,
            reason: 'Image asset referenced in Dart code is missing: $imgPath',
          );
          expect(
            f.lengthSync(),
            greaterThan(0),
            reason: 'Image asset referenced in Dart code is empty: $imgPath',
          );
        }

        // 3. Verify assets/images/story/ contains only the 5 prologue slides + active robot_mage_cliff.webp
        final storyFiles = Directory('assets/images/story')
            .listSync()
            .whereType<File>()
            .map((f) => f.uri.pathSegments.last)
            .toSet();
        expect(
          storyFiles,
          equals({
            'intro_1.jpeg',
            'intro_2.jpeg',
            'intro_3.jpeg',
            'intro_4.jpeg',
            'intro_5.jpeg',
            'robot_mage_cliff.webp',
          }),
        );

        // 4. Verify stringsHowPredict.json retains #1 Prologue keys in en/pt/es/de and removes Chapters I-VIII keys
        final stringsMap = jsonDecode(
          File('assets/data/stringsHowPredict.json').readAsStringSync(),
        ) as Map<String, dynamic>;

        for (final lang in const ['en', 'pt', 'es', 'de']) {
          for (final activeKey in const [
            'story_intro_title',
            'story_intro_summary',
            'story_intro_pages_badge',
            'story_intro_c1_chapter',
            'story_intro_c1_title',
            'story_intro_c1_caption',
            'story_intro_c2_chapter',
            'story_intro_c2_title',
            'story_intro_c2_caption',
            'story_intro_c3_chapter',
            'story_intro_c3_title',
            'story_intro_c3_caption',
            'story_intro_c4_chapter',
            'story_intro_c4_title',
            'story_intro_c4_caption',
            'story_intro_c5_chapter',
            'story_intro_c5_title',
            'story_intro_c5_caption',
          ]) {
            expect(
              stringsMap.containsKey('${lang}_$activeKey'),
              isTrue,
              reason: 'Missing active Prologue key ${lang}_$activeKey',
            );
          }

          for (final removedPrefix in const [
            'story_reset_',
            'story_predictability_',
            'story_random_',
            'story_algorithm_',
            'story_your_prediction_',
            'story_pc_next_move_',
            'story_suggestion_',
            'story_crystal_ball_',
          ]) {
            final staleKeys = stringsMap.keys.where(
              (k) => k.startsWith('${lang}_$removedPrefix'),
            );
            expect(
              staleKeys,
              isEmpty,
              reason: 'Found obsolete localization keys: $staleKeys',
            );
          }
        }
      },
    );
  });
}
