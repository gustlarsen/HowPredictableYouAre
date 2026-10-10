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

      // AI counter-move should beat Paper -> Scissors
      final counter = engine.computeSmartChoice(HandMove.rock);
      expect(counter, HandMove.scissors);
    });

    test('Extended hands (Lizard & Spock) matrix size is 5', () {
      final engine = MarkovEngine(enableExtendedHands: true);
      expect(engine.size, 5);
      expect(engine.activeMoves.length, 5);
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
