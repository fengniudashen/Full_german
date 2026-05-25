class StudySentence {
  const StudySentence({
    required this.id,
    required this.projectId,
    required this.position,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.note,
    this.bookmarked = false,
    this.lastDictation = '',
    this.correctCount = 0,
    this.attemptCount = 0,
  });

  final int id;
  final int projectId;
  final int position;
  final String text;
  final int startMs;
  final int endMs;
  final String note;
  final bool bookmarked;
  final String lastDictation;
  final int correctCount;
  final int attemptCount;

  Duration get start => Duration(milliseconds: startMs);
  Duration get end => Duration(milliseconds: endMs);
  bool get hasEndTime => endMs > 0;
  bool get hasValidRange => endMs > startMs;
  bool get hasDictation => lastDictation.isNotEmpty;

  double get accuracy {
    if (attemptCount == 0) return 0;
    return correctCount / attemptCount;
  }

  StudySentence copyWith({
    int? id,
    int? projectId,
    int? position,
    String? text,
    int? startMs,
    int? endMs,
    String? note,
    bool? bookmarked,
    String? lastDictation,
    int? correctCount,
    int? attemptCount,
  }) {
    return StudySentence(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      position: position ?? this.position,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      note: note ?? this.note,
      bookmarked: bookmarked ?? this.bookmarked,
      lastDictation: lastDictation ?? this.lastDictation,
      correctCount: correctCount ?? this.correctCount,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }
}
