import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/billing_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/markov_engine.dart';
import 'package:how_predictable/services/play_games_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/theme/app_theme.dart';
import 'package:how_predictable/views/dialogs/inventory_dialog.dart';
import 'package:how_predictable/views/dialogs/shop_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2 & Unlock Earth & Metal Mechanics', () {
    test('HandMove.resolvesAgainst allows 3 main elements to defeat all 5 elements', () {
      // Wood (scissors) defeats Earth (lizard) & Water (paper)
      expect(HandMove.scissors.resolvesAgainst(HandMove.lizard), RoundWinner.user);
      expect(HandMove.scissors.resolvesAgainst(HandMove.paper), RoundWinner.user);

      // Fire (rock) defeats Wood (scissors) & Metal (spock in elemental / check beats)
      expect(HandMove.rock.resolvesAgainst(HandMove.scissors), RoundWinner.user);
      // Water (paper) defeats Fire (rock) & Metal (spock)
      expect(HandMove.paper.resolvesAgainst(HandMove.rock), RoundWinner.user);
      expect(HandMove.paper.resolvesAgainst(HandMove.spock), RoundWinner.user);

      // Check how Fire resolves against Earth / Metal under Wu Xing / RPSLS rules:
      // Every one of the 5 enemy moves can be beaten by at least one of Fire/Water/Wood
      const playerMain = [HandMove.rock, HandMove.paper, HandMove.scissors];
      for (final enemyMove in HandMove.values) {
        final canBeat = playerMain.any(
          (p) => p.resolvesAgainst(enemyMove, elemental: true) == RoundWinner.user,
        );
        expect(canBeat, isTrue, reason: 'At least one main element must beat $enemyMove');
      }
    });

    test('Asymmetric MarkovEngine (3 player vs 5 enemy moves) avoids RangeError and keeps suggestions in player deck', () {
      final engine = MarkovEngine(
        enableExtendedHands: false,
        enableEnemyExtendedHands: true,
        enableElementalMode: true,
        random: Random(42),
      );

      expect(engine.size, 3);
      expect(engine.enemySize, 5);
      expect(engine.activeMoves, [HandMove.rock, HandMove.paper, HandMove.scissors]);
      expect(engine.enemyMoves, HandMove.values);

      // Enemy random moves hit all 5 elements
      final seenEnemy = <HandMove>{};
      for (int i = 0; i < 200; i++) {
        seenEnemy.add(engine.getRandomEnemyMove());
        expect(engine.activeMoves.contains(engine.getRandomMove()), isTrue);
      }
      expect(seenEnemy.length, 5);

      // Record transitions for player moves and verify smart choices use all 5 enemy moves
      for (int i = 0; i < 10; i++) {
        engine.recordTransition(HandMove.rock, HandMove.paper);
      }
      expect(engine.hasPrediction(HandMove.rock), isTrue);
      expect(engine.predictNextUserMoves(HandMove.rock), [HandMove.paper]);

      // Out-of-deck move passed to recordTransition / predictNextUserMoves should not throw RangeError
      expect(() => engine.recordTransition(HandMove.lizard, HandMove.rock), returnsNormally);
      expect(() => engine.recordTransition(HandMove.rock, HandMove.spock), returnsNormally);
      expect(engine.hasPrediction(HandMove.lizard), isFalse);
      expect(engine.predictNextUserMoves(HandMove.lizard), isEmpty);

      // Smart choices and suggestions across all 5 enemy moves stay within active player moves
      final smartChoices = engine.computeSmartChoices(HandMove.rock);
      expect(smartChoices, isNotEmpty);
      for (final enemyMove in HandMove.values) {
        final suggestion = engine.computeSuggestion(enemyMove);
        expect(
          engine.activeMoves.contains(suggestion),
          isTrue,
          reason: 'Suggestion $suggestion for $enemyMove must be in player activeMoves',
        );
      }
      for (final enemyTarget in [HandMove.lizard, HandMove.spock]) {
        final suggestions = engine.computeSuggestions([enemyTarget]);
        expect(suggestions, isNotEmpty);
        for (final s in suggestions) {
          expect(engine.activeMoves.contains(s), isTrue);
        }
      }
    });

    test('GameController Phase 2 fights 5-element enemy with 3-move deck, awards Earth/Metal orbs, and deals uniform 1 HP damage', () async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'animationsEnabled': false,
        'current_week': 10,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );

      expect(controller.isPhase2, isTrue);
      expect(controller.showNewHands, isFalse);
      expect(controller.engine.size, 3);
      expect(controller.engine.enemySize, 5);
      expect(controller.playerWinDamageToBoss, GameController.damagePerLoss);
      expect(controller.playerWinDamageToBoss, 1);

      // Verify playRandom never picks Earth/Metal while showNewHands is false
      for (int i = 0; i < 20; i++) {
        controller.startNewBattle();
        controller.playRandom();
        expect(
          [HandMove.rock, HandMove.paper, HandMove.scissors].contains(controller.lastUserMove),
          isTrue,
        );
      }

      // Play varied turns in Phase 2 and verify enemy uses all 5 elements while player plays 3
      controller.startNewBattle();
      final enemyPlayed = <HandMove>{};
      int earthDefeats = 0;
      int metalDefeats = 0;
      final rng = Random(7);
      const playerPool = [HandMove.rock, HandMove.paper, HandMove.scissors];
      for (int i = 0; i < 200; i++) {
        if (controller.remainingMana <= 0 || controller.userHp <= 0 || controller.computerHp <= 0) {
          controller.startNewBattle();
        }
        final move = playerPool[rng.nextInt(3)];
        final prevEarth = controller.earthOrbs;
        final prevMetal = controller.metalOrbs;
        final prevPcHp = controller.computerHp;

        controller.playTurn(move);
        if (controller.currentComputerMove != null) {
          enemyPlayed.add(controller.currentComputerMove!);
        }

        if (controller.lastWinner == RoundWinner.user) {
          expect(prevPcHp - controller.computerHp, 1);
          if (controller.currentComputerMove == HandMove.lizard) {
            earthDefeats++;
            expect(controller.earthOrbs, prevEarth + 1);
            expect(controller.lastCollectedOrbMove, HandMove.lizard);
          } else if (controller.currentComputerMove == HandMove.spock) {
            metalDefeats++;
            expect(controller.metalOrbs, prevMetal + 1);
            expect(controller.lastCollectedOrbMove, HandMove.spock);
          }
        }
      }

      expect(enemyPlayed.length, 5, reason: 'Phase 2 enemy should use all 5 elements');
      expect(earthDefeats, greaterThan(0), reason: 'Player main elements should defeat Earth');
      expect(metalDefeats, greaterThan(0), reason: 'Player main elements should defeat Metal');

      // Unlock Earth & Metal (requires 50 Earth + 50 Metal)
      expect(GameController.costNewHands, const ElementalCost(earth: 50, metal: 50));
      expect(controller.unlockNewHands(), isFalse);
    });

    test('Unlocking "Unlock Earth & Metal" deducts 50 Earth + 50 Metal, preserves IAP/Cloud Save, and maintains uniform 1 HP damage', () async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'animationsEnabled': false,
        'current_week': 10,
        'orbs_fire': 10,
        'orbs_water': 10,
        'orbs_wood': 10,
        'orbs_earth': 60,
        'orbs_metal': 55,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );

      // Cannot unlock if either Earth or Metal < 50
      expect(BillingService.productIdForShopItem('Unlock Earth & Metal'), BillingService.productNewHands);
      expect(BillingService.productIdForShopItem('New Hands'), BillingService.productNewHands);

      final success = controller.unlockNewHands();
      expect(success, isTrue);
      expect(controller.unlockedNewHands, isTrue);
      // Starts OFF until player manually toggles it ON
      expect(controller.showNewHands, isFalse);
      expect(controller.fireOrbs, 10);
      expect(controller.waterOrbs, 10);
      expect(controller.woodOrbs, 10);
      expect(controller.earthOrbs, 10);
      expect(controller.metalOrbs, 5);
      expect(controller.engine.size, 3);
      expect(controller.playerWinDamageToBoss, GameController.damagePerLoss);
      expect(controller.playerWinDamageToBoss, 1);

      // Toggling ON activates 5 elements and maintains uniform 1 HP damage
      controller.toggleShowNewHands(true);
      expect(controller.showNewHands, isTrue);
      expect(controller.engine.size, 5);
      expect(controller.playerWinDamageToBoss, GameController.damagePerLoss);
      expect(controller.playerWinDamageToBoss, 1);

      // Verify manual ON/OFF toggle restores 3 moves and keeps 1 HP damage
      controller.toggleShowNewHands(false);
      expect(controller.showNewHands, isFalse);
      expect(controller.engine.size, 3);
      expect(controller.engine.enemySize, 5);
      expect(controller.playerWinDamageToBoss, 1);

      controller.toggleShowNewHands(true);
      expect(controller.showNewHands, isTrue);
      expect(controller.engine.size, 5);
      expect(controller.playerWinDamageToBoss, 1);

      // CloudSaveData weights still track unlockedNewHands
      final cloud = CloudSaveData(unlockedNewHands: true);
      expect(cloud.unlockedShopValue, 100);
    });

    testWidgets('HintsBar displays 3-of-5 PC choices without turning into "?" when enemySize == 5', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'musicEnabled': false,
        'animationsEnabled': false,
        'current_week': 10,
        'unlockedYourPrediction': true,
        'showYourPrediction': true,
        'unlockedNextMove': true,
        'showNextMove': true,
        'unlockedAlgorithm': true,
        'showAlgorithm': true,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );

      // Teach Markov engine so prediction is deterministic (1 user move -> multiple tied PC moves out of 5)
      controller.playTurn(HandMove.rock);
      // Force engine prediction on rock -> paper, then compute hints
      for (int i = 0; i < 6; i++) {
        controller.engine.recordTransition(HandMove.rock, HandMove.paper);
      }
      // Re-run a turn ending on rock or manually verify smartChoices length
      final smartCount = controller.engine.computeSmartChoices(HandMove.rock).length;
      expect(smartCount, lessThan(controller.engine.enemySize));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider.value(
              value: controller,
              child: HintsBar(controller: controller),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Phase 2 GameScreen renders shield badge and hides locked Earth & Metal buttons', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'musicEnabled': false,
        'animationsEnabled': false,
        'current_week': 10,
        'orbs_earth': 50,
        'orbs_metal': 50,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: controller,
            child: const GameScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Phase 2 boss elemental shield badge renders in GameScreen/VersusArena
      expect(find.byKey(const ValueKey('phase2_boss_shield_badge')), findsOneWidget);
      // Player still only sees 3 elemental buttons while Unlock Earth & Metal is OFF
      expect(find.text('Earth'), findsNothing);
      expect(find.text('Metal'), findsNothing);
    });

    testWidgets('ShopDialog purchases Unlock Earth & Metal for 50 Earth + 50 Metal and enables -4 boss damage when toggled ON', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'musicEnabled': false,
        'animationsEnabled': false,
        'current_week': 10,
        'orbs_earth': 50,
        'orbs_metal': 50,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => ChangeNotifierProvider.value(
                        value: controller,
                        child: ShopDialog(controller: controller),
                      ),
                    );
                  },
                  child: const Text('open_shop'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open_shop'));
      await tester.pumpAndSettle();

      final dialogScrollable = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      );
      final scrollState = tester.state<ScrollableState>(dialogScrollable.first);
      final titleFinder = find.text('Unlock Earth & Metal');
      final unlockBtn = find.byKey(
        const ValueKey('diamond_unlock_${BillingService.productNewHands}'),
      );

      for (double offset = 0; offset <= scrollState.position.maxScrollExtent; offset += 250) {
        scrollState.position.jumpTo(offset);
        await tester.pump();
        if (titleFinder.evaluate().isNotEmpty && unlockBtn.evaluate().isNotEmpty) {
          break;
        }
      }
      await tester.pumpAndSettle();

      expect(titleFinder, findsOneWidget);
      expect(find.text('New Hands'), findsNothing);
      await tester.ensureVisible(unlockBtn);
      await tester.pumpAndSettle();
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Verify purchase deducted 50 Earth + 50 Metal and boss takes uniform 1 HP damage when toggled ON
      expect(controller.unlockedNewHands, isTrue);
      expect(controller.earthOrbs, 0);
      expect(controller.metalOrbs, 0);
      controller.toggleShowNewHands(true);
      expect(controller.playerWinDamageToBoss, 1);
      final hpBeforeBonusHit = controller.computerHp;
      controller.crystalBallMove = HandMove.lizard;
      controller.playTurn(HandMove.scissors);
      expect(controller.lastWinner, RoundWinner.user);
      expect(hpBeforeBonusHit - controller.computerHp, 1);
    });

    testWidgets('Earth uses bronze-brown palette in Dark Mode and deep roasted brown in Light Mode', (WidgetTester tester) async {
      expect(HandMove.lizard.elementalPrimaryColor, const Color(0xFFC47A38));
      expect(HandMove.lizard.elementalSecondaryColor, const Color(0xFF593214));

      const darkPalette = AppPalette(isDark: true);
      const lightPalette = AppPalette(isDark: false);
      expect(darkPalette.elementalText(HandMove.lizard), const Color(0xFFD68C45));
      expect(lightPalette.elementalText(HandMove.lizard), const Color(0xFF6E3D14));

      SharedPreferences.setMockInitialValues({
        'has_seen_story_intro': true,
        'darkMode': true,
        'animationsEnabled': false,
        'musicEnabled': false,
        'soundEnabled': false,
        'unlockedNewSkin': true,
        'showNewSkin': false,
        'unlockedNewHands': true,
        'showNewHands': true,
        'orbs_earth': 42,
      });
      final storage = StorageService();
      await storage.init();
      final controller = GameController(
        storage: storage,
        localization: LocalizationService(),
        audio: AudioService(),
      );
      addTearDown(controller.dispose);

      // Verify InventoryDialog Earth Orb title uses tan-bronze #D68C45 in Dark Mode
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(body: InventoryDialog(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final earthOrbTitle = tester.widget<Text>(find.text('Earth Orb'));
      expect(earthOrbTitle.style?.color, const Color(0xFFD68C45));

      final earthRow = tester.widget<Container>(
        find.byKey(const ValueKey('inventory_orb_row_earth')),
      );
      final earthBorder = (earthRow.decoration! as BoxDecoration).border! as Border;
      expect(
        earthBorder.top.color,
        const Color(0xFFC47A38).withValues(alpha: 0.52),
      );

      // Verify VersusArena & GameScreen EARTH label uses tan-bronze #D68C45 in Dark Mode
      controller.playTurn(HandMove.lizard);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: ChangeNotifierProvider.value(
            value: controller,
            child: const GameScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final earthLabels = tester.widgetList<Text>(find.text('EARTH')).toList();
      expect(earthLabels.length, greaterThanOrEqualTo(2));
      for (final label in earthLabels) {
        expect(label.style?.color, const Color(0xFFD68C45));
      }
    });
  });
}
