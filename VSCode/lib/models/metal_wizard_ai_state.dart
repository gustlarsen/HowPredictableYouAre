import 'dart:collection';
import 'move.dart';

enum MetalWizardStrategyMode {
  /// Win-Stay / Lose-Shift
  normal,

  /// Win-Shift / Lose-Stay
  inverse,
}

enum MetalWizardScriptType {
  /// Sequence A: 10 alternating casts starting with Metal
  alternating,

  /// Sequence B: 5 Metal casts followed by 5 Earth casts
  fiveMetalFiveEarth,
}

/// Deterministic stateful AI controller for Stage 3: Metal Wizard (300 HP).
class MetalWizardAiState {
  static const List<HandMove> alternatingSequence = [
    HandMove.metal,
    HandMove.earth,
    HandMove.metal,
    HandMove.earth,
    HandMove.metal,
    HandMove.earth,
    HandMove.metal,
    HandMove.earth,
    HandMove.metal,
    HandMove.earth,
  ];

  static const List<HandMove> fiveMetalFiveEarthSequence = [
    HandMove.metal,
    HandMove.metal,
    HandMove.metal,
    HandMove.metal,
    HandMove.metal,
    HandMove.earth,
    HandMove.earth,
    HandMove.earth,
    HandMove.earth,
    HandMove.earth,
  ];

  HandMove currentMove;
  MetalWizardStrategyMode strategyMode;
  int consecutiveLosses;
  final List<HandMove> _scriptedQueue;
  HandMove? nextMoveAfterScript;
  int tenLossStage;
  MetalWizardScriptType? _activeScriptType;

  MetalWizardAiState({
    this.currentMove = HandMove.metal,
    this.strategyMode = MetalWizardStrategyMode.normal,
    this.consecutiveLosses = 0,
    List<HandMove> scriptedQueue = const [],
    this.nextMoveAfterScript,
    this.tenLossStage = 0,
    MetalWizardScriptType? activeScriptType,
  })  : _scriptedQueue = List<HandMove>.from(scriptedQueue),
        _activeScriptType = activeScriptType ??
            (scriptedQueue.isEmpty
                ? null
                : (tenLossStage == 1
                    ? MetalWizardScriptType.alternating
                    : MetalWizardScriptType.fiveMetalFiveEarth));

  List<HandMove> get scriptedQueue => UnmodifiableListView<HandMove>(_scriptedQueue);

  bool get isExecutingScriptedSequence => _scriptedQueue.isNotEmpty;

  MetalWizardScriptType? get activeScriptType =>
      _scriptedQueue.isEmpty ? null : _activeScriptType;

  void reset() {
    currentMove = HandMove.metal;
    strategyMode = MetalWizardStrategyMode.normal;
    consecutiveLosses = 0;
    _scriptedQueue.clear();
    nextMoveAfterScript = null;
    tenLossStage = 0;
    _activeScriptType = null;
  }

  static HandMove _oppositeElement(HandMove move) {
    return move == HandMove.metal ? HandMove.earth : HandMove.metal;
  }

  static HandMove _sanitizeMetalOrEarth(HandMove move) {
    return move == HandMove.earth ? HandMove.earth : HandMove.metal;
  }

