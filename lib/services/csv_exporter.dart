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

  /// Export in Anki-compatible TSV format.
  /// Columns: Front (German word) \t Back (context sentence + correct form)
  /// Anki imports TSV with tab separator by default.
  static String buildAnkiTsv(List<WrongWord> rows) {
    final buf = StringBuffer();
    buf.writeln('#separator:tab');
    buf.writeln('#html:true');
    buf.writeln('#tags column:3');
    for (final r in rows) {
      final front = r.correctForm;
      final back = '<b>${r.correctForm}</b><br><br>'
          '<i>${r.sentenceText}</i><br><br>'
          '来源: ${r.projectName}';
      final tags = r.mastered ? 'mastered' : 'learning';
      buf.writeln('${_escapeTsv(front)}\t${_escapeTsv(back)}\t$tags');
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

  static String _escapeTsv(String value) {
    return value
        .replaceAll('\t', ' ')
        .replaceAll('\n', '<br>')
        .replaceAll('\r', '');
  }
}
