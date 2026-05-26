import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/wrong_word.dart';
import 'package:deutschflow/services/csv_exporter.dart';

/// Intensive tests for CsvExporter — CSV and Anki TSV export.
/// Cross-validates with WrongWord model and edge cases.
void main() {
  WrongWord _makeWord({
    int id = 1,
    String wrong = 'habn',
    String correct = 'haben',
    String sentence = 'Wir haben Zeit.',
    String project = 'Test',
    bool mastered = false,
    int reviewCount = 0,
  }) {
    return WrongWord(
      id: id,
      projectId: 1,
      sentenceId: 1,
      wrongForm: wrong,
      correctForm: correct,
      sentenceText: sentence,
      projectName: project,
      createdAt: DateTime.utc(2026, 6, 1),
      mastered: mastered,
      reviewCount: reviewCount,
    );
  }

  group('CsvExporter.buildWrongWordsCsv', () {
    test('header row is present', () {
      final csv = CsvExporter.buildWrongWordsCsv([]);
      expect(csv, contains('错误形式,正确形式,原文句子,来源项目,日期,已掌握'));
    });

    test('single row export', () {
      final csv = CsvExporter.buildWrongWordsCsv([_makeWord()]);
      expect(csv, contains('habn'));
      expect(csv, contains('haben'));
      expect(csv, contains('Wir haben Zeit.'));
    });

    test('escapes commas in fields', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        _makeWord(sentence: 'Hallo, Welt, hier.'),
      ]);
      expect(csv, contains('"Hallo, Welt, hier."'));
    });

    test('escapes double quotes in fields', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        _makeWord(sentence: 'Er sagte "Ja".'),
      ]);
      expect(csv, contains('"Er sagte ""Ja""."'));
    });

    test('escapes newlines in fields', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        _makeWord(sentence: 'Zeile1\nZeile2'),
      ]);
      expect(csv, contains('"Zeile1\nZeile2"'));
    });

    test('mastered status shows correctly', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        _makeWord(mastered: true),
        _makeWord(id: 2, mastered: false),
      ]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 3); // header + 2 rows
      expect(lines[1], contains('是'));
      expect(lines[2], contains('否'));
    });

    test('10 rows stress test', () {
      final words = List.generate(10, (i) => _makeWord(
        id: i,
        wrong: 'wrong$i',
        correct: 'correct$i',
        project: 'Project$i',
      ));
      final csv = CsvExporter.buildWrongWordsCsv(words);
      final lines = csv.trim().split('\n');
      expect(lines.length, 11); // header + 10 rows
    });

    test('empty list produces header only', () {
      final csv = CsvExporter.buildWrongWordsCsv([]);
      final lines = csv.trim().split('\n');
      expect(lines.length, 1);
    });

    test('German special characters preserved', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        _makeWord(wrong: 'Strasse', correct: 'Straße', sentence: 'Über die Straße.'),
      ]);
      expect(csv, contains('Straße'));
      expect(csv, contains('Über'));
    });
  });

  group('CsvExporter.buildAnkiTsv', () {
    test('header contains Anki metadata', () {
      final tsv = CsvExporter.buildAnkiTsv([]);
      expect(tsv, contains('#separator:tab'));
      expect(tsv, contains('#html:true'));
      expect(tsv, contains('#tags column:3'));
    });

    test('single card has front/back/tags', () {
      final tsv = CsvExporter.buildAnkiTsv([_makeWord()]);
      final lines = tsv.trim().split('\n');
      expect(lines.length, 4); // 3 header lines + 1 card
      final card = lines[3];
      final parts = card.split('\t');
      expect(parts.length, 3); // front, back, tags
      expect(parts[0], 'haben'); // front = correct form
      expect(parts[1], contains('<b>haben</b>')); // back has bold
      expect(parts[1], contains('Wir haben Zeit.')); // context
      expect(parts[2], 'learning'); // not mastered
    });

    test('mastered word gets "mastered" tag', () {
      final tsv = CsvExporter.buildAnkiTsv([_makeWord(mastered: true)]);
      expect(tsv, contains('\tmastered'));
    });

    test('unmastered word gets "learning" tag', () {
      final tsv = CsvExporter.buildAnkiTsv([_makeWord(mastered: false)]);
      expect(tsv, contains('\tlearning'));
    });

    test('HTML in back is well-formed', () {
      final tsv = CsvExporter.buildAnkiTsv([_makeWord()]);
      final lines = tsv.trim().split('\n');
      final back = lines[3].split('\t')[1];
      expect(back, contains('<b>'));
      expect(back, contains('</b>'));
      expect(back, contains('<i>'));
      expect(back, contains('</i>'));
      expect(back, contains('<br>'));
    });

    test('tabs in sentence text are replaced with spaces', () {
      final tsv = CsvExporter.buildAnkiTsv([
        _makeWord(sentence: 'Wort\tZwei'),
      ]);
      // Tabs should NOT appear in the card data (would break TSV)
      final lines = tsv.trim().split('\n');
      final card = lines[3];
      final parts = card.split('\t');
      expect(parts.length, 3); // Still only 3 columns
    });

    test('10 cards stress test', () {
      final words = List.generate(10, (i) => _makeWord(
        id: i,
        correct: 'Wort$i',
        sentence: 'Satz für Wort$i',
      ));
      final tsv = CsvExporter.buildAnkiTsv(words);
      final lines = tsv.trim().split('\n');
      expect(lines.length, 13); // 3 headers + 10 cards
    });

    test('newlines in sentence become <br>', () {
      final tsv = CsvExporter.buildAnkiTsv([
        _makeWord(sentence: 'Zeile eins\nZeile zwei'),
      ]);
      final lines = tsv.trim().split('\n');
      final back = lines[3].split('\t')[1];
      expect(back, contains('<br>'));
      expect(back, isNot(contains('\n'))); // No raw newlines in back
    });
  });

  group('CSV ↔ Anki cross-validation', () {
    test('same words produce consistent data in both formats', () {
      final words = [
        _makeWord(wrong: 'Strase', correct: 'Straße'),
        _makeWord(id: 2, wrong: 'gehn', correct: 'gehen', mastered: true),
      ];

      final csv = CsvExporter.buildWrongWordsCsv(words);
      final tsv = CsvExporter.buildAnkiTsv(words);

      // Both should contain the correct forms
      expect(csv, contains('Straße'));
      expect(tsv, contains('Straße'));
      expect(csv, contains('gehen'));
      expect(tsv, contains('gehen'));

      // CSV should have mastered status
      expect(csv, contains('是'));
      expect(csv, contains('否'));

      // TSV should have tags
      expect(tsv, contains('mastered'));
      expect(tsv, contains('learning'));
    });
  });
}
