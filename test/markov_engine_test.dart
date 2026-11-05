import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:howpredictable/services/markov_engine.dart';

void main() {
  group('MarkovEngine', () {
    test('initializes 3x3 transition matrix with all zeros', () {
      final engine = MarkovEngine(random: Random(42));
      expect(engine.matrix, [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ]);
    });

    test('does not update matrix on first turn when total == 0', () {
      final engine = MarkovEngine();
      engine.updateMatrix(
        total: 0,
        lastUserChoice: MarkovEngine.rock,
        currentUserChoice: MarkovEngine.paper,
      );
      expect(engine.matrix, [
        [0, 0, 0],
        [0, 0, 0],
        [0, 0, 0],
      ]);
    });

    test('accumulates transition frequencies and predicts next user move', () {
      final engine = MarkovEngine();
      // User transitions from Rock (1) -> Scissors (3) twice
      engine.updateMatrix(
        total: 1,
        lastUserChoice: MarkovEngine.rock,
        currentUserChoice: MarkovEngine.scissors,
      );
      engine.updateMatrix(
        total: 2,
        lastUserChoice: MarkovEngine.rock,
        currentUserChoice: MarkovEngine.scissors,
      );
      // User transitions from Rock (1) -> Paper (2) once
      engine.updateMatrix(
        total: 3,
        lastUserChoice: MarkovEngine.rock,
        currentUserChoice: MarkovEngine.paper,
      );

      expect(engine.matrix[0], [0, 1, 2]);
      expect(
        engine.findMostLikelyNextUserChoice(MarkovEngine.rock),
        MarkovEngine.scissors,
      );
      // Counter to Scissors (3) is Rock (1)
      expect(engine.smartChoice(MarkovEngine.rock), MarkovEngine.rock);
      // Suggestion to beat PC's Rock (1) is Paper (2)
      expect(
        engine.suggestionForNextTurn(MarkovEngine.rock),
        MarkovEngine.paper,
      );
    });

    test('tie-breaking selects first matching column as in Kodular lists_position_in', () {
      final engine = MarkovEngine();
      // All zeros in row 1 -> max is 0 at index 1 (Rock)
      expect(
        engine.findMostLikelyNextUserChoice(MarkovEngine.rock),
        MarkovEngine.rock,
      );
      expect(engine.smartChoice(MarkovEngine.rock), MarkovEngine.paper);
    });
  });
}

