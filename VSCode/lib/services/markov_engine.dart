import 'dart:math';
import '../models/move.dart';

class MarkovEngine {
  final Random _random;
  final bool enableExtendedHands;

  late List<List<int>> _matrix;
  late List<HandMove> _activeMoves;

  MarkovEngine({
    this.enableExtendedHands = false,
    Random? random,
  }) : _random = random ?? Random() {
    _initMatrix();
  }

  void _initMatrix() {
    _activeMoves = enableExtendedHands
        ? [HandMove.rock, HandMove.paper, HandMove.scissors, HandMove.lizard, HandMove.spock]
        : [HandMove.rock, HandMove.paper, HandMove.scissors];

    final size = _activeMoves.length;
    _matrix = List.generate(size, (_) => List.filled(size, 0));
  }

  List<List<int>> get matrix => _matrix;
  List<HandMove> get activeMoves => _activeMoves;
  int get size => _activeMoves.length;

  /// Resets the transition matrix counts back to zero
  void reset() {
    final s = _activeMoves.length;
    _matrix = List.generate(s, (_) => List.filled(s, 0));
  }

  /// Sets matrix from a saved 2D list
  void setMatrix(List<List<int>> savedMatrix) {
    if (savedMatrix.length == _matrix.length &&
        savedMatrix.every((row) => row.length == _matrix.length)) {
      _matrix = savedMatrix;
    }
  }

  int _indexOf(HandMove move) {
    final idx = _activeMoves.indexOf(move);
    return idx >= 0 ? idx : 0;
  }

  /// Updates transition matrix with observed transition: [lastMove] -> [currentMove]
  void recordTransition(HandMove? lastMove, HandMove currentMove) {
    if (lastMove == null) return;
    final rowIdx = _indexOf(lastMove);
    final colIdx = _indexOf(currentMove);
    _matrix[rowIdx][colIdx] += 1;
  }

  /// Returns the user's most likely next move based on Markov transition probabilities
  HandMove predictNextUserMove(HandMove? lastUserMove) {
    if (lastUserMove == null) {
      return getRandomMove();
    }

    final rowIdx = _indexOf(lastUserMove);
    final row = _matrix[rowIdx];

    int maxCount = -1;
    List<int> bestIndices = [];

    for (int col = 0; col < row.length; col++) {
      if (row[col] > maxCount) {
        maxCount = row[col];
        bestIndices = [col];
      } else if (row[col] == maxCount && maxCount > 0) {
        bestIndices.add(col);
      }
    }

    // If no transitions recorded for this row yet, fall back to random
    if (maxCount <= 0 || bestIndices.isEmpty) {
      return getRandomMove();
    }

    // If tie, pick randomly among best transitions
    final selectedIdx = bestIndices[_random.nextInt(bestIndices.length)];
    return _activeMoves[selectedIdx];
  }

  /// AI chooses the counter-move to defeat the predicted user move
  HandMove computeSmartChoice(HandMove? lastUserMove) {
    final predictedUserMove = predictNextUserMove(lastUserMove);

    // Find all active moves that defeat the predicted move
    final winningCounters = _activeMoves.where((m) => m.beats(predictedUserMove)).toList();
    if (winningCounters.isNotEmpty) {
      return winningCounters[_random.nextInt(winningCounters.length)];
    }

    return predictedUserMove.standardCounter;
  }

  /// Picks a random move from currently active moves
  HandMove getRandomMove() {
    return _activeMoves[_random.nextInt(_activeMoves.length)];
  }

  /// Suggests a move for the player to defeat the computer's expected move
  HandMove computeSuggestion(HandMove anticipatedPcMove) {
    final winningCounters = _activeMoves.where((m) => m.beats(anticipatedPcMove)).toList();
    if (winningCounters.isNotEmpty) {
      return winningCounters[_random.nextInt(winningCounters.length)];
    }
    return anticipatedPcMove.standardCounter;
  }
}
