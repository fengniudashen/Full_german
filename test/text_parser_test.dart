import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/services/text_parser.dart';

void main() {
  group('TextParser', () {
    test('splits German text by sentence-ending punctuation and keeps punctuation', () {
      final sentences = TextParser.splitIntoSentences(
        'Guten Morgen!  Wie geht es dir? Ich lerne Deutsch.  Sehr gut',
      );

      expect(sentences, [
        'Guten Morgen!',
        'Wie geht es dir?',
        'Ich lerne Deutsch.',
        'Sehr gut',
      ]);
    });

    test('collapses extra whitespace', () {
      final sentences = TextParser.splitIntoSentences(' Ich   bin\nheute   hier.  Du auch? ');

      expect(sentences, ['Ich bin heute hier.', 'Du auch?']);
    });
  });
}
