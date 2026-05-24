import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/word_comparison.dart';
import 'package:deutschflow/services/text_comparator.dart';

void main() {
  group('TextComparator', () {
    test('marks exact matches green', () {
      final result = TextComparator.compare('Ich lerne Deutsch.', 'Ich lerne Deutsch.');

      expect(result.correctCount, 3);
      expect(result.minorCount, 0);
      expect(result.wrongCount, 0);
      expect(result.items.every((item) => item.status == ComparisonStatus.correct), isTrue);
    });

    test('marks case punctuation and ss differences yellow', () {
      final result = TextComparator.compare('Ich weiß es.', 'ich weiss es');

      expect(result.correctCount, 0);
      expect(result.minorCount, 3);
      expect(result.wrongCount, 0);
    });

    test('marks misspellings missing words and extra words red', () {
      final result = TextComparator.compare('Ich lerne heute Deutsch.', 'Ich liebe Deutsch sehr.');

      expect(result.wrongCount, greaterThanOrEqualTo(2));
      expect(result.redErrors, isNotEmpty);
    });
  });
}