  /// Resolves the Metal Wizard's AI state after a turn completes with [outcome]
  /// (`RoundWinner.user` = Metal Wizard lost 1 HP, `RoundWinner.computer` =
  /// Metal Wizard won, `RoundWinner.draw` = Draw or Anti-Metal Shield block).
  void resolveTurn(RoundWinner outcome) {
    if (_scriptedQueue.isNotEmpty) {
      _scriptedQueue.removeAt(0);
      if (_scriptedQueue.isNotEmpty) {
        currentMove = _scriptedQueue.first;
      } else {
        strategyMode = MetalWizardStrategyMode.normal;
        currentMove = nextMoveAfterScript ?? HandMove.metal;
        nextMoveAfterScript = null;
        _activeScriptType = null;
        consecutiveLosses = 0;
      }
      return;
    }

    switch (outcome) {
      case RoundWinner.draw:
        return;
      case RoundWinner.computer:
        consecutiveLosses = 0;
        if (strategyMode == MetalWizardStrategyMode.inverse) {
          currentMove = _oppositeElement(currentMove);
        }
        return;
      case RoundWinner.user:
        consecutiveLosses += 1;
        if (consecutiveLosses >= 10) {
          if (tenLossStage == 0) {
            _scriptedQueue
              ..clear()
              ..addAll(alternatingSequence);
            nextMoveAfterScript = HandMove.earth;
            _activeScriptType = MetalWizardScriptType.alternating;
            tenLossStage = 1;
          } else {
            _scriptedQueue
              ..clear()
              ..addAll(fiveMetalFiveEarthSequence);
            nextMoveAfterScript = HandMove.metal;
            _activeScriptType = MetalWizardScriptType.fiveMetalFiveEarth;
            tenLossStage = 0;
          }
          currentMove = _scriptedQueue.first;
        } else {
          if (strategyMode == MetalWizardStrategyMode.normal) {
            currentMove = _oppositeElement(currentMove);
          }
          if (consecutiveLosses % 3 == 0) {
            strategyMode = strategyMode == MetalWizardStrategyMode.normal
                ? MetalWizardStrategyMode.inverse
                : MetalWizardStrategyMode.normal;
          }
        }
        return;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'currentMoveId': currentMove.id,
      'strategyMode': strategyMode.name,
      'consecutiveLosses': consecutiveLosses,
      'scriptedQueueIds': _scriptedQueue.map((m) => m.id).toList(),
      'nextMoveAfterScriptId': nextMoveAfterScript?.id,
      'tenLossStage': tenLossStage,
      'activeScriptType': _activeScriptType?.name,
    };
  }

  factory MetalWizardAiState.fromJson(Map<String, dynamic> map) {
    final currentMove = _sanitizeMetalOrEarth(
      HandMove.fromId((map['currentMoveId'] as num?)?.toInt() ?? HandMove.metal.id),
    );
    final rawMode = map['strategyMode']?.toString();
    final strategyMode = rawMode == MetalWizardStrategyMode.inverse.name
        ? MetalWizardStrategyMode.inverse
        : MetalWizardStrategyMode.normal;
    final rawLosses = (map['consecutiveLosses'] as num?)?.toInt() ?? 0;
    final consecutiveLosses = rawLosses < 0 ? 0 : rawLosses;
    final rawQueue = map['scriptedQueueIds'];
    final scriptedQueue = <HandMove>[];
    if (rawQueue is List) {
      for (final item in rawQueue) {
        final id = (item as num?)?.toInt();
        if (id != null) {
          scriptedQueue.add(_sanitizeMetalOrEarth(HandMove.fromId(id)));
        }
      }
    }
    final nextAfterId = (map['nextMoveAfterScriptId'] as num?)?.toInt();
    final nextMoveAfterScript = nextAfterId == null
        ? null
        : _sanitizeMetalOrEarth(HandMove.fromId(nextAfterId));
    final rawStage = (map['tenLossStage'] as num?)?.toInt() ?? 0;
    final tenLossStage = rawStage == 1 ? 1 : 0;
    final rawScriptType = map['activeScriptType']?.toString();
    MetalWizardScriptType? activeScriptType;
    if (scriptedQueue.isNotEmpty) {
      if (rawScriptType == MetalWizardScriptType.fiveMetalFiveEarth.name) {
        activeScriptType = MetalWizardScriptType.fiveMetalFiveEarth;
      } else if (rawScriptType == MetalWizardScriptType.alternating.name) {
        activeScriptType = MetalWizardScriptType.alternating;
      } else {
        activeScriptType = tenLossStage == 1
            ? MetalWizardScriptType.alternating
            : MetalWizardScriptType.fiveMetalFiveEarth;
      }
    }

    return MetalWizardAiState(
      currentMove: scriptedQueue.isNotEmpty ? scriptedQueue.first : currentMove,
      strategyMode: strategyMode,
      consecutiveLosses: consecutiveLosses,
      scriptedQueue: scriptedQueue,
      nextMoveAfterScript: nextMoveAfterScript,
      tenLossStage: tenLossStage,
      activeScriptType: activeScriptType,
    );
  }
}
