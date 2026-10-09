class EvaluationTier {
  final String key;
  final String fallbackDescription;

  const EvaluationTier(this.key, this.fallbackDescription);

  static EvaluationTier fromPercent(double percentPredict, int totalRounds) {
    if (totalRounds < 100) {
      return const EvaluationTier('string3', 'Under Evaluation');
    }

    if (percentPredict == 0) {
      return const EvaluationTier('string21', 'Perfect Predictor');
    } else if (percentPredict < 5) {
      return const EvaluationTier('string22', 'Very Good Predictor');
    } else if (percentPredict < 15) {
      return const EvaluationTier('string23', 'Good Predictor');
    } else if (percentPredict < 25) {
      return const EvaluationTier('string24', 'Bad Predictor');
    } else if (percentPredict < 35) {
      return const EvaluationTier('string25', 'Are you trying to predict me ?');
    } else if (percentPredict < 45) {
      return const EvaluationTier('string26', 'Unpredictable');
    } else if (percentPredict < 50) {
      return const EvaluationTier('string27', 'Hardly Predictable');
    } else if (percentPredict < 60) {
      return const EvaluationTier('string28', 'Slightly Predictable');
    } else if (percentPredict < 70) {
      return const EvaluationTier('string29', 'Reasonably Predictable');
    } else if (percentPredict < 80) {
      return const EvaluationTier('string30', 'Sometimes Predictable');
    } else if (percentPredict < 90) {
      return const EvaluationTier('string31', 'Often Predictable');
    } else if (percentPredict < 95) {
      return const EvaluationTier('string32', 'Very Predictable');
    } else {
      return const EvaluationTier('string33', 'Totally Predictable');
    }
  }
}
