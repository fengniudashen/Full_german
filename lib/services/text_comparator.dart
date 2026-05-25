import '../models/word_comparison.dart';

enum _TraceStep { substitute, deleteOriginal, insertTyped }

class TextComparator {
  static ComparisonResult compare(String original, String typed) {
    final origTokens = _tokenize(original);
    final typedTokens = _tokenize(typed);
    final rows = origTokens.length + 1;
    final cols = typedTokens.length + 1;

    final scores = List.generate(rows, (_) => List<double>.filled(cols, 0));
    final trace = List.generate(rows, (_) => List<_TraceStep?>.filled(cols, null));

    for (var r = 1; r < rows; r++) {
      scores[r][0] = r.toDouble();
      trace[r][0] = _TraceStep.deleteOriginal;
    }
    for (var c = 1; c < cols; c++) {
      scores[0][c] = c.toDouble();
      trace[0][c] = _TraceStep.insertTyped;
    }

    for (var r = 1; r < rows; r++) {
      for (var c = 1; c < cols; c++) {
        final subCost = _substitutionCost(origTokens[r - 1], typedTokens[c - 1]);
        var bestScore = scores[r - 1][c - 1] + subCost;
        var bestStep = _TraceStep.substitute;

        final delScore = scores[r - 1][c] + 1;
        if (delScore < bestScore) {
          bestScore = delScore;
          bestStep = _TraceStep.deleteOriginal;
        }

        final insScore = scores[r][c - 1] + 1;
        if (insScore < bestScore) {
          bestScore = insScore;
          bestStep = _TraceStep.insertTyped;
        }

        scores[r][c] = bestScore;
        trace[r][c] = bestStep;
      }
    }

    var r = origTokens.length;
    var c = typedTokens.length;
    final items = <WordComparison>[];

    while (r > 0 || c > 0) {
      final step = trace[r][c];
      if (step == _TraceStep.substitute) {
        items.add(WordComparison(
          original: origTokens[r - 1],
          typed: typedTokens[c - 1],
          status: _statusFor(origTokens[r - 1], typedTokens[c - 1]),
        ));
        r--;
        c--;
      } else if (step == _TraceStep.deleteOriginal) {
        items.add(WordComparison(
          original: origTokens[r - 1],
          typed: '',
          status: ComparisonStatus.wrong,
        ));
        r--;
      } else {
        items.add(WordComparison(
          original: '',
          typed: typedTokens[c - 1],
          status: ComparisonStatus.wrong,
        ));
        c--;
      }
    }

    return ComparisonResult(items: items.reversed.toList(growable: false));
  }

  static String dictionaryKey(String token) {
    return _canonical(token, foldCase: true, stripPunctuation: true);
  }

  static List<String> _tokenize(String value) {
    return RegExp(r'\S+')
        .allMatches(value.trim())
        .map((m) => m.group(0)!.trim())
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }

  static double _substitutionCost(String a, String b) {
    return switch (_statusFor(a, b)) {
      ComparisonStatus.correct => 0,
      ComparisonStatus.minor => 0.25,
      ComparisonStatus.wrong => 1,
    };
  }

  static ComparisonStatus _statusFor(String a, String b) {
    if (a == b) return ComparisonStatus.correct;

    final ca = _canonical(a, foldCase: true, stripPunctuation: true, foldEszett: true);
    final cb = _canonical(b, foldCase: true, stripPunctuation: true, foldEszett: true);
    if (ca.isNotEmpty && ca == cb) return ComparisonStatus.minor;

    return ComparisonStatus.wrong;
  }

  static String _canonical(
    String token, {
    bool foldCase = false,
    bool stripPunctuation = false,
    bool foldEszett = false,
  }) {
    var v = token.trim();
    if (stripPunctuation) {
      v = v.split('').where(_isLetterOrNumber).join();
    }
    if (foldCase) v = v.toLowerCase();
    if (foldEszett) v = v.replaceAll('ß', 'ss');
    return v;
  }

  static bool _isLetterOrNumber(String ch) {
    return RegExp(r'[A-Za-z0-9ÄÖÜäöüß]').hasMatch(ch);
  }
}
