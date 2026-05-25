import '../models/wrong_word.dart';

class CsvExporter {
  static String buildWrongWordsCsv(List<WrongWord> rows) {
    final buf = StringBuffer();
    buf.writeln('错误形式,正确形式,原文句子,来源项目,日期,已掌握');
    for (final r in rows) {
      buf.writeln([
        r.wrongForm,
        r.correctForm,
        r.sentenceText,
        r.projectName,
        r.createdAt.toIso8601String(),
        r.mastered ? '是' : '否',
      ].map(_escape).join(','));
    }
    return buf.toString();
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
