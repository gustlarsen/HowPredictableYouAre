import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_predictable/controllers/game_controller.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/models/royal_castle.dart';
import 'package:how_predictable/services/audio_service.dart';
import 'package:how_predictable/services/localization_service.dart';
import 'package:how_predictable/services/storage_service.dart';
import 'package:how_predictable/views/dialogs/royal_castle_dialog.dart';
import 'package:how_predictable/views/screens/game_screen.dart';
import 'package:how_predictable/views/widgets/hints_bar.dart';
import 'package:how_predictable/views/widgets/markov_matrix_view.dart';

Future<GameController> _createController({
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    'musicEnabled': false,
    'soundEnabled': false,
    'vibrationEnabled': false,
    'animationsEnabled': false,
    'hasSeenStoryIntro': true,
    'has_seen_story_intro': true,
    ...prefs,
  });
  final storage = StorageService();
  await storage.init();
  final localization = LocalizationService();
  await localization.load();
  return GameController(
    storage: storage,
    localization: localization,
    audio: AudioService(),
  );
}

Widget _wrapWithMapRoot(GameController controller) {
  return ChangeNotifierProvider<GameController>.value(
    value: controller,
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('enter_battle_btn'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const GameScreen(),
                  ),
                );
              },
              child: const Text('Enter Battle'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Narrative Branching & Temple High Master Progression', () {
    testWidgets(
      'Defeating Metal Wizard on Week 0 triggers Flawless Rescue (Secret Ending), whereas Week >= 1 opens Moral Choice Cutscene (Sacrifice vs Refuse -> 350 HP Temple High Master -> 100% HP/Mana restore -> 400 HP Baby Mage Robot)',
      (WidgetTester tester) async {
        // A) Week 1+ Moral Choice: Sacrifice the Princess -> unlocks The Sacred Sacrifice & ends run immediately
        final sacrificeController = await _createController(
          prefs: {
            'current_week': 2,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 1,
          },
        );
        addTearDown(sacrificeController.dispose);

        await tester.pumpWidget(_wrapWithMapRoot(sacrificeController));
        await tester.tap(find.byKey(const ValueKey('enter_battle_btn')));
        await tester.pumpAndSettle();

        sacrificeController.playTurn(HandMove.rock); // Fire beats Metal
        expect(sacrificeController.computerHp, 0);
        expect(sacrificeController.isBossVictoryPending, isTrue);

        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('temple_moral_choice_dialog')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(const ValueKey('temple_moral_choice_next_button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('temple_choice_sacrifice_princess_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('temple_choice_refuse_protect_button')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('temple_choice_sacrifice_princess_button')),
        );
        await tester.pumpAndSettle();

        expect(
          sacrificeController.isEndingUnlocked(NarrativeEnding.sacredSacrifice),
          isTrue,
        );
        expect(sacrificeController.sacredSacrificeCount, 1);
        expect(
          find.byKey(const ValueKey('victory_cutscene_dialog')),
          findsOneWidget,
        );
        expect(find.text('ENDING: THE SACRED SACRIFICE'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();
        expect(sacrificeController.currentWeek, 0);
        expect(sacrificeController.enemyStage, 1);

        // B) Week 1+ Moral Choice: Refuse & Protect Her -> 350 HP Temple High Master -> 100% Altar Restoration -> 400 HP Baby Mage Robot
        final refuseController = await _createController(
          prefs: {
            'current_week': 3,
            'enemy_stage': 3,
            'enemy_max_hp': 300,
            'pcHp': 1,
            'unlockedNewHands': true,
            'showNewHands': true,
          },
        );
        addTearDown(refuseController.dispose);

        await tester.pumpWidget(_wrapWithMapRoot(refuseController));
        await tester.tap(find.byKey(const ValueKey('enter_battle_btn')));
        await tester.pumpAndSettle();

        refuseController.playTurn(HandMove.rock);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('temple_moral_choice_next_button')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('temple_choice_refuse_protect_button')),
        );
        await tester.pumpAndSettle();

        expect(refuseController.enemyStage, 5);
        expect(refuseController.isTempleMasterBoss, isTrue);
        expect(refuseController.enemyMaxHp, 350);
        expect(refuseController.computerHp, 350);
        expect(
          find.byKey(const ValueKey<String>('assets/images/temple_arena_bg.webp')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>(
              'assets/images/enemies/temple_master_idle.png',
            ),
          ),
          findsOneWidget,
        );

        // Reduce Cleric HP and Mana, then defeat Temple High Master -> Altar restores HP & Mana to 100%
        refuseController.userHp = 15;
        refuseController.totalRounds = 60;
        refuseController.computerHp = 1;
        refuseController.crystalBallMove = HandMove.scissors;
        refuseController.playTurn(HandMove.rock);
        expect(refuseController.computerHp, 0);
        expect(refuseController.templeMasterDefeatedCount, 1);

        await tester.pumpAndSettle();
        expect(find.text('Temple High Master Defeated!'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('boss_victory_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(refuseController.enemyStage, 4);
        expect(refuseController.isBabyMageBoss, isTrue);
        expect(refuseController.enemyMaxHp, 400);
        expect(refuseController.computerHp, 400);
        expect(refuseController.userHp, refuseController.effectivePlayerMaxHp);
        expect(refuseController.remainingMana, refuseController.playerMaxMana);
      },
    );
  });

  group('2. Dual-Element Combat Resolution & Orb Rewards', () {
    test(
      'Evaluates all 5 dual-spell outcomes (beats both, beats 1 & ties 1, beats 1 & loses 1, ties 1 & loses 1, loses to both) with exact HP and Orb changes',
      () async {
        final controller = await _createController(
          prefs: {
            'current_week': 5,
            'enemy_stage': 4,
            'enemy_max_hp': 400,
            'pcHp': 400,
            'unlockedNewHands': true,
            'showNewHands': true,
          },
        );
        addTearDown(controller.dispose);

        // 1) Beats BOTH spells: Earth (lizard) vs Fire + Water
        // -> -1 HP boss, 0 HP player, +1 Fire orb AND +1 Water orb
        controller.setCrystalBallDualMoves(HandMove.fire, HandMove.water);
        controller.playTurn(HandMove.earth);
        expect(controller.computerHp, 399);
        expect(controller.userHp, 50);
        expect(controller.fireOrbs, 1);
        expect(controller.waterOrbs, 1);
        expect(controller.lastDualSpellResult!.isCommonWeaknessHit, isTrue);
        expect(controller.lastRoundComputerDamage, 1);
        expect(controller.lastRoundUserDamage, 0);

        // 2) Beats 1 & Ties 1: Water (paper) vs Fire + Water
        // -> -1 HP boss, 0 HP player, +1 Fire orb only
        controller.setCrystalBallDualMoves(HandMove.fire, HandMove.water);
        controller.playTurn(HandMove.water);
        expect(controller.computerHp, 398);
        expect(controller.userHp, 50);
        expect(controller.fireOrbs, 2);
        expect(controller.waterOrbs, 1);
        expect(controller.lastRoundComputerDamage, 1);
        expect(controller.lastRoundUserDamage, 0);

        // 3) Beats 1 & Loses to 1 (Simultaneous Clash): Fire (rock) vs Water + Wood
        // (Fire loses to Water, beats Wood) -> -1 HP boss AND -1 HP player, +1 Wood orb
        controller.setCrystalBallDualMoves(HandMove.water, HandMove.wood);
        controller.playTurn(HandMove.fire);
        expect(controller.computerHp, 397);
        expect(controller.userHp, 49);
        expect(controller.woodOrbs, 1);
        expect(controller.lastDualSpellResult!.isSimultaneousClash, isTrue);
        expect(controller.lastRoundComputerDamage, 1);
        expect(controller.lastRoundUserDamage, 1);

        // 4) Ties 1 & Loses to 1: Fire (rock) vs Fire + Water
        // (Fire ties Fire, loses to Water) -> 0 HP boss, -1 HP player, 0 orbs
        controller.setCrystalBallDualMoves(HandMove.fire, HandMove.water);
        controller.playTurn(HandMove.fire);
        expect(controller.computerHp, 397);
        expect(controller.userHp, 48);
        expect(controller.lastRoundComputerDamage, 0);
        expect(controller.lastRoundUserDamage, 1);

        // 5) Loses to BOTH spells (Double Damage): Wood (scissors) vs Fire + Metal
        // (Wood loses to Fire AND loses to Metal) -> 0 HP boss, -2 HP player, 0 orbs
        controller.setCrystalBallDualMoves(HandMove.fire, HandMove.metal);
        controller.playTurn(HandMove.wood);
        expect(controller.computerHp, 397);
        expect(controller.userHp, 46); // 48 - 2 = 46!
        expect(controller.lastDualSpellResult!.isDoubleLoss, isTrue);
        expect(controller.lastRoundComputerDamage, 0);
        expect(controller.lastRoundUserDamage, 2);
      },
    );
  });

  group('3. Deterministic Pi Sequence AI, HintsBar & Pi Decoder View', () {
    testWidgets(
      'Baby Mage Robot follows Pi digits (3, 1, 4, 1, 5, 9, 2, 6, 5, 3...) and synchronizes HintsBar and Irrational Pi Core Decoder',
      (WidgetTester tester) async {
        final controller = await _createController(
          prefs: {
            'current_week': 5,
            'enemy_stage': 4,
            'enemy_max_hp': 400,
            'pcHp': 400,
            'unlockedNewHands': true,
            'showNewHands': true,
            'unlockedNextMove': true,
            'showNextMove': true,
            'unlockedSuggestion': true,
            'showSuggestion': true,
            'unlockedCrystalBall': true,
            'showCrystalBall': true,
            'unlockedCrystalBallPlus': true,
            'showCrystalBallPlus': true,
            'unlockedAlgorithm': true,
            'showAlgorithm': true,
          },
        );
        addTearDown(controller.dispose);

        expect(GameController.piDigitsSequence.length, greaterThanOrEqualTo(500));

        // Expected first 6 Pi digits: 3, 1, 4, 1, 5, 9
        final expectedSequence = <({
          int digit,
          List<HandMove> pair,
          HandMove counter5,
          HandMove counter3,
        })>[
          (
            digit: 3,
            pair: [HandMove.water, HandMove.earth],
            counter5: HandMove.wood,
            counter3: HandMove.wood,
          ),
          (
            digit: 1,
            pair: [HandMove.fire, HandMove.water],
            counter5: HandMove.earth,
            counter3: HandMove.water,
          ),
          (
            digit: 4,
            pair: [HandMove.earth, HandMove.wood],
            counter5: HandMove.metal,
            counter3: HandMove.wood,
          ),
          (
            digit: 1,
            pair: [HandMove.fire, HandMove.water],
            counter5: HandMove.earth,
            counter3: HandMove.water,
          ),
          (
            digit: 5,
            pair: [HandMove.earth, HandMove.wood],
            counter5: HandMove.metal,
            counter3: HandMove.wood,
          ),
          (
            digit: 9,
            pair: [HandMove.metal, HandMove.fire],
            counter5: HandMove.water,
            counter3: HandMove.water,
          ),
        ];

        for (final step in expectedSequence) {
          expect(controller.currentPiDigit, step.digit);
          expect(controller.pcNextMoves, step.pair);
          expect(controller.crystalBallMoves, step.pair);
          expect(controller.suggestedMoves, [step.counter5]);
          expect(controller.crystalBallPlusMoves, [step.counter5]);

          // Also verify 3-element deck fallback counter recommendation
          expect(
            GameController.optimalCountersForDualSpells(
              step.pair,
              const [HandMove.fire, HandMove.water, HandMove.wood],
            ),
            [step.counter3],
          );

          controller.playTurn(step.counter5);
          expect(controller.currentComputerMoves, step.pair);
          expect(controller.lastRoundComputerDamage, 1);
          expect(controller.lastRoundUserDamage, 0);
        }

        // Render HintsBar & MarkovMatrixView (Irrational Pi Core Decoder)
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HintsBar(controller: controller),
                    MarkovMatrixView(
                      engine: controller.engine,
                      lastUserMove: controller.lastUserMove,
                      elementalMode: true,
                      localization: controller.localization,
                      isBabyMageRandomView: controller.isBabyMageBoss,
                      currentPiDigit: controller.currentPiDigit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('markov_baby_mage_pi_decoder')),
          findsOneWidget,
        );
        expect(find.textContaining('3.14159'), findsWidgets);
        expect(find.byKey(const ValueKey('pi_decoder_row_0_1')), findsOneWidget);
        expect(find.byKey(const ValueKey('pi_decoder_row_2_3')), findsOneWidget);
        expect(find.byKey(const ValueKey('pi_decoder_row_4_5')), findsOneWidget);
        expect(find.byKey(const ValueKey('pi_decoder_row_6_7')), findsOneWidget);
        expect(find.byKey(const ValueKey('pi_decoder_row_8_9')), findsOneWidget);
      },
    );
  });

  group('4. Teleport Cowardly Escapes & 6 Endings Tracker', () {
    testWidgets(
      'Teleporting or falling to 0 HP against Temple High Master triggers The Sacred Sacrifice; Teleporting against Baby Mage Robot triggers The Deserter; Royal Library tracks X / 6 Endings',
      (WidgetTester tester) async {
        // A) Teleporting during Temple High Master -> The Sacred Sacrifice
        final tmTeleportController = await _createController(
          prefs: {
            'current_week': 4,
            'enemy_stage': 5,
            'enemy_max_hp': 350,
            'pcHp': 350,
          },
        );
        addTearDown(tmTeleportController.dispose);

        await tester.pumpWidget(_wrapWithMapRoot(tmTeleportController));
        await tester.tap(find.byKey(const ValueKey('enter_battle_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();

        expect(find.text('Abandon the Princess?'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('teleport_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(
          tmTeleportController.isEndingUnlocked(NarrativeEnding.sacredSacrifice),
          isTrue,
        );
        expect(tmTeleportController.sacredSacrificeCount, 1);
        expect(find.text('ENDING: THE SACRED SACRIFICE'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();
        expect(tmTeleportController.currentWeek, 0);
        expect(tmTeleportController.enemyStage, 1);

        // B) Falling to 0 HP against Temple High Master -> The Sacred Sacrifice
        final tmDeathController = await _createController(
          prefs: {
            'current_week': 4,
            'enemy_stage': 5,
            'enemy_max_hp': 350,
            'pcHp': 350,
            'userHp': 1,
          },
        );
        addTearDown(tmDeathController.dispose);

        await tester.pumpWidget(_wrapWithMapRoot(tmDeathController));
        await tester.tap(find.byKey(const ValueKey('enter_battle_btn')));
        await tester.pumpAndSettle();

        tmDeathController.crystalBallMove = HandMove.water;
        tmDeathController.playTurn(HandMove.fire); // Lose 1 HP -> 0 HP
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('death_dialog')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('death_accept_button')));
        await tester.pumpAndSettle();

        expect(
          tmDeathController.isEndingUnlocked(NarrativeEnding.sacredSacrifice),
          isTrue,
        );
        expect(tmDeathController.sacredSacrificeCount, 1);
        expect(find.text('ENDING: THE SACRED SACRIFICE'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        // C) Teleporting during Baby Mage Robot -> The Deserter
        final deserterController = await _createController(
          prefs: {
            'current_week': 6,
            'enemy_stage': 4,
            'enemy_max_hp': 400,
            'pcHp': 400,
          },
        );
        addTearDown(deserterController.dispose);

        await tester.pumpWidget(_wrapWithMapRoot(deserterController));
        await tester.tap(find.byKey(const ValueKey('enter_battle_btn')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('teleport_portal_button')));
        await tester.pumpAndSettle();

        expect(find.text('Desert the Kingdom?'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('teleport_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(
          deserterController.isEndingUnlocked(NarrativeEnding.theDeserter),
          isTrue,
        );
        expect(deserterController.deserterCount, 1);
        expect(find.text('ENDING: THE DESERTER'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('victory_cutscene_skip_button')),
        );
        await tester.pumpAndSettle();

        // D) Royal Library displays Endings Discovered: 6 / 6 when all 6 endings are unlocked
        final allEndingsController = await _createController(
          prefs: {
            'unlocked_endings': [
              for (final e in NarrativeEnding.values) e.id,
            ],
            'encountered_bestiary': [
              for (final c in BestiaryCreature.values) c.id,
            ],
          },
        );
        addTearDown(allEndingsController.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: RoyalCastleDialog(
                controller: allEndingsController,
                initialWing: CastleWing.library,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Endings Discovered: 6 / 6'), findsOneWidget);
        expect(find.text('Flawless Rescue (Secret)'), findsOneWidget);
        expect(find.text('Sanctuary Victory (Standard)'), findsOneWidget);
        expect(find.text('The Sacred Sacrifice'), findsOneWidget);
        expect(find.text('The Deserter'), findsOneWidget);
        expect(find.text('Ruin'), findsOneWidget);
        expect(find.text('Invasion (Time Out)'), findsOneWidget);
      },
    );
  });
}
