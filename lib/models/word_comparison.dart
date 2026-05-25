enum ComparisonStatus { correct, minor, wrong }

class WordComparison {
  const WordComparison({
    required this.original,
    required this.typed,
    required this.status,
  });

  final String original;
  final String typed;
  final ComparisonStatus status;

  bool get isExtraWord => original.isEmpty && typed.isNotEmpty;
  bool get isMissingWord => original.isNotEmpty && typed.isEmpty;
  bool get isWrong => status == ComparisonStatus.wrong;

  String get displayText {
    if (isExtraWord) return '+ $typed';
    if (isMissingWord) return '$original → 漏词';
    if (status == ComparisonStatus.correct) return original;
    return '$original / $typed';
  }
}

class WrongWordDraft {
  const WrongWordDraft({required this.wrongForm, required this.correctForm});
  final String wrongForm;
  final String correctForm;
}

class ComparisonResult {
  const ComparisonResult({required this.items});
  final List<WordComparison> items;

  int get correctCount =>
      items.where((i) => i.status == ComparisonStatus.correct).length;
  int get minorCount =>
      items.where((i) => i.status == ComparisonStatus.minor).length;
  int get wrongCount =>
      items.where((i) => i.status == ComparisonStatus.wrong).length;
  int get totalCount => items.length;

  bool get hasWrongWords => wrongCount > 0;

  double get accuracy =>
      totalCount == 0 ? 1.0 : correctCount / totalCount;

  List<WrongWordDraft> get redErrors {
    return items.where((i) => i.isWrong).map((i) {
      final wrongForm = i.typed.isEmpty ? '(漏词)' : i.typed;
      final correctForm = i.original.isEmpty ? '(多词)' : i.original;
      return WrongWordDraft(wrongForm: wrongForm, correctForm: correctForm);
    }).toList(growable: false);
  }
}
