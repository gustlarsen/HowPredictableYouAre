import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/widgets/elemental_energy_sphere.dart';
import 'package:how_predictable/views/widgets/elemental_symbol_icon.dart';
import 'package:how_predictable/views/widgets/shop_item_icons.dart';
import 'package:how_predictable/views/widgets/temple_wing_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedEnOfferingsDescriptions = <String, String>{
    'predictability_score_desc':
        'Unlocks Match Scoreboard (Your Score, PC Score, Total) & Predictability Gauge %',
    'reset_button_desc':
        'Adds a Reset button to clear the current match and Markov matrix anytime',
    'new_hands_desc':
        'Unlocks Earth & Metal elements for an expanded 5-element battle matrix',
    'random_button_desc':
        'Adds a Random button to play unpredictable moves and outsmart the AI',
    'show_algorithm_desc':
        'Reveals the live Markov Transition Matrix tracking your move patterns',
    'your_prediction_desc':
        'Displays the move(s) the AI predicts you will play next',
    'pc_next_move_desc':
        'Reveals the move(s) the AI is preparing to play against you',
    'gift_box_desc_main':
        'Unlocks a periodic 🎁 gift chest on the top bar granting +5 Fire, Water & Wood orbs',
    'suggestion_desc':
        "Recommends the optimal counter-move(s) to beat the AI's next play",
    'new_skin_desc': 'Hands Theme (Rock, Paper, Scissors)',
    'crystal_ball_desc':
        'Reveals the exact next move the AI will play before you choose',
    'crystal_ball_plus_desc':
        'Upgrades Crystal Ball to guarantee 100% foresight on every single round',
  };

  const expectedEnPrayerDescriptions = <String, String>{
    'vow_of_silence_locked_desc':
        'Permanently silences all banner and video ad prompts across the entire app. Never resets across journeys.',
  };

  testWidgets(
    'All Sacred Temple Offerings & Vow of Silence items display warm amber/gold descriptive subtitles across en, pt, es, and de without mid-word breaks',
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

      // 1. Verify all keys exist and are non-empty translations in all 4 languages
      final allExpectedEn = {
        ...expectedEnOfferingsDescriptions,
        ...expectedEnPrayerDescriptions,
      };
      for (final lang in LocalizationService.supportedLanguages) {
        localization.setLanguage(lang);
        for (final key in allExpectedEn.keys) {
          final translated = localization.t(key);
          expect(translated, isNotEmpty, reason: 'Missing $lang $key');
          expect(
            translated,
            isNot(key),
            reason: 'Fallback key returned for $lang $key',
          );
          if (lang != 'en') {
            expect(
              translated,
              isNot(allExpectedEn[key]),
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

      Future<void> verifyTextSubtitles(
        String lang,
        Iterable<String> keys,
      ) async {
        final scrollableFinder = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );
        tester.state<ScrollableState>(scrollableFinder).position.jumpTo(0);
        await tester.pumpAndSettle();

        for (final key in keys) {
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
              TextSelection(
                baseOffset: start,
                extentOffset: start + segment.length,
              ),
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
      for (final entry in allExpectedEn.entries) {
        expect(localization.t(entry.key), entry.value);
      }

      for (final lang in LocalizationService.supportedLanguages) {
        controller.setLanguage(lang);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
        await tester.pumpAndSettle();
        await verifyTextSubtitles(lang, expectedEnOfferingsDescriptions.keys);

        await tester.tap(find.byKey(const ValueKey('temple_tab_prayer')));
        await tester.pumpAndSettle();
        await verifyTextSubtitles(lang, expectedEnPrayerDescriptions.keys);
      }

      // 2. Also verify Crystal Ball (which is unlocked above) displays its subtitle in unlocked state
      controller.setLanguage('en');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('temple_tab_offerings')));
      await tester.pumpAndSettle();
      final scrollableFinder = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      );
      final cbFinder = find.text(
        expectedEnOfferingsDescriptions['crystal_ball_desc']!,
      );
      await tester.scrollUntilVisible(cbFinder, 180, scrollable: scrollableFinder);
      await tester.pumpAndSettle();
      expect(cbFinder, findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ShopDialog renders all bespoke CustomPainter RPG shop icons, Tab 4-6 icons, and 3D ElementalEnergySphere orbs with zero flat ElementalSymbolIcon widgets in Dark & Light modes',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'unlockedCrystalBall': true,
        'showCrystalBall': true,
        'enemy_stage': 2,
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

      for (final isDark in [true, false]) {
        controller.darkMode = isDark;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
            home: Scaffold(
              body: ShopDialog(
                key: ValueKey('shop_icons_theme_$isDark'),
                controller: controller,
                initialWing: TempleWing.offerings,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Verify Tab 4, Tab 5, and Tab 6 custom vector icons are wired into ShopDialog
        expect(find.byType(AdorationHarpIcon), findsOneWidget);
        expect(find.byType(PrayerHandsIcon), findsOneWidget);
        expect(find.byType(TitheVaultIcon), findsOneWidget);

        // Verify 5 top elemental balance counters use 3D ElementalEnergySphere (no flat symbols)
        final summaryBar = find.byKey(const ValueKey('shop_orb_summary_bar'));
        expect(
          find.descendant(
            of: summaryBar,
            matching: find.byType(ElementalEnergySphere),
          ),
          findsNWidgets(5),
        );
        expect(find.byType(ElementalSymbolIcon), findsNothing);

        // Scroll through Offerings and verify every bespoke shop item icon + 3D cost orbs render
        final scrollable = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Scrollable),
        );
        const offeringsIconTypes = <Type>[
          PredictabilityScoreIcon,
          ResetButtonIcon,
          NewHandsIcon,
          RandomButtonIcon,
          OverchargedStaffIcon,
          MarkovMatrixIcon,
          YourPredictionIcon,
          EnemyNextMoveIcon,
          GiftBoxIcon,
          StrategySuggestionIcon,
          NewSkinIcon,
          CrystalBallIcon,
          CrystalBallPlusIcon,
          MarkovRecalibratorIcon,
          RemoveAdsIcon,
        ];

        for (final iconType in offeringsIconTypes) {
          final iconFinder = find.byType(iconType);
          await tester.scrollUntilVisible(
            iconFinder,
            180,
            scrollable: scrollable,
          );
          await tester.pumpAndSettle();
          expect(
            iconFinder,
            findsOneWidget,
            reason: 'Expected $iconType in Offerings wing (isDark=$isDark)',
          );
          expect(tester.takeException(), isNull);
        }

        // Verify Prayer wing displays RemoveAdsIcon & 3D orbs on the Free Elemental Orbs card
        await tester.tap(find.byKey(const ValueKey('temple_tab_prayer')));
        await tester.pumpAndSettle();
        expect(find.byType(RemoveAdsIcon), findsOneWidget);
        final adCard = find.byKey(const ValueKey('shop_rewarded_ad_card'));
        expect(adCard, findsOneWidget);
        expect(
          find.descendant(
            of: adCard,
            matching: find.byType(ElementalEnergySphere),
          ),
          findsWidgets,
        );
        expect(find.byType(ElementalSymbolIcon), findsNothing);

        // Verify Consagration wing (+1 Max HP / +1 Max Mana Pool) cost pills use 3D orbs
        await tester.tap(find.byKey(const ValueKey('temple_tab_consagration')));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('shop_upgrade_max_hp_card')),
            matching: find.byType(ElementalEnergySphere),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('shop_upgrade_max_mana_card')),
            matching: find.byType(ElementalEnergySphere),
          ),
          findsWidgets,
        );
        expect(find.byType(ElementalSymbolIcon), findsNothing);
      }
    },
  );

  testWidgets(
    'All bespoke shop_item_icons render cleanly across standard and isOnGoldBackground contrast palettes',
    (WidgetTester tester) async {
      for (final onGold in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor:
                  onGold ? const Color(0xFFF5C22B) : const Color(0xFF1A1D26),
              body: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PredictabilityScoreIcon(size: 32, isOnGoldBackground: onGold),
                  ResetButtonIcon(size: 32, isOnGoldBackground: onGold),
                  NewHandsIcon(size: 32, isOnGoldBackground: onGold),
                  RandomButtonIcon(size: 32, isOnGoldBackground: onGold),
                  MarkovMatrixIcon(size: 32, isOnGoldBackground: onGold),
                  YourPredictionIcon(size: 32, isOnGoldBackground: onGold),
                  EnemyNextMoveIcon(size: 32, isOnGoldBackground: onGold),
                  GiftBoxIcon(size: 32, isOnGoldBackground: onGold),
                  StrategySuggestionIcon(size: 32, isOnGoldBackground: onGold),
                  RemoveAdsIcon(size: 32, isOnGoldBackground: onGold),
                  NewSkinIcon(size: 32, isOnGoldBackground: onGold),
                  CrystalBallIcon(size: 32, isOnGoldBackground: onGold),
                  CrystalBallPlusIcon(size: 32, isOnGoldBackground: onGold),
                  OverchargedStaffIcon(size: 32, isOnGoldBackground: onGold),
                  MarkovRecalibratorIcon(size: 32, isOnGoldBackground: onGold),
                  AdorationHarpIcon(size: 28, isOnGoldBackground: onGold),
                  PrayerHandsIcon(size: 28, isOnGoldBackground: onGold),
                  TitheVaultIcon(size: 28, isOnGoldBackground: onGold),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(PredictabilityScoreIcon), findsOneWidget);
        expect(find.byType(ResetButtonIcon), findsOneWidget);
        expect(find.byType(NewHandsIcon), findsOneWidget);
        expect(find.byType(RandomButtonIcon), findsOneWidget);
        expect(find.byType(MarkovMatrixIcon), findsOneWidget);
        expect(find.byType(YourPredictionIcon), findsOneWidget);
        expect(find.byType(EnemyNextMoveIcon), findsOneWidget);
        expect(find.byType(GiftBoxIcon), findsOneWidget);
        expect(find.byType(StrategySuggestionIcon), findsOneWidget);
        expect(find.byType(RemoveAdsIcon), findsOneWidget);
        expect(find.byType(NewSkinIcon), findsOneWidget);
        expect(find.byType(CrystalBallIcon), findsOneWidget);
        expect(find.byType(CrystalBallPlusIcon), findsOneWidget);
        expect(find.byType(OverchargedStaffIcon), findsOneWidget);
        expect(find.byType(MarkovRecalibratorIcon), findsOneWidget);
        expect(find.byType(AdorationHarpIcon), findsOneWidget);
        expect(find.byType(PrayerHandsIcon), findsOneWidget);
        expect(find.byType(TitheVaultIcon), findsOneWidget);
      }
    },
  );
}

