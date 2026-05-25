class WrongWord {
  const WrongWord({
    required this.id,
    required this.projectId,
    required this.sentenceId,
    required this.wrongForm,
    required this.correctForm,
    required this.sentenceText,
    required this.projectName,
    required this.createdAt,
    this.mastered = false,
    this.reviewCount = 0,
    this.nextReviewAt,
  });

  final int id;
  final int projectId;
  final int sentenceId;
  final String wrongForm;
  final String correctForm;
  final String sentenceText;
  final String projectName;
  final DateTime createdAt;
  final bool mastered;
  final int reviewCount;
  final DateTime? nextReviewAt;

  /// Ebbinghaus intervals in hours: 1h, 8h, 1d, 2d, 4d, 7d, 15d, 30d
  static const ebIntervals = [1, 8, 24, 48, 96, 168, 360, 720];

  /// Calculate the next review time based on review count.
  DateTime computeNextReview() {
    final idx = reviewCount.clamp(0, ebIntervals.length - 1);
    return DateTime.now().add(Duration(hours: ebIntervals[idx]));
  }

  /// Whether this word is due for review now.
  bool get isDueForReview {
    if (mastered) return false;
    if (nextReviewAt == null) return true;
    return DateTime.now().isAfter(nextReviewAt!);
  }
}
