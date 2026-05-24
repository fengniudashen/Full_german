class StudySentence {
  const StudySentence({
    required this.id,
    required this.projectId,
    required this.position,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.note,
  });

  final int id;
  final int projectId;
  final int position;
  final String text;
  final int startMs;
  final int endMs;
  final String note;

  Duration get start => Duration(milliseconds: startMs);

  Duration get end => Duration(milliseconds: endMs);

  bool get hasEndTime => endMs > 0;

  bool get hasValidRange => endMs > startMs;

  StudySentence copyWith({
    int? id,
    int? projectId,
    int? position,
    String? text,
    int? startMs,
    int? endMs,
    String? note,
  }) {
    return StudySentence(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      position: position ?? this.position,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      note: note ?? this.note,
    );
  }
}
