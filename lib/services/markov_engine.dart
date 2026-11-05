import 'dart:math';

class MarkovEngine {
  static const int rock = 1;
  static const int paper = 2;
  static const int scissors = 3;
  static const int none = 4;

  /// Kodular 1-indexed choices: [1 (ROCK), 2 (PAPER), 3 (SCISSORS)]
  static const List<int> choices = [rock, paper, scissors];

  /// Kodular 1-indexed beatingChoices:
  /// Index 1 (ROCK) is beaten by 2 (PAPER)
  /// Index 2 (PAPER) is beaten by 3 (SCISSORS)
  /// Index 3 (SCISSORS) is beaten by 1 (ROCK)
  static const List<int> beatingChoices = [paper, scissors, rock];

  final Random _random;
  List<List<int>> _matrix = [
    [0, 0, 0],
    [0, 0, 0],
    [0, 0, 0],
  ];

  MarkovEngine({Random? random}) : _random = random ?? Random();

  List<List<int>> get matrix =>
      _matrix.map((row) => List<int>.unmodifiable(row)).toList(growable: false);

  void initializeMarkovMatrix() {
    _matrix = [
      [0, 0, 0],
      [0, 0, 0],
      [0, 0, 0],
    ];
  }

  void setMatrix(List<List<int>> newMatrix) {
    if (newMatrix.length == 3 && newMatrix.every((r) => r.length == 3)) {
      _matrix = newMatrix.map((r) => List<int>.from(r)).toList();
    } else {
      initializeMarkovMatrix();
    }
  }

  static int beatingChoiceFor(int choice) {
    if (choice < 1 || choice > 3) {
      return paper;
    }
    return beatingChoices[choice - 1];
  }

  static int maxInRow(List<int> row) {
    if (row.isEmpty) return 0;
    int maxVal = row[0];
    for (int i = 1; i < row.length; i++) {
      if (row[i] > maxVal) {
        maxVal = row[i];
      }
    }
    return maxVal;
  }

  /// Exact port of Kodular `findMostLikelyNextUserChoice`:
  /// Queries `MarkovTransitionMatrix[lastUserChoice]` and returns the first
  /// 1-based index (1..3) matching `maxInRow(row)`.
  int findMostLikelyNextUserChoice(int lastUserChoice) {
    final safeRowIndex = (lastUserChoice >= 1 && lastUserChoice <= 3)
        ? lastUserChoice - 1
        : 0;
    final row = _matrix[safeRowIndex];
    final maxVal = maxInRow(row);
    for (int i = 0; i < row.length; i++) {
      if (row[i] == maxVal) {
        return i + 1;
      }
    }
    return rock;
  }

  /// Exact port of Kodular `smartChoice`:
  /// `beatingChoices[findMostLikelyNextUserChoice()]`
  int smartChoice(int lastUserChoice) {
    final predictedUserMove = findMostLikelyNextUserChoice(lastUserChoice);
    return beatingChoiceFor(predictedUserMove);
  }

  /// Exact port of Kodular suggestion:
  /// `beatingChoices[smartChoice()]`
  int suggestionForNextTurn(int lastUserChoice) {
    final pcMove = smartChoice(lastUserChoice);
    return beatingChoiceFor(pcMove);
  }

  /// Exact port of Kodular `randomChoice`:
  /// Picks randomly from `[ROCK, PAPER, SCISSORS]`.
  int randomChoice() {
    return choices[_random.nextInt(choices.length)];
  }

  /// Exact port of Kodular `updateMatrix`:
  /// Only records transition when `total != 0`.
  void updateMatrix({
    required int total,
    required int lastUserChoice,
    required int currentUserChoice,
  }) {
    if (total != 0 &&
        lastUserChoice >= 1 &&
        lastUserChoice <= 3 &&
        currentUserChoice >= 1 &&
        currentUserChoice <= 3) {
      _matrix[lastUserChoice - 1][currentUserChoice - 1] += 1;
    }
  }

  int cell(int rowZeroBased, int colZeroBased) {
    return _matrix[rowZeroBased][colZeroBased];
  }
}

