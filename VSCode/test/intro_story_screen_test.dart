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
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/screens/intro_story_screen.dart';
import 'package:how_predictable/views/screens/world_map_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IntroStoryScreen Assets & Localization', () {
    test('All 4 story intro JPEG assets exist on disk and are non-empty', () {
      for (int i = 1; i <= 4; i++) {
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
      }
    });

    test('All 4 cards, titles, and buttons localize cleanly in en, pt, es, and de', () async {
      final loc = LocalizationService();
      await loc.load();

      final expectedCaptions = <String, List<String>>{
        'en': [
          'A Wizard obsessed with Metal studied human behavior and forged an automaton capable of predicting patterns and conjuring Fire, Water, and Wood.',
          "In the royal garden, the automaton defeated the three guardian mages and kidnapped the Princess to the Metal Wizard's dark fortress.",
          'With no other hope, the King turned to the Sacred Temple and summoned the only young Cleric capable of channeling all three elements.',
          'Armed with your blessed Staff and orb satchel, you march toward the lair—defeat the automaton before time runs out.',
        ],
        'pt': [
          'Um Mago obcecado pelo elemento Metal estudou o comportamento humano e forjou um autômato capaz de prever padrões e conjurar Fogo, Água e Madeira.',
          'No jardim real, o autômato derrotou os três magos guardiões e raptou a Princesa para a fortaleza sombria do Mago de Metal.',
          'Sem saída, o Rei recorreu ao Templo Sagrado e convocou o único jovem Clérigo capaz de canalizar os três elementos.',
          'Com seu Cajado abençoado e sua mochila de orbes, você parte rumo ao covil — vença o autômato antes que o tempo acabe.',
        ],
        'es': [
          'Un Mago obsesionado con el Metal estudió el comportamiento humano y forjó un autómata capaz de predecir patrones y conjurar Fuego, Agua y Madera.',
          'En el jardín real, el autómata derrotó a los tres magos guardianes y secuestró a la Princesa hacia la oscura fortaleza del Mago de Metal.',
          'Sin otra salida, el Rey acudió al Templo Sagrado y convocó al único joven Clérigo capaz de canalizar los tres elementos.',
          'Con tu Báculo bendito y tu mochila de orbes, marchas hacia la guarida: derrota al autómata antes de que se acabe el tiempo.',
        ],
        'de': [
          'Ein vom Metall besessener Zauberer studierte das menschliche Verhalten und schmiedete einen Automaten, der Muster vorhersagt und Feuer, Wasser sowie Holz beschwört.',
          'Im königlichen Garten besiegte der Automat die drei Wächter-Magier und entführte die Prinzessin in die dunkle Festung des Metall-Zauberers.',
          'Ohne anderen Ausweg wandte sich der König an den Heiligen Tempel und rief den einzigen jungen Kleriker, der alle drei Elemente meistert.',
          'Mit deinem gesegneten Stab und deinem Orb-Rucksack ziehst du zur Festung – besiege den Automaten, bevor die Zeit abläuft.',
        ],
      };

      for (final lang in ['en', 'pt', 'es', 'de']) {
        loc.setLanguage(lang);
        expect(loc.t('story_skip'), isNot('story_skip'));
        expect(loc.t('story_next'), isNot('story_next'));
        expect(loc.t('story_begin_quest'), isNot('story_begin_quest'));
        expect(loc.t('story_replay_intro'), isNot('story_replay_intro'));
        expect(loc.t('story_intro_title'), isNot('story_intro_title'));
        expect(loc.t('story_intro_summary'), isNot('story_intro_summary'));
        expect(
          loc.t('story_intro_pages_badge'),
          isNot('story_intro_pages_badge'),
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
      'First launch (hasSeenIntro == false) opens IntroStoryScreen, animates typewriter + tap-to-advance across all 4 cards, persists hasSeenIntro, syncs Cloud Save, and enters WorldMapScreen',
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

        // IntroStoryScreen is open before WorldMapScreen
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.byType(WorldMapScreen), findsNothing);
        expect(find.text('1 / 4'), findsOneWidget);
        expect(find.text('Chapter I'), findsOneWidget);
        expect(find.text('The Metal Automaton'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);

        // Verify 4 page indicator dots are rendered
        for (int i = 0; i < 4; i++) {
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
        expect(find.text('1 / 4'), findsOneWidget);

        // Second tap on dialogue box enters the playable Royal Garden Tutorial Battle
        await tester.tap(find.byKey(const ValueKey('intro_dialogue_box_0')));
        await tester.pump();
        expect(find.byKey(const ValueKey('royal_garden_tutorial_battle')), findsOneWidget);

        // Act 1: Guided Turns 1-3 (Fire -> Water -> Wood)
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
        await tester.pump();

        // Act 2: Play until all 3 mages fall (repeating a pattern so Markov Matrix counters reliably)
        for (int i = 0; i < 60; i++) {
          if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
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

        // Continue from completed tutorial battle into closing Card 2
        if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const ValueKey('tutorial_finish_continue_button')));
          await tester.pump();
        } else {
          await tester.pump(const Duration(milliseconds: 1600));
        }

        expect(find.text('2 / 4'), findsOneWidget);
        expect(find.text('Chapter II'), findsOneWidget);
        expect(find.text('Ambush in the Royal Garden'), findsOneWidget);

        // Tap Next button -> advances to Card 3
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('3 / 4'), findsOneWidget);
        expect(find.text('Chapter III'), findsOneWidget);
        expect(find.text("The King's Summons"), findsOneWidget);

        // Tap Next button -> advances to Card 4 where action button becomes Begin Quest
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('4 / 4'), findsOneWidget);
        expect(find.text('Chapter IV'), findsOneWidget);
        expect(find.text('The Quest Begins'), findsOneWidget);
        expect(find.text('Begin Quest'), findsOneWidget);

        // Tap Begin Quest -> persists hasSeenIntro = true, grants 3 starting orbs, syncs Cloud Save, enters WorldMapScreen at Week 0
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(controller.hasSeenIntro, isTrue);
        expect(storage.hasSeenIntro, isTrue);
        expect(storage.hasSeenStoryIntro, isTrue);
        expect(controller.currentWeek, 0);
        expect(controller.fireOrbs, 1);
        expect(controller.waterOrbs, 1);
        expect(controller.woodOrbs, 1);
        expect(storage.fireOrbs, 1);
        expect(storage.waterOrbs, 1);
        expect(storage.woodOrbs, 1);
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(WorldMapScreen), findsOneWidget);

        final cloud = CloudSaveData.tryParse(fakeClient.savedPayload)!;
        expect(cloud.hasSeenStoryIntro, isTrue);
        expect(cloud.fireOrbs, 1);
        expect(cloud.waterOrbs, 1);
        expect(cloud.woodOrbs, 1);
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
      'Dark Mode and Light Mode render IntroStoryScreen cleanly across compact and standard viewports without overflow',
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

            await tester.pumpWidget(
              ChangeNotifierProvider.value(
                value: controller,
                child: const HowPredictableApp(),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.byType(IntroStoryScreen), findsOneWidget);

            // Verify Light Mode parchment story box & dark ink colors
            final dialogueContainer = tester.widget<Container>(
              find.descendant(
                of: find.byKey(const ValueKey('intro_dialogue_box_0')),
                matching: find.byType(Container),
              ).first,
            );
            final decoration = dialogueContainer.decoration! as BoxDecoration;
            expect(
              decoration.color,
              isDark ? const Color(0xFF161923) : const Color(0xFFF5EFE2),
            );

            final captionText = tester.widget<Text>(
              find.byKey(const ValueKey('intro_caption_text_0')),
            );
            expect(
              captionText.style?.color,
              isDark ? Colors.white : const Color(0xFF231F1A),
            );

            controller.dispose();
          }
        }

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );

    testWidgets(
      'Royal Castle Library consolidates intro into single #1 card (1/9..9/9) that opens the 4-slide IntroStoryScreen carousel, and Replay Intro works identically',
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

        // Unified #1 card is present; old 4 duplicate intro_1..intro_4 list entries are absent
        final introSlot = find.byKey(const ValueKey('story_gallery_item_intro'));
        await tester.ensureVisible(introSlot);
        await tester.pumpAndSettle();
        expect(introSlot, findsOneWidget);
        expect(
          find.byKey(const ValueKey('story_gallery_thumb_intro')),
          findsOneWidget,
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
        expect(find.text('4 Scenes'), findsOneWidget);
        expect(find.text('Read Comic'), findsOneWidget);

        for (int i = 1; i <= 4; i++) {
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

        // Tapping Replay Intro / Tutorial opens IntroStoryScreen at Card 1, and Skip returns to Library
        await tester.ensureVisible(replayIntroBtn);
        await tester.pumpAndSettle();
        await tester.tap(replayIntroBtn);
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.text('1 / 4'), findsOneWidget);
        expect(find.text('The Metal Automaton'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_skip_button')));
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(controller.currentWeek, 3);

        // Tapping the unified #1 Intro card opens Card 1 -> Playable Royal Garden Tutorial Battle -> Cards 2-4
        final readBtn = find.byKey(const ValueKey('story_gallery_read_btn_intro'));
        await tester.ensureVisible(readBtn);
        await tester.pumpAndSettle();
        await tester.tap(readBtn);
        await tester.pumpAndSettle();

        expect(find.byType(IntroStoryScreen), findsOneWidget);
        expect(find.text('1 / 4'), findsOneWidget);
        expect(find.text('The Metal Automaton'), findsOneWidget);

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

        // Play through Act 1 + Act 2 in sandbox replay mode
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_fire')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_water')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('tutorial_move_btn_wood')));
        await tester.pump();

        for (int i = 0; i < 60; i++) {
          if (find.byKey(const ValueKey('royal_garden_tutorial_battle')).evaluate().isEmpty) {
            break;
          }
          if (find.byKey(const ValueKey('tutorial_finish_continue_button')).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(const ValueKey('tutorial_finish_continue_button')));
            await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();

        expect(find.text('2 / 4'), findsOneWidget);
        expect(find.text('Ambush in the Royal Garden'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('3 / 4'), findsOneWidget);
        expect(find.text("The King's Summons"), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.text('4 / 4'), findsOneWidget);
        expect(find.text('The Quest Begins'), findsOneWidget);

        // Begin Quest on slide 4 returns cleanly to Royal Castle Library with ZERO campaign changes
        await tester.tap(find.byKey(const ValueKey('intro_action_button')));
        await tester.pumpAndSettle();
        expect(find.byType(IntroStoryScreen), findsNothing);
        expect(find.byType(RoyalCastleDialog), findsOneWidget);
        expect(controller.currentWeek, 3);
        expect(controller.fireOrbs, 0);
        expect(controller.waterOrbs, 0);
        expect(controller.woodOrbs, 0);

        // Unlocking all 8 artifact chapters brings Story Memories counter to 9 / 9
        for (final chapter in controller.artifactStoryChapters) {
          controller.markStorySeen(chapter);
        }
        await tester.pumpAndSettle();
        expect(find.text('9 / 9'), findsOneWidget);
      },
    );
  });
}
