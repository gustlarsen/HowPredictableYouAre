import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedEnDescriptions = <String, String>{
    'predictability_score_desc':
        'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
    'reset_button_desc':
        'Adds a Reset button to clear the current match and Markov matrix anytime',
    'new_hands_desc':
        'Unlocks Earth & Metal in your move deck and deals bonus damage to the Phase 2 boss. Earn Earth & Metal orbs by defeating them in Phase 2.',
    'random_button_desc':
        'Adds a Random button to play unpredictable moves and outsmart the AI',
    'show_algorithm_desc':
        'Reveals the live Markov Transition Matrix tracking your move patterns',
    'your_prediction_desc':
        'Displays the move(s) the AI predicts you will play next',
    'pc_next_move_desc':
        'Reveals the move(s) the AI is preparing to play against you',
    'gift_box_desc':
        'Unlocks a periodic 🎁 gift chest on the top bar granting +5 orbs of every element',
    'suggestion_desc':
        "Recommends the optimal counter-move(s) to beat the AI's next play",
    'remove_ads_desc':
        'Removes all banner and video ad prompts across the entire app',
    'new_skin_desc': 'Hands Theme (Rock, Paper, Scissors)',
    'crystal_ball_desc':
        'Reveals the exact next move the AI will play before you choose',
    'crystal_ball_plus_desc':
        'Upgrades Crystal Ball to guarantee 100% foresight on every single round',
  };

  testWidgets(
    'All 13 ShopDialog items display warm amber/gold descriptive subtitles in locked and unlocked states across en, pt, es, and de without mid-word breaks',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        // Unlock Crystal Ball so Crystal Ball+ is also visible in the ShopDialog
        'unlockedCrystalBall': true,
        'showCrystalBall': true,
        'animationsEnabled': false,
        'musicEnabled': false,
      });

      final storage = StorageService();
      await storage.init();
      final localization = LocalizationService();
      await tester.runAsync(() => localization.load());
      final audio = AudioService();

      final controller = GameController(
        storage: storage,
        localization: localization,
        audio: audio,
      );
      addTearDown(controller.dispose);

      // 1. Verify all 13 keys exist and are non-empty translations in all 4 languages
      for (final lang in LocalizationService.supportedLanguages) {
        localization.setLanguage(lang);
        for (final key in expectedEnDescriptions.keys) {
          final translated = localization.t(key);
          expect(translated, isNotEmpty, reason: 'Missing $lang $key');
          expect(translated, isNot(key), reason: 'Fallback key returned for $lang $key');
          if (lang != 'en') {
            expect(
              translated,
              isNot(expectedEnDescriptions[key]),
              reason: 'Untranslated $lang $key',
            );
          }
        }
      }
      localization.setLanguage('en');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: ShopDialog(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      );

      // Helper to verify every shop subtitle in the current language renders,
      // uses amber/gold color + softWrap, and never splits a token mid-word.
      Future<void> verifyAllSubtitlesForLanguage(String lang) async {
        controller.setLanguage(lang);
        await tester.pumpAndSettle();

        // Reset scroll to top before scanning downward
        tester.state<ScrollableState>(scrollableFinder).position.jumpTo(0);
        await tester.pumpAndSettle();

        for (final key in expectedEnDescriptions.keys) {
          final expectedText = localization.t(key);
          final textFinder = find.text(expectedText);

          await tester.scrollUntilVisible(
            textFinder,
            180,
            scrollable: scrollableFinder,
          );
          await tester.pumpAndSettle();

          expect(
            textFinder,
            findsOneWidget,
            reason: 'Expected subtitle for $key ($lang): "$expectedText"',
          );

          final textWidget = tester.widget<Text>(textFinder);
          expect(textWidget.softWrap, isTrue);
          expect(textWidget.style?.fontSize, 11);
          expect(
            textWidget.style?.color,
            Colors.amber.withValues(alpha: 0.85),
          );

          // Ensure no single token (split by whitespace or hyphens) breaks mid-word
          final paragraph = tester.renderObject<RenderParagraph>(textFinder);
          int searchOffset = 0;
          for (final segment in expectedText.split(RegExp(r'[\s\-]+'))) {
            if (segment.isEmpty) continue;
            final start = expectedText.indexOf(segment, searchOffset);
            expect(start, greaterThanOrEqualTo(0));
            searchOffset = start + segment.length;
            final boxes = paragraph.getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: start + segment.length),
            );
            final lineTops = boxes.map((b) => b.top.round()).toSet();
            expect(
              lineTops.length,
              1,
              reason:
                  'Token "$segment" in $key ($lang) broke across multiple lines: $lineTops',
            );
          }
        }
      }

      // Check English exact strings and layout
      for (final entry in expectedEnDescriptions.entries) {
        expect(localization.t(entry.key), entry.value);
      }

      for (final lang in LocalizationService.supportedLanguages) {
        await verifyAllSubtitlesForLanguage(lang);
      }

      // 2. Also verify Crystal Ball (which is unlocked above) displays its subtitle in unlocked state
      controller.setLanguage('en');
      await tester.pumpAndSettle();
      final cbFinder = find.text(expectedEnDescriptions['crystal_ball_desc']!);
      await tester.scrollUntilVisible(cbFinder, 180, scrollable: scrollableFinder);
      await tester.pumpAndSettle();
      expect(cbFinder, findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );
}
