class StudyProject {
  const StudyProject({
    required this.id,
    required this.name,
    required this.audioPath,
    required this.sourceText,
    required this.createdAt,
    required this.timelineCompleted,
    required this.sentenceCount,
    required this.annotatedCount,
    this.dictatedCount = 0,
    this.wrongWordCount = 0,
    this.lastPracticedAt,
  });

  final int id;
  final String name;
  final String audioPath;
  final String sourceText;
  final DateTime createdAt;
  final bool timelineCompleted;
  final int sentenceCount;
  final int annotatedCount;
  final int dictatedCount;
  final int wrongWordCount;
  final DateTime? lastPracticedAt;

  bool get hasAudio => audioPath.trim().isNotEmpty;

  bool get isFullyAnnotated =>
      sentenceCount > 0 && annotatedCount >= sentenceCount;

  double get annotationProgress =>
      sentenceCount == 0 ? 0 : annotatedCount / sentenceCount;

  double get dictationProgress =>
      sentenceCount == 0 ? 0 : dictatedCount / sentenceCount;

  double get accuracy {
    if (dictatedCount == 0) return 0;
    final correct = dictatedCount - wrongWordCount;
    return correct < 0 ? 0 : correct / dictatedCount;
  }

  String get statusLabel {
    if (!timelineCompleted) return '待标注';
    if (dictatedCount == 0) return '可听写';
    if (dictatedCount >= sentenceCount) return '已完成';
    return '进行中';
  }

  StudyProject copyWith({
    int? id,
    String? name,
    String? audioPath,
    String? sourceText,
    DateTime? createdAt,
    bool? timelineCompleted,
    int? sentenceCount,
    int? annotatedCount,
    int? dictatedCount,
    int? wrongWordCount,
    DateTime? lastPracticedAt,
  }) {
    return StudyProject(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      sourceText: sourceText ?? this.sourceText,
      createdAt: createdAt ?? this.createdAt,
      timelineCompleted: timelineCompleted ?? this.timelineCompleted,
      sentenceCount: sentenceCount ?? this.sentenceCount,
      annotatedCount: annotatedCount ?? this.annotatedCount,
      dictatedCount: dictatedCount ?? this.dictatedCount,
      wrongWordCount: wrongWordCount ?? this.wrongWordCount,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
    );
  }
}
