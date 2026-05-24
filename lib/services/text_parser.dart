class TextParser {
  static final RegExp sentenceSplitPattern = RegExp(r'(?<=[.!?])\s+');

  static List<String> splitIntoSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return const [];
    }

    return normalized
        .split(sentenceSplitPattern)
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList(growable: false);
  }
}
