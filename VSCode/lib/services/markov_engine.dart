import 'dart:math';
import '../models/move.dart';

class MarkovEngine {
  static const List<HandMove> _baseMoves = [
    HandMove.rock,
    HandMove.paper,
    HandMove.scissors,
  ];

  static const List<HandMove> _allMoves = [
    HandMove.rock,
    HandMove.paper,
    HandMove.scissors,
    HandMove.lizard,
    HandMove.spock,
  ];

  final Random _random;
  final bool enableExtendedHands;
  bool enableEnemyExtendedHands;
  List<HandMove>? _enemyAllowedMoves;
  bool enableElementalMode;

  late List<List<int>> _matrix;
  late List<HandMove> _activeMoves;
  final Map<HandMove, HandMove> _lastTransitionFrom = {};

  MarkovEngine({
    this.enableExtendedHands = false,
    bool? enableEnemyExtendedHands,
    List<HandMove>? enemyAllowedMoves,
    this.enableElementalMode = false,
    Random? random,
  }) : enableEnemyExtendedHands =
           enableEnemyExtendedHands ?? enableExtendedHands,
       _enemyAllowedMoves =
           (enemyAllowedMoves == null || enemyAllowedMoves.isEmpty)
           ? null
           : List.unmodifiable(enemyAllowedMoves),
       _random = random ?? Random() {
    _initMatrix();
  }

  void _initMatrix() {
    _activeMoves = enableExtendedHands ? _allMoves : _baseMoves;

    final size = _activeMoves.length;
    _matrix = List.generate(size, (_) => List.filled(size, 0));
  }

  List<List<int>> get matrix => _matrix;
  List<HandMove> get activeMoves => _activeMoves;

  List<HandMove>? get enemyAllowedMoves => _enemyAllowedMoves;

  set enemyAllowedMoves(List<HandMove>? moves) {
    _enemyAllowedMoves =
        (moves == null || moves.isEmpty) ? null : List.unmodifiable(moves);
  }

  List<HandMove> get enemyMoves =>
      _enemyAllowedMoves ?? (enableEnemyExtendedHands ? _allMoves : _baseMoves);
  int get size => _activeMoves.length;
  int get enemySize => enemyMoves.length;

  /// Read-only view of the single most recent transition out of each state.
  Map<HandMove, HandMove> get lastTransitionFrom =>
      Map.unmodifiable(_lastTransitionFrom);

  /// Returns the single most recent move played after [move] within the
  /// active move deck, or null if no transition from [move] has been recorded.
  HandMove? lastTransitionFor(HandMove? move) {
    if (move == null || !_activeMoves.contains(move)) return null;
    final target = _lastTransitionFrom[move];
    if (target == null || !_activeMoves.contains(target)) return null;
    return target;
  }

  /// Serializes short-term transitions as `<fromId: toId>` for storage/cloud save.
  Map<int, int> get serializedLastTransitions => {
    for (final entry in _lastTransitionFrom.entries)
      entry.key.id: entry.value.id,
  };

  /// Restores short-term transitions from saved `<fromId: toId>` pairs.
  void setLastTransitions(Map<int, int> saved) {
    _lastTransitionFrom.clear();
    for (final entry in saved.entries) {
      HandMove? fromMove;
      HandMove? toMove;
      for (final m in HandMove.values) {
        if (m.id == entry.key) fromMove = m;
        if (m.id == entry.value) toMove = m;
      }
      if (fromMove != null &&
          toMove != null &&
          _activeMoves.contains(fromMove) &&
          _activeMoves.contains(toMove)) {
        _lastTransitionFrom[fromMove] = toMove;
      }
    }
  }

  /// Resets the transition matrix counts and short-term memory back to zero
  void reset() {
    final s = _activeMoves.length;
    _matrix = List.generate(s, (_) => List.filled(s, 0));
    _lastTransitionFrom.clear();
  }

  /// Sets matrix from a saved 2D list
  void setMatrix(List<List<int>> savedMatrix) {
    if (savedMatrix.length == _matrix.length &&
        savedMatrix.every((row) => row.length == _matrix.length)) {
      _matrix = savedMatrix;
    }
  }

  int _activeIndexOf(HandMove move) => _activeMoves.indexOf(move);

  /// Updates cumulative transition matrix and overwrites the single latest
  /// short-term transition observed from [lastMove] -> [currentMove].
  void recordTransition(HandMove? lastMove, HandMove currentMove) {
    if (lastMove == null) return;
    final rowIdx = _activeIndexOf(lastMove);
    final colIdx = _activeIndexOf(currentMove);
    if (rowIdx < 0 ||
        rowIdx >= _matrix.length ||
        colIdx < 0 ||
        colIdx >= _matrix[rowIdx].length) {
      return;
    }
    _matrix[rowIdx][colIdx] += 1;
    _lastTransitionFrom[lastMove] = currentMove;
  }

  /// Returns true if there is at least one recorded transition from [lastUserMove]
  bool hasPrediction(HandMove? lastUserMove) {
    if (lastUserMove == null) return false;
    final rowIdx = _activeIndexOf(lastUserMove);
    if (rowIdx < 0 || rowIdx >= _matrix.length) return false;
    final row = _matrix[rowIdx];
    return row.any((count) => count > 0);
  }

  /// Returns true if a 1-step short-term transition exists from [lastUserMove].
  bool hasShortTermPrediction(HandMove? lastUserMove) {
    return lastTransitionFor(lastUserMove) != null;
  }

  /// Returns the single most recent move played after [lastUserMove], or empty.
  List<HandMove> predictShortTermNextUserMoves(HandMove? lastUserMove) {
    final target = lastTransitionFor(lastUserMove);
    if (target == null) return [];
    return [target];
  }

