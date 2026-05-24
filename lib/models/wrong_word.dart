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
  });

  final int id;
  final int projectId;
  final int sentenceId;
  final String wrongForm;
  final String correctForm;
  final String sentenceText;
  final String projectName;
  final DateTime createdAt;
}
