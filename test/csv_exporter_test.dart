import 'package:flutter_test/flutter_test.dart';
import 'package:deutschflow/models/wrong_word.dart';
import 'package:deutschflow/services/csv_exporter.dart';

void main() {
  group('CsvExporter', () {
    test('exports wrong words with escaped CSV fields', () {
      final csv = CsvExporter.buildWrongWordsCsv([
        WrongWord(
          id: 1,
          projectId: 1,
          sentenceId: 1,
          wrongForm: 'habn',
          correctForm: 'haben',
          sentenceText: 'Wir, haben "Zeit".',
          projectName: 'Projekt A',
          createdAt: DateTime.utc(2026, 5, 24, 8, 30),
        ),
      ]);

      expect(csv, contains('错误形式,正确形式,原文句子,来源项目,日期'));
      expect(csv, contains('habn,haben,"Wir, haben ""Zeit"".",Projekt A'));
    });
  });
}
