import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/word_comparison.dart';
import 'package:deutschflow/services/text_comparator.dart';

/// Intensive cross-functional tests for TextComparator (Wagner-Fischer algorithm).
/// Tests cover: German-specific characters, edge cases, stress scenarios,
/// and cross-validation with other subsystems.
void main() {
  group('TextComparator — German Umlaut & ß handling', () {
    test('ä/ö/ü exact match is green', () {
      final r = TextComparator.compare(
        'Über die schöne Straße gehen wir.',
        'Über die schöne Straße gehen wir.',
      );
      expect(r.wrongCount, 0);
      expect(r.minorCount, 0);
      expect(r.correctCount, 6);
    });

    test('ß → ss is yellow (minor), not red', () {
      final r = TextComparator.compare('Straße', 'Strasse');
      expect(r.items.first.status, ComparisonStatus.minor);
    });

    test('ss → ß is also yellow', () {
      final r = TextComparator.compare('Ich muss gehen.', 'Ich muß gehen.');
      final mustItem = r.items.firstWhere((i) => i.original == 'muss');
      expect(mustItem.status, ComparisonStatus.minor);
    });

    test('ä → a is wrong (not minor — different meaning)', () {
      final r = TextComparator.compare('Bär', 'Bar');
      // Case fold doesn't help: bär ≠ bar
      expect(r.items.first.status, ComparisonStatus.wrong);
    });

    test('Ä → ä is minor (case difference only)', () {
      final r = TextComparator.compare('Äpfel', 'äpfel');
      expect(r.items.first.status, ComparisonStatus.minor);
    });

    test('multiple umlauts in one sentence all match correctly', () {
      final r = TextComparator.compare(
        'Die Vögel fliegen über die Bäume und Flüsse.',
        'Die Vögel fliegen über die Bäume und Flüsse.',
      );
      expect(r.accuracy, 1.0);
      expect(r.correctCount, 8);
    });
  });

  group('TextComparator — Case sensitivity', () {
    test('all lowercase is minor for every word', () {
      final r = TextComparator.compare(
        'Ich Gehe Nach Hause.',
        'ich gehe nach hause.',
      );
      expect(r.minorCount, 4);
      expect(r.wrongCount, 0);
    });

    test('mixed case errors preserve accurate counts', () {
      final r = TextComparator.compare(
        'Der Mann kauft ein Buch.',
        'der Mann kauft ein buch.',
      );
      // "Der"→"der" minor, "Buch."→"buch." minor, rest correct
      expect(r.minorCount, 2);
      expect(r.correctCount, 3);
      expect(r.wrongCount, 0);
    });

    test('German nouns capitalization: lowercase noun is minor not wrong', () {
      final r = TextComparator.compare('Entscheidung', 'entscheidung');
      expect(r.items.first.status, ComparisonStatus.minor);
    });
  });

  group('TextComparator — Punctuation tolerance', () {
    test('missing period is minor', () {
      final r = TextComparator.compare('Gut.', 'Gut');
      expect(r.items.first.status, ComparisonStatus.minor);
    });

    test('extra comma is minor', () {
      final r = TextComparator.compare('Ja', 'Ja,');
      expect(r.items.first.status, ComparisonStatus.minor);
    });

    test('question mark vs period is minor', () {
      final r = TextComparator.compare('Wirklich?', 'Wirklich.');
      expect(r.items.first.status, ComparisonStatus.minor);
    });

    test('exclamation vs period is minor', () {
      final r = TextComparator.compare('Halt!', 'Halt.');
      expect(r.items.first.status, ComparisonStatus.minor);
    });
  });

  group('TextComparator — Missing & extra words', () {
    test('one missing word at end', () {
      final r = TextComparator.compare('Ich lerne Deutsch.', 'Ich lerne');
      expect(r.wrongCount, greaterThanOrEqualTo(1));
      final missing = r.items.where((i) => i.isMissingWord).toList();
      expect(missing, isNotEmpty);
    });

    test('one extra word at end', () {
      final r = TextComparator.compare('Ich lerne', 'Ich lerne Deutsch');
      expect(r.wrongCount, greaterThanOrEqualTo(1));
      final extra = r.items.where((i) => i.isExtraWord).toList();
      expect(extra, isNotEmpty);
    });

    test('missing word in middle', () {
      final r = TextComparator.compare(
        'Er hat gestern ein Buch gelesen.',
        'Er hat ein Buch gelesen.',
      );
      // "gestern" is missing
      expect(r.wrongCount, greaterThanOrEqualTo(1));
    });

    test('completely empty input is all missing', () {
      final r = TextComparator.compare('Hallo Welt', '');
      expect(r.wrongCount, 2);
      expect(r.correctCount, 0);
    });

    test('completely wrong input', () {
      final r = TextComparator.compare('Guten Tag', 'xyz abc');
      expect(r.wrongCount, 2);
      expect(r.correctCount, 0);
    });
  });

  group('TextComparator — Stress tests (long sentences)', () {
    test('100-word sentence exact match', () {
      final words = List.generate(100, (i) => 'Wort$i');
      final text = words.join(' ');
      final r = TextComparator.compare(text, text);
      expect(r.correctCount, 100);
      expect(r.wrongCount, 0);
    });

    test('long sentence with scattered errors', () {
      final orig = List.generate(50, (i) => 'Wort$i');
      final typed = List<String>.from(orig);
      // Introduce errors at positions 5, 15, 25, 35, 45
      for (final i in [5, 15, 25, 35, 45]) {
        typed[i] = 'FALSCH$i';
      }
      final r = TextComparator.compare(orig.join(' '), typed.join(' '));
      expect(r.wrongCount, 5);
      expect(r.correctCount, 45);
    });

    test('empty original with non-empty typed', () {
      final r = TextComparator.compare('', 'something');
      expect(r.wrongCount, 1);
      expect(r.correctCount, 0);
    });

    test('both empty', () {
      final r = TextComparator.compare('', '');
      expect(r.totalCount, 0);
      expect(r.accuracy, 1.0);
    });
  });

  group('TextComparator — redErrors extraction', () {
    test('extracts wrong word drafts correctly', () {
      final r = TextComparator.compare(
        'Ich habe einen Hund.',
        'Ich habe einen Hunt.',
      );
      final errors = r.redErrors;
      expect(errors, isNotEmpty);
      expect(errors.first.wrongForm, isNotEmpty);
      expect(errors.first.correctForm, isNotEmpty);
    });

    test('no red errors for perfect match', () {
      final r = TextComparator.compare('Perfekt', 'Perfekt');
      expect(r.redErrors, isEmpty);
    });

    test('no red errors for minor-only differences', () {
      final r = TextComparator.compare('Straße.', 'strasse');
      expect(r.redErrors, isEmpty);
      expect(r.minorCount, 1);
    });
  });

  group('TextComparator — Real-world German news sentences', () {
    test('Tagesschau-style sentence with compound words', () {
      final r = TextComparator.compare(
        'Die Bundesregierung hat neue Maßnahmen zur Bekämpfung der Inflation beschlossen.',
        'Die Bundesregierung hat neue Maßnahmen zur Bekämpfung der Inflation beschlossen.',
      );
      expect(r.accuracy, 1.0);
    });

    test('common learner mistakes in news sentence', () {
      final r = TextComparator.compare(
        'Schwere russische Luftangriffe auf Kiew.',
        'Schwere russiche Luftangrife auf Kiev.',
      );
      // "russische"→"russiche" wrong, "Luftangriffe"→"Luftangrife" wrong, "Kiew"→"Kiev" wrong
      expect(r.wrongCount, greaterThanOrEqualTo(2));
      expect(r.correctCount, greaterThanOrEqualTo(2)); // "Schwere" and "auf"
    });

    test('numbers in sentence', () {
      final r = TextComparator.compare(
        'FC Bayern München gewinnt zum 21. Mal den DFB Pokal.',
        'FC Bayern München gewinnt zum 21. Mal den DFB Pokal.',
      );
      expect(r.accuracy, 1.0);
    });
  });

  group('TextComparator — dictionaryKey', () {
    test('strips punctuation and lowercases', () {
      expect(TextComparator.dictionaryKey('Straße!'), 'straße');
      expect(TextComparator.dictionaryKey('"Hund",'), 'hund');
      expect(TextComparator.dictionaryKey('GROSSE'), 'grosse');
    });

    test('empty string returns empty', () {
      expect(TextComparator.dictionaryKey(''), '');
    });

    test('pure punctuation returns empty', () {
      expect(TextComparator.dictionaryKey('...'), '');
    });
  });
}
