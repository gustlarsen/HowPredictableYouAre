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

  /// Returns true if there is at least one recorded transition from [lastUserMove]
  bool hasPrediction(HandMove? lastUserMove) {
    if (lastUserMove == null) return false;
    final rowIdx = _indexOf(lastUserMove);
    final row = _matrix[rowIdx];
    return row.any((count) => count > 0);
  }

  /// Returns all most likely next user moves tied for the highest transition count.
  /// Returns an empty list if [lastUserMove] is null or has no recorded transitions yet.
  List<HandMove> predictNextUserMoves(HandMove? lastUserMove) {
    if (lastUserMove == null) {
      return [];
    }

    final rowIdx = _indexOf(lastUserMove);
    final row = _matrix[rowIdx];

    int maxCount = 0;
    List<HandMove> bestMoves = [];

    for (int col = 0; col < row.length; col++) {
      if (row[col] > maxCount) {
        maxCount = row[col];
        bestMoves = [_activeMoves[col]];
      } else if (row[col] == maxCount && maxCount > 0) {
        bestMoves.add(_activeMoves[col]);
      }
    }

    return bestMoves;
  }

  /// Returns the user's most likely next move based on Markov transition probabilities
  HandMove predictNextUserMove(HandMove? lastUserMove) {
    final bestMoves = predictNextUserMoves(lastUserMove);
    if (bestMoves.isEmpty) {
      return getRandomMove();
    }
    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  /// Returns all possible counter-moves the PC could choose corresponding to the
  /// user's most likely next move(s). Returns an empty list if no prediction is available.
  List<HandMove> computeSmartChoices(HandMove? lastUserMove) {
    final predictedMoves = predictNextUserMoves(lastUserMove);
    if (predictedMoves.isEmpty) {
      return [];
    }

    final List<HandMove> choices = [];
    for (final predicted in predictedMoves) {
      final winningCounters = _activeMoves.where((m) => m.beats(predicted)).toList();
      if (winningCounters.isNotEmpty) {
        for (final counter in winningCounters) {
          if (!choices.contains(counter)) {
            choices.add(counter);
          }
        }
      } else {
        final fallback = predicted.standardCounter;
        if (!choices.contains(fallback)) {
          choices.add(fallback);
        }
      }
    }
    return choices;
  }

  /// AI chooses the counter-move to defeat the predicted user move
  HandMove computeSmartChoice(HandMove? lastUserMove) {
    final choices = computeSmartChoices(lastUserMove);
    if (choices.isEmpty) {
      return getRandomMove();
    }
    return choices[_random.nextInt(choices.length)];
  }

  /// Picks a random move from currently active moves
  HandMove getRandomMove() {
    return _activeMoves[_random.nextInt(_activeMoves.length)];
  }

  /// Suggests the most probable hand(s) for the player to defeat the computer's expected move(s),
  /// ordered corresponding to [anticipatedPcMoves]. Returns an empty list if PC plays random.
  List<HandMove> computeSuggestions(List<HandMove> anticipatedPcMoves) {
    if (anticipatedPcMoves.isEmpty) {
      return [];
    }

    // Build ordered candidate list corresponding to each anticipated PC move
    final List<HandMove> orderedCandidates = [];
    for (final pcMove in anticipatedPcMoves) {
      final counters = _activeMoves.where((m) => m.beats(pcMove)).toList();
      for (final c in counters) {
        if (!orderedCandidates.contains(c)) {
          orderedCandidates.add(c);
        }
      }
    }

    for (final m in _activeMoves) {
      if (!orderedCandidates.contains(m)) {
        orderedCandidates.add(m);
      }
    }

    int maxWins = 0;
    final Map<HandMove, int> winCounts = {};
    for (final candidate in orderedCandidates) {
      final wins = anticipatedPcMoves.where((pc) => candidate.beats(pc)).length;
      winCounts[candidate] = wins;
      if (wins > maxWins) {
        maxWins = wins;
      }
    }

    if (maxWins <= 0) {
      return [];
    }

    return orderedCandidates.where((c) => winCounts[c] == maxWins).toList();
  }

  /// Suggests a move for the player to defeat the computer's expected move
  HandMove computeSuggestion(HandMove anticipatedPcMove) {
    final suggestions = computeSuggestions([anticipatedPcMove]);
    if (suggestions.isNotEmpty) {
      return suggestions[_random.nextInt(suggestions.length)];
    }
    return anticipatedPcMove.standardCounter;
  }
}
