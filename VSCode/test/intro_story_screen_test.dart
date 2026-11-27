import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/main.dart';
import 'package:how_predictable/models/story_chapter.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/observatory_dialog.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/dialogs/story_gallery_dialog.dart';
import 'package:how_predictable/views/screens/intro_story_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';
import 'package:how_predictable/views/widgets/watch_tower_icon.dart';

class _FakePlayGamesClient implements PlayGamesClient {
  String? savedPayload;
  int saveCount = 0;

  @override
  Future<String?> signIn() async => 'signed_in';

  @override
  Future<String?> getPlayerName() async => 'StoryTester';

  @override
  Future<String?> getPlayerID() async => 'story_tester_1';

  @override
  Future<String?> saveGame({required String data, required String name}) async {
    savedPayload = data;
    saveCount++;
    return 'saved';
  }

  @override
  Future<String?> loadGame({required String name}) async => savedPayload;
}

Future<({
  StorageService storage,
  LocalizationService localization,
  GameController controller,
  _FakePlayGamesClient playGamesClient,
})> _createTestHarness({
  Map<String, Object> prefs = const {},
  bool signInPlayGames = false,
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();

  final localization = LocalizationService();
  await localization.load();
  localization.setLanguage(storage.language);

  final playGamesClient = _FakePlayGamesClient();
  final playGames = PlayGamesService(storage: storage, client: playGamesClient);
  if (signInPlayGames) {
    await playGames.signIn();
  }

  final controller = GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
    playGames: playGames,
  );

  return (
    storage: storage,
    localization: localization,
    controller: controller,
    playGamesClient: playGamesClient,
  );
}

