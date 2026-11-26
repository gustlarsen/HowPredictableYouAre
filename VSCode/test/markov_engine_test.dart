import 'package:flutter_test/flutter_test.dart';
import 'package:how_predictable/models/move.dart';
import 'package:how_predictable/services/markov_engine.dart';
import 'package:how_predictable/models/evaluation_tier.dart';

void main() {
  group('HandMove Rules Tests', () {
    test('Rock beats Scissors and Lizard', () {
      expect(HandMove.rock.beats(HandMove.scissors), isTrue);
      expect(HandMove.rock.beats(HandMove.lizard), isTrue);
      expect(HandMove.rock.beats(HandMove.paper), isFalse);
      expect(HandMove.rock.beats(HandMove.spock), isFalse);
      expect(HandMove.rock.beats(HandMove.rock), isFalse);
    });

    test('Paper beats Rock and Spock', () {
      expect(HandMove.paper.beats(HandMove.rock), isTrue);
      expect(HandMove.paper.beats(HandMove.spock), isTrue);
      expect(HandMove.paper.beats(HandMove.scissors), isFalse);
      expect(HandMove.paper.beats(HandMove.lizard), isFalse);
    });

    test('Scissors beats Paper and Lizard', () {
      expect(HandMove.scissors.beats(HandMove.paper), isTrue);
      expect(HandMove.scissors.beats(HandMove.lizard), isTrue);
      expect(HandMove.scissors.beats(HandMove.rock), isFalse);
    });

    test('Wu Xing 3-element and 5-element cycle rules when elemental mode is enabled', () {
      // Base 3 elements: Fire (rock), Water (paper), Wood (scissors)
      // Fire burns Wood, Water extinguishes Fire, Wood absorbs Water
      expect(HandMove.rock.beats(HandMove.scissors, elemental: true), isTrue);
      expect(HandMove.paper.beats(HandMove.rock, elemental: true), isTrue);
      expect(HandMove.scissors.beats(HandMove.paper, elemental: true), isTrue);

      // Balanced 5x5 Wu Xing cycle: each element beats 2 and loses to 2
      // Fire (rock) beats Wood (scissors) and Metal (spock)
      expect(HandMove.rock.beats(HandMove.scissors, elemental: true), isTrue);
      expect(HandMove.rock.beats(HandMove.spock, elemental: true), isTrue);
      expect(HandMove.rock.beats(HandMove.paper, elemental: true), isFalse);
      expect(HandMove.rock.beats(HandMove.lizard, elemental: true), isFalse);

      // Water (paper) beats Fire (rock) and Metal (spock)
      expect(HandMove.paper.beats(HandMove.rock, elemental: true), isTrue);
      expect(HandMove.paper.beats(HandMove.spock, elemental: true), isTrue);
      expect(HandMove.paper.beats(HandMove.scissors, elemental: true), isFalse);
      expect(HandMove.paper.beats(HandMove.lizard, elemental: true), isFalse);

      // Earth (lizard) beats Fire (rock) and Water (paper)
      expect(HandMove.lizard.beats(HandMove.rock, elemental: true), isTrue);
      expect(HandMove.lizard.beats(HandMove.paper, elemental: true), isTrue);
      expect(HandMove.lizard.beats(HandMove.scissors, elemental: true), isFalse);
      expect(HandMove.lizard.beats(HandMove.spock, elemental: true), isFalse);

      // Wood (scissors) beats Water (paper) and Earth (lizard)
      expect(HandMove.scissors.beats(HandMove.paper, elemental: true), isTrue);
      expect(HandMove.scissors.beats(HandMove.lizard, elemental: true), isTrue);
      expect(HandMove.scissors.beats(HandMove.rock, elemental: true), isFalse);
      expect(HandMove.scissors.beats(HandMove.spock, elemental: true), isFalse);

      // Metal (spock) beats Earth (lizard) and Wood (scissors)
      expect(HandMove.spock.beats(HandMove.lizard, elemental: true), isTrue);
      expect(HandMove.spock.beats(HandMove.scissors, elemental: true), isTrue);
      expect(HandMove.spock.beats(HandMove.rock, elemental: true), isFalse);
      expect(HandMove.spock.beats(HandMove.paper, elemental: true), isFalse);

      // Ties: no element beats itself in either classic or elemental mode
      for (final move in HandMove.values) {
        expect(move.beats(move, elemental: false), isFalse);
        expect(move.beats(move, elemental: true), isFalse);
        expect(move.battleDescriptionAgainst(move, elemental: false), isNull);
        expect(move.battleDescriptionAgainst(move, elemental: true), isNull);
      }
    });

    test('Battle descriptions and counterForMode cover all 3-element and 5-element Wu Xing interactions', () {
      // 10 Wu Xing winning interactions
      expect(
        HandMove.rock.battleDescriptionAgainst(HandMove.scissors, elemental: true),
        'Fire burns Wood',
      );
      expect(
        HandMove.rock.battleDescriptionAgainst(HandMove.spock, elemental: true),
        'Fire melts Metal',
      );
      expect(
        HandMove.paper.battleDescriptionAgainst(HandMove.rock, elemental: true),
        'Water extinguishes Fire',
      );
      expect(
        HandMove.paper.battleDescriptionAgainst(HandMove.spock, elemental: true),
        'Water rusts Metal',
      );
      expect(
        HandMove.scissors.battleDescriptionAgainst(HandMove.paper, elemental: true),
        'Wood absorbs Water',
      );
      expect(
        HandMove.scissors.battleDescriptionAgainst(HandMove.lizard, elemental: true),
        'Wood roots in Earth',
      );
      expect(
        HandMove.lizard.battleDescriptionAgainst(HandMove.rock, elemental: true),
        'Earth smothers Fire',
      );
      expect(
        HandMove.lizard.battleDescriptionAgainst(HandMove.paper, elemental: true),
        'Earth dams Water',
      );
      expect(
        HandMove.spock.battleDescriptionAgainst(HandMove.lizard, elemental: true),
        'Metal carves Earth',
      );
      expect(
        HandMove.spock.battleDescriptionAgainst(HandMove.scissors, elemental: true),
        'Metal chops Wood',
      );

      // counterForMode returns a valid winning move for every element
      for (final move in HandMove.values) {
        final classicCounter = move.counterForMode(elemental: false);
        expect(classicCounter.beats(move, elemental: false), isTrue);

        final elementalCounter = move.counterForMode(elemental: true);
        expect(elementalCounter.beats(move, elemental: true), isTrue);
      }
    });
  });

  group('Markov Engine Tests', () {
    test('Initial matrix is all zeros', () {
      final engine = MarkovEngine();
      expect(engine.size, 3);
      for (final row in engine.matrix) {
        expect(row, [0, 0, 0]);
      }
    });

    test('Records transitions correctly', () {
      final engine = MarkovEngine();
      // Record: Rock -> Paper twice
      engine.recordTransition(HandMove.rock, HandMove.paper);
      engine.recordTransition(HandMove.rock, HandMove.paper);
      // Record: Rock -> Scissors once
      engine.recordTransition(HandMove.rock, HandMove.scissors);

      // Row 0 is Rock. Indices: 0=Rock, 1=Paper, 2=Scissors
      expect(engine.matrix[0][1], 2);
      expect(engine.matrix[0][2], 1);
      expect(engine.matrix[0][0], 0);

      // Predicts Paper when last move was Rock
      final predicted = engine.predictNextUserMove(HandMove.rock);
      expect(predicted, HandMove.paper);
      expect(engine.predictNextUserMoves(HandMove.rock), [HandMove.paper]);

      // AI counter-move should beat Paper -> Scissors
      final counter = engine.computeSmartChoice(HandMove.rock);
      expect(counter, HandMove.scissors);
      expect(engine.computeSmartChoices(HandMove.rock), [HandMove.scissors]);
      expect(engine.computeSuggestions([HandMove.scissors]), [HandMove.rock]);
    });

    test('Returns empty predictions when Markov table has no recorded transitions for move', () {
      final engine = MarkovEngine();
      expect(engine.hasPrediction(null), isFalse);
      expect(engine.hasPrediction(HandMove.rock), isFalse);
      expect(engine.predictNextUserMoves(null), isEmpty);
      expect(engine.predictNextUserMoves(HandMove.rock), isEmpty);
      expect(engine.computeSmartChoices(HandMove.rock), isEmpty);
      expect(engine.computeSuggestions([]), isEmpty);
    });

    test('Returns all tied user moves, corresponding PC moves, and winning suggestions on tie', () {
      final engine = MarkovEngine();
      // Record tie from Rock: Rock -> Paper (1) and Rock -> Scissors (1)
      engine.recordTransition(HandMove.rock, HandMove.paper);
      engine.recordTransition(HandMove.rock, HandMove.scissors);

      expect(engine.hasPrediction(HandMove.rock), isTrue);
      final predictedMoves = engine.predictNextUserMoves(HandMove.rock);
      expect(predictedMoves, [HandMove.paper, HandMove.scissors]);

      // Corresponding PC moves that beat [Paper, Scissors] -> [Scissors, Rock]
      final pcChoices = engine.computeSmartChoices(HandMove.rock);
      expect(pcChoices, [HandMove.scissors, HandMove.rock]);

      // Safe hands that win or draw against ALL of PC's [Scissors, Rock] -> only [Rock]
      // (Paper beats Rock but loses to Scissors, so it is filtered out)
      final suggestions = engine.computeSuggestions(pcChoices);
      expect(suggestions, [HandMove.rock]);

      // When all 3 active hands are tied (Rock -> Rock, Paper, Scissors each once), return empty so UI displays '?'
      engine.recordTransition(HandMove.rock, HandMove.rock);
      expect(engine.predictNextUserMoves(HandMove.rock), isEmpty);
      expect(engine.computeSmartChoices(HandMove.rock), isEmpty);
      expect(
        engine.computeSuggestions([HandMove.rock, HandMove.paper, HandMove.scissors]),
        isEmpty,
      );
    });

    test('computeSuggestions filters out risky moves that lose to any PC candidate and falls back cleanly', () {
      // 1. 3-element Elemental mode: PC candidates [Fire, Water] -> only Water is safe (beats Fire, draws Water)
      // Wood beats Water but loses to Fire (risky) -> must be excluded.
      final engine3 = MarkovEngine(enableExtendedHands: false, enableElementalMode: true);
      expect(
        engine3.computeSuggestions([HandMove.fire, HandMove.water]),
        [HandMove.water],
      );

      // 2. 5-element Elemental mode: PC candidates [Fire, Water] -> Earth beats both (2 wins, 0 losses)
      final engine5 = MarkovEngine(enableExtendedHands: true, enableElementalMode: true);
      expect(
        engine5.computeSuggestions([HandMove.fire, HandMove.water]),
        [HandMove.earth],
      );

      // 3. 5-element Classic RPSLS mode: PC candidates [Rock, Paper] -> only Paper is safe
      // (Lizard & Scissors lose to Rock; Spock loses to Paper)
      final engineClassic5 = MarkovEngine(enableExtendedHands: true, enableElementalMode: false);
      expect(
        engineClassic5.computeSuggestions([HandMove.rock, HandMove.paper]),
        [HandMove.paper],
      );

      // 4. 5-element Elemental mode with no 2-win common weakness: PC candidates [Fire, Wood]
      // Fire draws Fire and beats Wood (0 losses) -> only Fire is safe!
      // Water, Earth, and Metal each beat one but lose to the other (1 loss -> filtered out).
      expect(
        engine5.computeSuggestions([HandMove.fire, HandMove.wood]),
        [HandMove.fire],
      );

      // 5. 5-element Elemental mode with 3 PC candidates [Fire, Water, Earth] -> Earth (2 wins, 0 losses)
      expect(
        engine5.computeSuggestions([HandMove.fire, HandMove.water, HandMove.earth]),
        [HandMove.earth],
      );

      // 6. Fallback when no move has 0 losses against all candidates:
      // [Fire, Water, Wood] in 5-element mode -> Earth minimizes losses (1 loss, 2 wins) vs Metal (2 losses, 1 win)
      expect(
        engine5.computeSuggestions([HandMove.fire, HandMove.water, HandMove.wood]),
        [HandMove.earth],
      );

      // [Fire, Water, Wood, Earth] in 5-element mode -> Wood & Earth (1 loss, 2 wins) vs Metal (2 losses, 2 wins)
      expect(
        engine5.computeSuggestions([HandMove.fire, HandMove.water, HandMove.wood, HandMove.earth]),
        unorderedEquals([HandMove.wood, HandMove.earth]),
      );
    });

    test('Extended hands (Lizard & Spock) matrix size is 5', () {
      final engine = MarkovEngine(enableExtendedHands: true);
      expect(engine.size, 5);
      expect(engine.activeMoves.length, 5);
    });

    test('MarkovEngine computes Wu Xing elemental counters without resetting matrix when enableElementalMode changes', () {
      final engine = MarkovEngine(enableExtendedHands: true, enableElementalMode: false);
      // Record transition: Rock (Fire) -> Lizard (Earth) twice
      engine.recordTransition(HandMove.rock, HandMove.lizard);
      engine.recordTransition(HandMove.rock, HandMove.lizard);

      expect(engine.predictNextUserMoves(HandMove.rock), [HandMove.lizard]);

      // In classic RPSLS, Rock and Scissors beat Lizard
      expect(engine.computeSmartChoices(HandMove.rock), [HandMove.rock, HandMove.scissors]);

      // Toggle elemental mode ON seamlessly without resetting the matrix
      engine.enableElementalMode = true;
      expect(engine.matrix[0][3], 2);
      expect(engine.predictNextUserMoves(HandMove.rock), [HandMove.lizard]);

      // In Wu Xing 5-element cycle, Wood (scissors) and Metal (spock) beat Earth (lizard)
      expect(engine.computeSmartChoices(HandMove.rock), [HandMove.scissors, HandMove.spock]);
      // And Fire (rock) beats both Wood (scissors) and Metal (spock)!
      expect(
        engine.computeSuggestions([HandMove.scissors, HandMove.spock]),
        [HandMove.rock],
      );
    });

    test('Full 3-element and 5-element Wu Xing Markov predictions, smart counters, and suggestions for all elements', () {
      // 1. 3-Element Mode (Fire, Water, Wood)
      final engine3 = MarkovEngine(enableExtendedHands: false, enableElementalMode: true);
      expect(engine3.activeMoves, [HandMove.rock, HandMove.paper, HandMove.scissors]);

      // Fire -> Water transition: predicts Water (paper), PC counters with Wood (scissors), suggestion for user is Fire (rock)
      engine3.recordTransition(HandMove.rock, HandMove.paper);
      expect(engine3.predictNextUserMoves(HandMove.rock), [HandMove.paper]);
      expect(engine3.computeSmartChoices(HandMove.rock), [HandMove.scissors]);
      expect(engine3.computeSuggestions([HandMove.scissors]), [HandMove.rock]);

      // Water -> Wood transition: predicts Wood (scissors), PC counters with Fire (rock), suggestion for user is Water (paper)
      engine3.recordTransition(HandMove.paper, HandMove.scissors);
      expect(engine3.predictNextUserMoves(HandMove.paper), [HandMove.scissors]);
      expect(engine3.computeSmartChoices(HandMove.paper), [HandMove.rock]);
      expect(engine3.computeSuggestions([HandMove.rock]), [HandMove.paper]);

      // Wood -> Fire transition: predicts Fire (rock), PC counters with Water (paper), suggestion for user is Wood (scissors)
      engine3.recordTransition(HandMove.scissors, HandMove.rock);
      expect(engine3.predictNextUserMoves(HandMove.scissors), [HandMove.rock]);
      expect(engine3.computeSmartChoices(HandMove.scissors), [HandMove.paper]);
      expect(engine3.computeSuggestions([HandMove.paper]), [HandMove.scissors]);

      // 2. 5-Element Mode (Fire, Water, Wood, Earth, Metal)
      final engine5 = MarkovEngine(enableExtendedHands: true, enableElementalMode: true);
      expect(
        engine5.activeMoves,
        [HandMove.rock, HandMove.paper, HandMove.scissors, HandMove.lizard, HandMove.spock],
      );

      // Predict Fire (rock): beaten by Water (paper) & Earth (lizard); Wood (scissors) beats both Water & Earth!
      engine5.recordTransition(HandMove.rock, HandMove.rock);
      expect(engine5.predictNextUserMoves(HandMove.rock), [HandMove.rock]);
      expect(engine5.computeSmartChoices(HandMove.rock), [HandMove.paper, HandMove.lizard]);
      expect(engine5.computeSuggestions([HandMove.paper, HandMove.lizard]), [HandMove.scissors]);

      // Predict Water (paper): beaten by Wood (scissors) & Earth (lizard); Metal (spock) beats both Wood & Earth!
      engine5.recordTransition(HandMove.paper, HandMove.paper);
      expect(engine5.predictNextUserMoves(HandMove.paper), [HandMove.paper]);
      expect(engine5.computeSmartChoices(HandMove.paper), [HandMove.scissors, HandMove.lizard]);
      expect(engine5.computeSuggestions([HandMove.scissors, HandMove.lizard]), [HandMove.spock]);

      // Predict Wood (scissors): beaten by Fire (rock) & Metal (spock); Water (paper) beats both Fire & Metal!
      engine5.recordTransition(HandMove.scissors, HandMove.scissors);
      expect(engine5.predictNextUserMoves(HandMove.scissors), [HandMove.scissors]);
      expect(engine5.computeSmartChoices(HandMove.scissors), [HandMove.rock, HandMove.spock]);
      expect(engine5.computeSuggestions([HandMove.rock, HandMove.spock]), [HandMove.paper]);

      // Predict Earth (lizard): beaten by Wood (scissors) & Metal (spock); Fire (rock) beats both Wood & Metal!
      engine5.recordTransition(HandMove.lizard, HandMove.lizard);
      expect(engine5.predictNextUserMoves(HandMove.lizard), [HandMove.lizard]);
      expect(engine5.computeSmartChoices(HandMove.lizard), [HandMove.scissors, HandMove.spock]);
      expect(engine5.computeSuggestions([HandMove.scissors, HandMove.spock]), [HandMove.rock]);

      // Predict Metal (spock): beaten by Fire (rock) & Water (paper); Earth (lizard) beats both Fire & Water!
      engine5.recordTransition(HandMove.spock, HandMove.spock);
      expect(engine5.predictNextUserMoves(HandMove.spock), [HandMove.spock]);
      expect(engine5.computeSmartChoices(HandMove.spock), [HandMove.rock, HandMove.paper]);
      expect(engine5.computeSuggestions([HandMove.rock, HandMove.paper]), [HandMove.lizard]);
    });
  });

  group('Evaluation Tier Tests', () {
    test('Under 100 rounds is Under Evaluation', () {
      final tier = EvaluationTier.fromPercent(20.0, 50);
      expect(tier.key, 'string3');
      expect(tier.fallbackDescription, 'Under Evaluation');
    });

    test('100+ rounds maps to correct predictability tier', () {
      expect(EvaluationTier.fromPercent(0.0, 100).key, 'string21');
      expect(EvaluationTier.fromPercent(4.5, 100).key, 'string22');
      expect(EvaluationTier.fromPercent(40.0, 100).key, 'string26');
      expect(EvaluationTier.fromPercent(99.0, 100).key, 'string33');
    });
  });
}
