enum HandMove {
  rock(1, 'Rock', 'assets/images/RockL.png', 'assets/images/RockR.png', '✊'),
  paper(2, 'Paper', 'assets/images/PaperL.png', 'assets/images/PaperR.png', '✋'),
  scissors(3, 'Scissors', 'assets/images/ScissorL.png', 'assets/images/ScissorR.png', '✌'),
  lizard(4, 'Lizard', '', '', '🦎'),
  spock(5, 'Spock', '', '', '🖖');

  final int id;
  final String label;
  final String leftAsset;
  final String rightAsset;
  final String emoji;

  const HandMove(this.id, this.label, this.leftAsset, this.rightAsset, this.emoji);

  static HandMove fromId(int id) {
    return HandMove.values.firstWhere(
      (m) => m.id == id,
      orElse: () => HandMove.rock,
    );
  }

  /// Returns true if this move defeats [other]
  bool beats(HandMove other) {
    switch (this) {
      case HandMove.rock:
        return other == HandMove.scissors || other == HandMove.lizard;
      case HandMove.paper:
        return other == HandMove.rock || other == HandMove.spock;
      case HandMove.scissors:
        return other == HandMove.paper || other == HandMove.lizard;
      case HandMove.lizard:
        return other == HandMove.spock || other == HandMove.paper;
      case HandMove.spock:
        return other == HandMove.scissors || other == HandMove.rock;
    }
  }

  /// Returns the move that counters this move (for standard RPS)
  HandMove get standardCounter {
    switch (this) {
      case HandMove.rock:
        return HandMove.paper;
      case HandMove.paper:
        return HandMove.scissors;
      case HandMove.scissors:
        return HandMove.rock;
      case HandMove.lizard:
        return HandMove.rock;
      case HandMove.spock:
        return HandMove.paper;
    }
  }
}

enum RoundWinner {
  user,
  computer,
  draw;

  bool get isUser => this == RoundWinner.user;
  bool get isComputer => this == RoundWinner.computer;
  bool get isDraw => this == RoundWinner.draw;
}
