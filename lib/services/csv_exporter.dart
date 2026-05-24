import '../models/wrong_word.dart';

class CsvExporter {
  static String buildWrongWordsCsv(List<WrongWord> rows) {
    final buffer = StringBuffer();
    buffer.writeln('错误形式,正确形式,原文句子,来源项目,日期');

    for (final row in rows) {
      buffer.writeln([
        row.wrongForm,
        row.correctForm,
        row.sentenceText,
        row.projectName,
        row.createdAt.toIso8601String(),
      ].map(_escape).join(','));
    }

    return buffer.toString();
  }

  static String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    final needsQuotes = escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r');
    return needsQuotes ? '"$escaped"' : escaped;
  }
}
