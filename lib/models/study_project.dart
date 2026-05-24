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
  });

  final int id;
  final String name;
  final String audioPath;
  final String sourceText;
  final DateTime createdAt;
  final bool timelineCompleted;
  final int sentenceCount;
  final int annotatedCount;

  bool get hasAudio => audioPath.trim().isNotEmpty;

  bool get isFullyAnnotated =>
      sentenceCount > 0 && annotatedCount >= sentenceCount;

  StudyProject copyWith({
    int? id,
    String? name,
    String? audioPath,
    String? sourceText,
    DateTime? createdAt,
    bool? timelineCompleted,
    int? sentenceCount,
    int? annotatedCount,
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
    );
  }
}
