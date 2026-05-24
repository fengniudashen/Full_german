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
    if (isExtraWord) {
      return '+ $typed';
    }
    if (isMissingWord) {
      return '$original -> 漏词';
    }
    if (status == ComparisonStatus.correct) {
      return original;
    }
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
      items.where((item) => item.status == ComparisonStatus.correct).length;

  int get minorCount =>
      items.where((item) => item.status == ComparisonStatus.minor).length;

  int get wrongCount =>
      items.where((item) => item.status == ComparisonStatus.wrong).length;

  bool get hasWrongWords => wrongCount > 0;

  List<WrongWordDraft> get redErrors {
    return items.where((item) => item.isWrong).map((item) {
      final wrongForm = item.typed.isEmpty ? '(漏词)' : item.typed;
      final correctForm = item.original.isEmpty ? '(多词)' : item.original;
      return WrongWordDraft(wrongForm: wrongForm, correctForm: correctForm);
    }).toList(growable: false);
  }
}