Future<void> _completeRoyalGardenTutorial(WidgetTester tester) async {
  // Act 1: Guided Turns 1-3 (Fire -> Water -> Wood)
  await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
  await tester.pump();

  // Act 2: Play until all 3 mages fall
  for (int i = 0; i < 60; i++) {
    if (find.byKey(const ValueKey('royal_garden_tutorial_battle')).evaluate().isEmpty) {
      break;
    }
    if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('tutorial_finish_continue_button')));
      await tester.pump();
      break;
    }
    for (final key in const [
      'tutorial_move_btn_fire',
      'tutorial_move_btn_water',
      'tutorial_move_btn_wood',
    ]) {
      final finder = find.byKey(ValueKey(key));
      if (finder.evaluate().isEmpty) continue;
      final inkWell = tester.widget<InkWell>(finder);
      if (inkWell.onTap != null) {
        await tester.tap(finder);
        await tester.pump();
        break;
      }
    }
  }

  if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
    await tester.tap(find.byKey(const ValueKey('tutorial_finish_continue_button')));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntroStoryScreen Assets & Localization', () {
    test('All 5 story intro JPEG assets exist on disk, are non-empty, legacy intro_comic is removed, and Prologue cover uses intro_3', () {
      expect(IntroStoryCardData.cards.length, 5);
      for (int i = 1; i <= 5; i++) {
        final file = File('assets/images/story/intro_$i.jpeg');
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Missing assets/images/story/intro_$i.jpeg',
        );
        expect(
          file.lengthSync(),
          greaterThan(10000),
          reason: 'Asset intro_$i.jpeg should be non-empty',
        );
        final bytes = file.readAsBytesSync();
        expect(bytes.sublist(0, 2), [0xFF, 0xD8], reason: 'intro_$i.jpeg must be valid JPEG');
        expect(IntroStoryCardData.cards[i - 1].assetPath, 'assets/images/story/intro_$i.jpeg');
      }

      expect(
        File('assets/images/story/intro_comic.jpeg').existsSync(),
        isFalse,
        reason: 'Obsolete intro_comic.jpeg should be deleted',
      );

      expect(StoryChapter.intro.assetPath, 'assets/images/story/intro_3.jpeg');
    });

    test('All 5 cards, titles, Watch Tower link, and badges localize cleanly in en, pt, es, and de', () async {
      final loc = LocalizationService();
      await loc.load();

      final expectedCaptions = <String, List<String>>{
        'en': [
          "In the peaceful royal garden, the Princess gathered roses under the watchful protection of the realm's three guardian mages.",
          'Suddenly, a ruthless Robot Mage forged from dark metal ambushed the garden, unleashing arcane lightning against the guardians!',
          'With the three guardian mages fallen in battle, the Robot Mage seized the helpless Princess and carried her toward the dark fortress.',
          'Desperate to save his daughter, the King hurried to the Sacred Temple and pleaded for aid, calling upon a young Cleric.',
          "Armed with your blessed Staff, your adventure begins! Before marching into battle, check the Watch Tower to spy on the Princess's cell and see what the Metal Wizard is planning.",
        ],
        'pt': [
          'No pacífico jardim real, a Princesa colhia rosas sob a proteção vigilante dos três magos guardiões do reino.',
          'De repente, um impiedoso Robô Mago forjado em metal sombrio emboscou o jardim, lançando raios arcanos contra os guardiões!',
          'Com os três magos guardiões derrotados em batalha, o Robô Mago capturou a Princesa indefesa e a levou rumo à fortaleza sombria.',
          'Desesperado para salvar sua filha, o Rei correu ao Templo Sagrado e pediu ajuda, convocando um jovem Clérigo.',
          'Empunhando seu Cajado abençoado, sua aventura começa! Antes de partir para a batalha, dê uma olhada na Torre de Vigia para ver a cela da Princesa e o que o Mago de Metal está planejando.',
        ],
        'es': [
          'En el pacífico jardín real, la Princesa recogía rosas bajo la vigilante protección de los tres magos guardianes del reino.',
          'De repente, un despiadado Robot Mago forjado en metal oscuro emboscó el jardín, ¡desatando rayos arcanos contra los guardianes!',
          'Con los tres magos guardianes caídos en batalla, el Robot Mago capturó a la Princesa indefensa y la llevó hacia la fortaleza oscura.',
          'Desesperado por salvar a su hija, el Rey acudió al Templo Sagrado y suplicó ayuda, convocando a un joven Clérigo.',
          'Empuñando tu Báculo bendito, ¡comienza tu aventura! Antes de ir a la batalla, echa un vistazo a la Torre de Vigilancia para ver la celda de la Princesa y lo que planea el Mago de Metal.',
        ],
        'de': [
          'Im friedlichen königlichen Garten pflückte die Prinzessin Rosen unter dem wachsamen Schutz der drei Wächter-Magier.',
          'Plötzlich überfiel ein gnadenloser Roboter-Magier aus dunklem Metall den Garten und entfesselte arkane Blitze gegen die Wächter!',
          'Nachdem die drei Wächter-Magier im Kampf gefallen waren, ergriff der Roboter-Magier die wehrlose Prinzessin und verschleppte sie.',
          'Verzweifelt, seine Tochter zu retten, eilte der König zum Heiligen Tempel, bat um Hilfe und rief einen jungen Kleriker.',
          'Mit deinem gesegneten Stab beginnt dein Abenteuer! Wirf vorher einen Blick in den Wachturm, um die Zelle der Prinzessin zu sehen und zu erfahren, was der Metall-Zauberer plant.',
        ],
      };

      final expectedWatchTowerLink = <String, String>{
        'en': 'Go to Watch Tower',
        'pt': 'Ir para a Torre de Vigia',
        'es': 'Ir a la Torre de Vigilancia',
        'de': 'Zum Wachturm gehen',
      };

      final expectedPagesBadge = <String, String>{
        'en': '5 Scenes',
        'pt': '5 Cenas',
        'es': '5 Escenas',
        'de': '5 Szenen',
      };

      for (final lang in ['en', 'pt', 'es', 'de']) {
        loc.setLanguage(lang);
        expect(loc.t('story_skip'), isNot('story_skip'));
        expect(loc.t('story_next'), isNot('story_next'));
        expect(loc.t('story_begin_quest'), isNot('story_begin_quest'));
        expect(loc.t('story_replay_intro'), isNot('story_replay_intro'));
        expect(loc.t('story_intro_title'), isNot('story_intro_title'));
        expect(loc.t('story_intro_summary'), isNot('story_intro_summary'));
        expect(loc.t('story_intro_pages_badge'), expectedPagesBadge[lang]);
        expect(
          loc.t('story_go_to_watchtower_btn'),
          expectedWatchTowerLink[lang],
        );

        for (int i = 0; i < IntroStoryCardData.cards.length; i++) {
          final card = IntroStoryCardData.cards[i];
          expect(loc.t(card.chapterKey), isNot(card.chapterKey));
          expect(loc.t(card.titleKey), isNot(card.titleKey));
          expect(loc.t(card.captionKey), expectedCaptions[lang]![i]);
        }
      }
    });
  });

  group('IntroStoryScreen Onboarding & Navigation Tests', () {
    testWidgets(
      'First launch opens 5-slide IntroStoryScreen, triggers playable tutorial after Slide 2, resumes at Slides 3-5, shows Watch Tower link only on Slide 5, persists hasSeenIntro, syncs Cloud Save, and enters WorldMapScreen',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {'animationsEnabled': true},
          signInPlayGames: true,
        );
        final controller = harness.controller;
        final storage = harness.storage;
        final fakeClient = harness.playGamesClient;
        addTearDown(controller.dispose);

        expect(controller.hasSeenIntro, isFalse);
        expect(storage.hasSeenIntro, isFalse);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pump();

        // Slide 1 (intro_1)
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.byType(WorldMapScreen), findsNothing);
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('Chapter I'), findsOneWidget);
        expect(find.text('The Royal Garden'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
          findsNothing,
        );

        // Verify 5 page indicator dots are rendered
        for (int i = 0; i < 5; i++) {
          expect(find.byKey(ValueKey('intro_page_dot_$i')), findsOneWidget);
        }

        // Typewriter reveal starts partial and progresses over 25ms ticks
        final caption0Finder = find.byKey(
          const ValueKey('intro_caption_text_0'),
        );
        final initialText = tester.widget<Text>(caption0Finder).data!;
        final fullCard1Text = IntroStoryCardData.cards[0].fallbackCaption;
        expect(initialText.length, lessThan(fullCard1Text.length));

        await tester.pump(const Duration(milliseconds: 125));
        final midText = tester.widget<Text>(caption0Finder).data!;
        expect(midText.length, greaterThan(initialText.length));
        expect(midText.length, lessThan(fullCard1Text.length));

        // First tap on dialogue box reveals the full text immediately without advancing
        await tester.tap(find.byKey(const ValueKey('intro_dialogue_box_0')));
        await tester.pump();
        expect(tester.widget<Text>(caption0Finder).data, fullCard1Text);
        expect(find.text('1 / 5'), findsOneWidget);

        // Second tap on dialogue box advances to Slide 2 (intro_2)
        await tester.tap(find.byKey(const ValueKey('intro_dialogue_box_0')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('2 / 5'), findsOneWidget);
        expect(find.text('Chapter II'), findsOneWidget);
        expect(find.text('Ambush in the Royal Garden'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
          findsNothing,
        );

        // Advancing past Slide 2 launches the playable Royal Garden Tutorial Battle
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        expect(
          find.byKey(const ValueKey('royal_garden_tutorial_battle')),
          findsOneWidget,
        );

        await _completeRoyalGardenTutorial(tester);
        await tester.pump(const Duration(milliseconds: 1600));

        // Resumes seamlessly at Slide 3 (intro_3)
        expect(find.text('3 / 5'), findsOneWidget);
        expect(find.text('Chapter III'), findsOneWidget);
        expect(find.text('The Princess Captured'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
          findsNothing,
        );

        // Tap Next -> Slide 4 (intro_4)
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('4 / 5'), findsOneWidget);
        expect(find.text('Chapter IV'), findsOneWidget);
        expect(find.text("The King's Summons"), findsOneWidget);
        expect(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
          findsNothing,
        );

        // Tap Next -> Slide 5 (intro_5) where Begin Quest + Go to Watch Tower appear
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('5 / 5'), findsOneWidget);
        expect(find.text('Chapter V'), findsOneWidget);
        expect(find.text('The Quest Begins'), findsOneWidget);
        expect(find.text('Begin Quest'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
          findsOneWidget,
        );
        expect(find.text('Go to Watch Tower'), findsOneWidget);

        // Tap Begin Quest -> persists hasSeenIntro = true, grants orbs, syncs Cloud Save, enters WorldMapScreen at Week 0
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.hasSeenIntro, isTrue);
        expect(storage.hasSeenIntro, isTrue);
        expect(storage.hasSeenStoryIntro, isTrue);
        expect(controller.currentWeek, 0);
        expect(controller.fireOrbs, greaterThanOrEqualTo(1));
        expect(controller.waterOrbs, greaterThanOrEqualTo(1));
        expect(controller.woodOrbs, greaterThanOrEqualTo(1));
        expect(storage.fireOrbs, controller.fireOrbs);
        expect(storage.waterOrbs, controller.waterOrbs);
        expect(storage.woodOrbs, controller.woodOrbs);
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(WatchTowerDialog), findsNothing);

        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.hasSeenStoryIntro, isTrue);
        expect(cloud.fireOrbs, controller.fireOrbs);
        expect(cloud.waterOrbs, controller.waterOrbs);
        expect(cloud.woodOrbs, controller.woodOrbs);
      },
    );

    testWidgets(
      'Tapping "Go to Watch Tower" on Slide 5 on first launch persists hasSeenIntro, syncs Cloud Save, navigates to WorldMapScreen, and immediately opens WatchTowerDialog',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {'animationsEnabled': false},
          signInPlayGames: true,
        );
        final controller = harness.controller;
        final storage = harness.storage;
        final fakeClient = harness.playGamesClient;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Slide 1 -> Slide 2 -> Tutorial -> Skip tutorial -> Slide 3 -> Slide 4 -> Slide 5
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('royal_garden_tutorial_battle')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();
        expect(find.text('3 / 5'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('5 / 5'), findsOneWidget);

        final watchTowerLink = find.byKey(
          const ValueKey('intro_go_to_watchtower_button'),
        );
        expect(watchTowerLink, findsOneWidget);
        expect(
          find.descendant(
            of: watchTowerLink,
            matching: find.byType(WatchTowerIcon),
          ),
          findsOneWidget,
        );
        expect(tester.getSize(watchTowerLink).height, greaterThanOrEqualTo(40));

        await tester.tap(watchTowerLink);
        await tester.pumpAndSettle();

        expect(controller.hasSeenIntro, isTrue);
        expect(storage.hasSeenIntro, isTrue);
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(WatchTowerDialog), findsOneWidget);

        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.hasSeenStoryIntro, isTrue);
      },
    );

    testWidgets(
      'Tapping Skip on IntroStoryScreen persists hasSeenIntro = true and transitions straight to WorldMapScreen',
      (WidgetTester tester) async {
        final harness = await _createTestHarness(
          prefs: {'animationsEnabled': false},
          signInPlayGames: true,
        );
        final controller = harness.controller;
        final storage = harness.storage;
        final fakeClient = harness.playGamesClient;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.byType(WorldMapScreen), findsNothing);

        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();

        expect(controller.hasSeenIntro, isTrue);
        expect(storage.hasSeenIntro, isTrue);
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);

        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.hasSeenStoryIntro, isTrue);
      },
    );

    testWidgets(
      'Subsequent launches (hasSeenIntro == true) and Week 0 campaign resets bypass IntroStoryScreen and open WorldMapScreen directly',
      (WidgetTester tester) async {
        final harness = await _createTestHarness(
          prefs: {
            'has_seen_story_intro': true,
            'animationsEnabled': false,
            'current_week': 5,
          },
        );
        final controller = harness.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);

        // Permadeath Week 0 reset keeps hasSeenIntro == true
        await controller.applyPermadeathReset();
        await tester.pumpAndSettle();

        expect(controller.currentWeek, 0);
        expect(controller.hasSeenIntro, isTrue);
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
      },
    );
  });

  group('IntroStoryScreen Dark & Light Theme and Royal Library Integration', () {
    testWidgets(
      'Dark Mode and Light Mode render all 5 IntroStoryScreen slides (including Slide 5 Watch Tower link) cleanly across compact and standard viewports without overflow',
      (WidgetTester tester) async {
        for (final isDark in [true, false]) {
          for (final viewport in [
            const Size(360, 640),
            const Size(390, 844),
          ]) {
            tester.view.physicalSize = viewport;
            tester.view.devicePixelRatio = 1.0;

            final harness = await _createTestHarness(
              prefs: {
                'darkMode': isDark,
                'animationsEnabled': false,
              },
            );
            final controller = harness.controller;

            for (int slideIndex = 0; slideIndex < 5; slideIndex++) {
              await tester.pumpWidget(
                ChangeNotifierProvider.value(
                  value: controller,
                  child: HowPredictableApp(
                    home: IntroStoryScreen(
                      key: ValueKey('theme_${isDark}_${viewport.width}_$slideIndex'),
                      initialPage: slideIndex,
                      isReplay: true,
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              expect(tester.takeException(), isNull);
              expect(find.byType(IntroStoryScreen), findsOneWidget);
              expect(find.text('${slideIndex + 1} / 5'), findsOneWidget);
              expect(
                find.byKey(ValueKey('intro_artwork_image_intro_${slideIndex + 1}')),
                findsOneWidget,
              );

              final dialogueContainer = tester.widget<Container>(
                find.descendant(
                  of: find.byKey(ValueKey('intro_dialogue_box_$slideIndex')),
                  matching: find.byType(Container),
                ).first,
              );
              final decoration = dialogueContainer.decoration! as BoxDecoration;
              expect(
                decoration.color,
                isDark ? const Color(0xFF161923) : const Color(0xFFF5EFE2),
              );

              final captionText = tester.widget<Text>(
                find.byKey(ValueKey('intro_caption_text_$slideIndex')),
              );
              expect(
                captionText.style?.color,
                isDark ? Colors.white : const Color(0xFF231F1A),
              );

              // Go to Watch Tower link button appears ONLY on Slide 5
              expect(
                find.byKey(const ValueKey('intro_go_to_watchtower_button')),
                slideIndex == 4 ? findsOneWidget : findsNothing,
              );
            }

            controller.dispose();
          }
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Royal Castle Library #1 Prologue card uses intro_3 thumbnail, shows 5 Scenes badge, launches full 5-slide prologue, and Slide 5 Go to Watch Tower opens WatchTowerDialog cleanly',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final harness = await _createTestHarness(
          prefs: {
            'has_seen_story_intro': true,
            'animationsEnabled': false,
            'current_week': 3,
          },
        );
        final controller = harness.controller;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: const HowPredictableApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Open Royal Castle -> Library wing
        await tester.tap(find.byKey(const ValueKey('landmark_royal_castle')));
        await tester.pumpAndSettle();
        expect(find.byType(RoyalCastleDialog), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('castle_tab_library')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('castle_wing_library')), findsOneWidget);

        // Verify 1 / 9 Story Memories unlocked (unified #1 Intro card)
        expect(find.text('1 / 9'), findsOneWidget);

        final replayIntroBtn = find.byKey(
          const ValueKey('library_replay_intro_button'),
        );
        await tester.ensureVisible(replayIntroBtn);
        await tester.pumpAndSettle();
        expect(replayIntroBtn, findsOneWidget);
        expect(find.text('Replay Intro / Tutorial'), findsOneWidget);

        // Unified #1 card uses intro_3.jpeg thumbnail and displays "5 Scenes" badge
        final introSlot = find.byKey(const ValueKey('story_gallery_item_intro'));
        await tester.ensureVisible(introSlot);
        await tester.pumpAndSettle();
        expect(introSlot, findsOneWidget);

        final thumbFinder = find.byKey(const ValueKey('story_gallery_thumb_intro'));
        expect(thumbFinder, findsOneWidget);
        final thumbImage = tester.widget<Image>(
          find.descendant(of: thumbFinder, matching: find.byType(Image)),
        );
        expect(
          (thumbImage.image as AssetImage).assetName,
          'assets/images/story/intro_3.jpeg',
        );

        expect(
          find.byKey(const ValueKey('story_gallery_badge_intro')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('story_gallery_read_btn_intro')),
          findsOneWidget,
        );
        expect(find.text('#1'), findsOneWidget);
        expect(find.text("Prologue: The Metal Wizard's Plot"), findsOneWidget);
        expect(find.text('5 Scenes'), findsOneWidget);
        expect(find.text('Read Comic'), findsOneWidget);

        for (int i = 1; i <= 5; i++) {
          expect(
            find.byKey(ValueKey('story_gallery_item_intro_$i')),
            findsNothing,
          );
        }

        // Remaining 8 artifact chapters are numbered #2..#9
        for (int n = 2; n <= 9; n++) {
          expect(find.text('#$n'), findsOneWidget);
        }
        expect(find.text('#10'), findsNothing);

        // Tapping Replay Intro / Tutorial opens IntroStoryScreen at Slide 1, and Skip returns to Library
        await tester.ensureVisible(replayIntroBtn);
        await tester.pumpAndSettle();
        await tester.tap(replayIntroBtn);
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('The Royal Garden'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(controller.currentWeek, 3);

        // Tapping unified #1 Intro card opens Slides 1 -> 2 -> Playable Tutorial -> Slides 3 -> 4 -> 5
        final readBtn = find.byKey(const ValueKey('story_gallery_read_btn_intro'));
        await tester.ensureVisible(readBtn);
        await tester.pumpAndSettle();
        await tester.tap(readBtn);
        await tester.pumpAndSettle();

        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.text('1 / 5'), findsOneWidget);
        expect(find.text('The Royal Garden'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('2 / 5'), findsOneWidget);
        expect(find.text('Ambush in the Royal Garden'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('royal_garden_tutorial_battle')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('tutorial_sandbox_badge')),
          findsOneWidget,
        );

        await _completeRoyalGardenTutorial(tester);
        await tester.pumpAndSettle();

        expect(find.text('3 / 5'), findsOneWidget);
        expect(find.text('The Princess Captured'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('4 / 5'), findsOneWidget);
        expect(find.text("The King's Summons"), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('5 / 5'), findsOneWidget);
        expect(find.text('The Quest Begins'), findsOneWidget);

        // Begin Quest on Slide 5 returns cleanly to Royal Castle Library with ZERO campaign changes
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(controller.currentWeek, 3);
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);

        // Re-open #1 Prologue, advance to Slide 5 (skipping tutorial), and tap "Go to Watch Tower"
        await tester.ensureVisible(readBtn);
        await tester.pumpAndSettle();
        await tester.tap(readBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();
        expect(find.text('3 / 5'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('5 / 5'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('intro_go_to_watchtower_button')),
        );
        await tester.pumpAndSettle();

        // Closes replay modal stack cleanly and opens WatchTowerDialog on WorldMapScreen
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(RoyalCastleDialog), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);
        expect(find.byType(WatchTowerDialog), findsOneWidget);
        expect(controller.currentWeek, 3);
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);

        // Open Story Log inside WatchTowerDialog -> verifies #1 Prologue card uses intro_3 & 5 Scenes
        final storyLogBtn = find.byKey(const ValueKey('observatory_story_log_button'));
        if (storyLogBtn.evaluate().isNotEmpty) {
          await tester.ensureVisible(storyLogBtn);
          await tester.pumpAndSettle();
          await tester.tap(storyLogBtn);
          await tester.pumpAndSettle();
          expect(find.byType(StoryGalleryDialog), findsOneWidget);
          expect(find.text('5 Scenes'), findsOneWidget);
          final galleryThumb = tester.widget<Image>(
            find.descendant(
              of: find.byKey(const ValueKey('story_gallery_thumb_intro')),
              matching: find.byType(Image),
            ),
          );
          expect(
            (galleryThumb.image as AssetImage).assetName,
            'assets/images/story/intro_3.jpeg',
          );
        }
      },
    );
  });
}
