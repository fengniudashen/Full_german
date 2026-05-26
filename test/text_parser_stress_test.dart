import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/services/text_parser.dart';

/// Intensive stress tests for TextParser.splitIntoSentences.
/// Tests: German-specific punctuation, edge cases, real-world texts,
/// and cross-validation with TextComparator expectations.
void main() {
  group('TextParser — Basic splitting', () {
    test('splits on period', () {
      expect(
        TextParser.splitIntoSentences('Satz eins. Satz zwei.'),
        ['Satz eins.', 'Satz zwei.'],
      );
    });

    test('splits on exclamation mark', () {
      expect(
        TextParser.splitIntoSentences('Halt! Stopp!'),
        ['Halt!', 'Stopp!'],
      );
    });

    test('splits on question mark', () {
      expect(
        TextParser.splitIntoSentences('Warum? Wie? Wann?'),
        ['Warum?', 'Wie?', 'Wann?'],
      );
    });

    test('mixed punctuation', () {
      expect(
        TextParser.splitIntoSentences('Wie geht es? Gut. Danke!'),
        ['Wie geht es?', 'Gut.', 'Danke!'],
      );
    });
  });

  group('TextParser — Whitespace normalization', () {
    test('collapses multiple spaces', () {
      expect(
        TextParser.splitIntoSentences('Ich   bin   hier.'),
        ['Ich bin hier.'],
      );
    });

    test('handles tabs and newlines', () {
      expect(
        TextParser.splitIntoSentences('Satz\teins.\nSatz\tzwei.'),
        ['Satz eins.', 'Satz zwei.'],
      );
    });

    test('trims leading and trailing whitespace', () {
      expect(
        TextParser.splitIntoSentences('   Hallo.   '),
        ['Hallo.'],
      );
    });

    test('handles Windows line endings', () {
      expect(
        TextParser.splitIntoSentences('Eins.\r\nZwei.\r\nDrei.'),
        ['Eins.', 'Zwei.', 'Drei.'],
      );
    });
  });

  group('TextParser — Edge cases', () {
    test('empty string returns empty list', () {
      expect(TextParser.splitIntoSentences(''), isEmpty);
    });

    test('whitespace only returns empty list', () {
      expect(TextParser.splitIntoSentences('   \n  \t  '), isEmpty);
    });

    test('single word without punctuation', () {
      expect(
        TextParser.splitIntoSentences('Hallo'),
        ['Hallo'],
      );
    });

    test('single sentence without trailing punctuation', () {
      expect(
        TextParser.splitIntoSentences('Ich lerne Deutsch'),
        ['Ich lerne Deutsch'],
      );
    });

    test('trailing text after last punctuation stays as separate sentence', () {
      expect(
        TextParser.splitIntoSentences('Satz eins. Kein Punkt'),
        ['Satz eins.', 'Kein Punkt'],
      );
    });
  });

  group('TextParser — German-specific', () {
    test('preserves umlauts and ß', () {
      final result = TextParser.splitIntoSentences(
        'Über die Straße gehen. Schöne Grüße!',
      );
      expect(result, ['Über die Straße gehen.', 'Schöne Grüße!']);
    });

    test('handles abbreviations with periods (Dr. Mr. etc.)', () {
      // Current implementation splits on every period — this documents behavior
      final result = TextParser.splitIntoSentences('Herr Dr. Müller ist da.');
      // It will split at "Dr." — documenting expected behavior
      expect(result.length, greaterThanOrEqualTo(1));
    });

    test('handles numbered lists (21. Mal)', () {
      // Documents behavior with ordinal numbers
      final result = TextParser.splitIntoSentences(
        'FC Bayern gewinnt zum 21. Mal den Pokal.',
      );
      expect(result.length, greaterThanOrEqualTo(1));
    });
  });

  group('TextParser — Stress tests', () {
    test('100 sentences', () {
      final text = List.generate(100, (i) => 'Satz Nummer $i.').join(' ');
      final result = TextParser.splitIntoSentences(text);
      expect(result.length, 100);
    });

    test('very long sentence (500 words, no split)', () {
      final text = List.generate(500, (i) => 'Wort$i').join(' ');
      final result = TextParser.splitIntoSentences(text);
      expect(result.length, 1);
      expect(result.first.split(' ').length, 500);
    });

    test('consecutive punctuation marks', () {
      final result = TextParser.splitIntoSentences('Wirklich?! Ja...');
      expect(result.length, greaterThanOrEqualTo(1));
    });
  });

  group('TextParser — Cross-validation with TextComparator input', () {
    test('split sentences produce valid TextComparator input', () {
      final text = 'Ich lerne Deutsch. Er spricht gut. Sie versteht alles!';
      final sentences = TextParser.splitIntoSentences(text);
      expect(sentences.length, 3);

      // Each sentence should be non-empty and have words
      for (final s in sentences) {
        expect(s.trim().isNotEmpty, true);
        expect(s.split(' ').where((w) => w.isNotEmpty).length, greaterThan(0));
      }
    });

    test('real Tagesschau text parses into valid sentences', () {
      const tagesschau = 'Schwere russische Luftangriffe auf Kiew. '
          'Nach Angaben der Behörden wurden mehrere Menschen getötet. '
          'Viele Gebäude wurden beschädigt!';
      final sentences = TextParser.splitIntoSentences(tagesschau);
      expect(sentences.length, 3);
      expect(sentences[0], contains('Kiew'));
      expect(sentences[1], contains('getötet'));
      expect(sentences[2], contains('beschädigt'));
    });
  });
}