  /// Returns all most likely next user moves tied for the highest transition count.
  /// Returns an empty list if [lastUserMove] is null or has no recorded transitions yet.
  List<HandMove> predictNextUserMoves(HandMove? lastUserMove) {
    if (lastUserMove == null) {
      return [];
    }

    final rowIdx = _activeIndexOf(lastUserMove);
    if (rowIdx < 0 || rowIdx >= _matrix.length) {
      return [];
    }
    final row = _matrix[rowIdx];
    final colLimit = row.length < _activeMoves.length
        ? row.length
        : _activeMoves.length;

    int maxCount = 0;
    List<HandMove> bestMoves = [];

    for (int col = 0; col < colLimit; col++) {
      if (row[col] > maxCount) {
        maxCount = row[col];
        bestMoves = [_activeMoves[col]];
      } else if (row[col] == maxCount && maxCount > 0) {
        bestMoves.add(_activeMoves[col]);
      }
    }

    if (bestMoves.length >= _activeMoves.length) {
      return [];
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

  List<HandMove> _countersForPredictedMoves(List<HandMove> predictedMoves) {
    final pool = enemyMoves;
    if (pool.length == 1) {
      return List<HandMove>.from(pool);
    }
    if (predictedMoves.isEmpty) {
      return [];
    }
    final List<HandMove> choices = [];
    for (final predicted in predictedMoves) {
      final winningCounters = pool
          .where((m) => m.beats(predicted, elemental: enableElementalMode))
          .toList();
      if (winningCounters.isNotEmpty) {
        for (final counter in winningCounters) {
          if (!choices.contains(counter)) {
            choices.add(counter);
          }
        }
      } else {
        final fallback = predicted.counterForMode(
          elemental: enableElementalMode,
        );
        if (pool.contains(fallback) && !choices.contains(fallback)) {
          choices.add(fallback);
        }
      }
    }
    if (choices.length >= pool.length) {
      return [];
    }
    return choices;
  }

  /// Returns all possible counter-moves the PC could choose corresponding to the
  /// user's most likely next move(s). Returns an empty list if no prediction is available.
  List<HandMove> computeSmartChoices(HandMove? lastUserMove) {
    return _countersForPredictedMoves(predictNextUserMoves(lastUserMove));
  }

  /// AI chooses the counter-move to defeat the predicted user move
  HandMove computeSmartChoice(HandMove? lastUserMove) {
    final choices = computeSmartChoices(lastUserMove);
    if (choices.isEmpty) {
      return getRandomEnemyMove();
    }
    return choices[_random.nextInt(choices.length)];
  }

  /// Returns counter-moves using only the single most recent transition from [lastUserMove].
  List<HandMove> computeShortTermSmartChoices(HandMove? lastUserMove) {
    return _countersForPredictedMoves(
      predictShortTermNextUserMoves(lastUserMove),
    );
  }

  /// Robot Archmage AI: counters strictly based on the single most recent
  /// transition from [lastUserMove], or chooses uniformly at random if none exists.
  HandMove computeShortTermSmartChoice(HandMove? lastUserMove) {
    final choices = computeShortTermSmartChoices(lastUserMove);
    if (choices.isEmpty) {
      return getRandomEnemyMove();
    }
    return choices[_random.nextInt(choices.length)];
  }

  /// Picks a random move from the player's currently active moves
  HandMove getRandomMove() {
    return _activeMoves[_random.nextInt(_activeMoves.length)];
  }

  /// Picks a random move from the enemy's current move pool (5 elements in Phase 2+)
  HandMove getRandomEnemyMove() {
    final pool = enemyMoves;
    return pool[_random.nextInt(pool.length)];
  }

  /// Suggests the most probable hand(s) from the player's active move deck
  /// to defeat the computer's expected move(s), ordered corresponding to [anticipatedPcMoves].
  /// Returns an empty list if PC plays random.
  List<HandMove> computeSuggestions(List<HandMove> anticipatedPcMoves) {
    if (anticipatedPcMoves.isEmpty) {
      return [];
    }

    // Build ordered candidate list corresponding to each anticipated PC move
    final List<HandMove> orderedCandidates = [];
    for (final pcMove in anticipatedPcMoves) {
      final counters = _activeMoves
          .where((m) => m.beats(pcMove, elemental: enableElementalMode))
          .toList();
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
      final wins = anticipatedPcMoves
          .where((pc) => candidate.beats(pc, elemental: enableElementalMode))
          .length;
      winCounts[candidate] = wins;
      if (wins > maxWins) {
        maxWins = wins;
      }
    }

    if (maxWins <= 0) {
      return [];
    }

    final suggestions =
        orderedCandidates.where((c) => winCounts[c] == maxWins).toList();
    if (suggestions.length >= _activeMoves.length) {
      return [];
    }
    return suggestions;
  }

  /// Suggests a move from the player's active move deck to defeat the computer's expected move
  HandMove computeSuggestion(HandMove anticipatedPcMove) {
    final suggestions = computeSuggestions([anticipatedPcMove]);
    if (suggestions.isNotEmpty) {
      return suggestions[_random.nextInt(suggestions.length)];
    }
    final activeCounters = _activeMoves
        .where((m) => m.beats(anticipatedPcMove, elemental: enableElementalMode))
        .toList();
    if (activeCounters.isNotEmpty) {
      return activeCounters[_random.nextInt(activeCounters.length)];
    }
    final fallback = anticipatedPcMove.counterForMode(
      elemental: enableElementalMode,
    );
    return _activeMoves.contains(fallback) ? fallback : _activeMoves.first;
  }
}
