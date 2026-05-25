class PracticeSession {
  const PracticeSession({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.startedAt,
    required this.sentencesPracticed,
    required this.correctCount,
    required this.wrongCount,
    required this.durationMs,
  });

  final int id;
  final int projectId;
  final String projectName;
  final DateTime startedAt;
  final int sentencesPracticed;
  final int correctCount;
  final int wrongCount;
  final int durationMs;

  double get accuracy {
    final total = correctCount + wrongCount;
    return total == 0 ? 1.0 : correctCount / total;
  }

  Duration get duration => Duration(milliseconds: durationMs);
}

class DailyStats {
  const DailyStats({
    required this.date,
    required this.sentencesPracticed,
    required this.correctCount,
    required this.wrongCount,
    required this.practiceTimeMs,
  });

  final DateTime date;
  final int sentencesPracticed;
  final int correctCount;
  final int wrongCount;
  final int practiceTimeMs;

  double get accuracy {
    final total = correctCount + wrongCount;
    return total == 0 ? 1.0 : correctCount / total;
  }
}
