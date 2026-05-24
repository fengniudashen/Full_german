import '../models/word_comparison.dart';

enum _TraceStep { substitute, deleteOriginal, insertTyped }

class TextComparator {
  static ComparisonResult compare(String original, String typed) {
    final originalTokens = _tokenize(original);
    final typedTokens = _tokenize(typed);
    final rowCount = originalTokens.length + 1;
    final columnCount = typedTokens.length + 1;

    final scores = List.generate(
      rowCount,
      (_) => List<double>.filled(columnCount, 0),
    );
    final trace = List.generate(
      rowCount,
      (_) => List<_TraceStep?>.filled(columnCount, null),
    );

    for (var row = 1; row < rowCount; row++) {
      scores[row][0] = row.toDouble();
      trace[row][0] = _TraceStep.deleteOriginal;
    }
    for (var column = 1; column < columnCount; column++) {
      scores[0][column] = column.toDouble();
      trace[0][column] = _TraceStep.insertTyped;
    }

    for (var row = 1; row < rowCount; row++) {
      for (var column = 1; column < columnCount; column++) {
        final substitutionCost = _substitutionCost(
          originalTokens[row - 1],
          typedTokens[column - 1],
        );
        var bestScore = scores[row - 1][column - 1] + substitutionCost;
        var bestStep = _TraceStep.substitute;

        final deleteScore = scores[row - 1][column] + 1;
        if (deleteScore < bestScore) {
          bestScore = deleteScore;
          bestStep = _TraceStep.deleteOriginal;
        }

        final insertScore = scores[row][column - 1] + 1;
        if (insertScore < bestScore) {
          bestScore = insertScore;
          bestStep = _TraceStep.insertTyped;
        }

        scores[row][column] = bestScore;
        trace[row][column] = bestStep;
      }
    }

    var row = originalTokens.length;
    var column = typedTokens.length;
    final items = <WordComparison>[];

    while (row > 0 || column > 0) {
      final step = trace[row][column];
      if (step == _TraceStep.substitute) {
        final originalToken = originalTokens[row - 1];
        final typedToken = typedTokens[column - 1];
        items.add(
          WordComparison(
            original: originalToken,
            typed: typedToken,
            status: _statusFor(originalToken, typedToken),
          ),
        );
        row--;
        column--;
      } else if (step == _TraceStep.deleteOriginal) {
        items.add(
          WordComparison(
            original: originalTokens[row - 1],
            typed: '',
            status: ComparisonStatus.wrong,
          ),
        );
        row--;
      } else {
        items.add(
          WordComparison(
            original: '',
            typed: typedTokens[column - 1],
            status: ComparisonStatus.wrong,
          ),
        );
        column--;
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
        .map((match) => match.group(0)!.trim())
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  static double _substitutionCost(String original, String typed) {
    final status = _statusFor(original, typed);
    return switch (status) {
      ComparisonStatus.correct => 0,
      ComparisonStatus.minor => 0.25,
      ComparisonStatus.wrong => 1,
    };
  }

  static ComparisonStatus _statusFor(String original, String typed) {
    if (original == typed) {
      return ComparisonStatus.correct;
    }

    final originalMinor = _canonical(
      original,
      foldCase: true,
      stripPunctuation: true,
      foldEszett: true,
    );
    final typedMinor = _canonical(
      typed,
      foldCase: true,
      stripPunctuation: true,
      foldEszett: true,
    );

    if (originalMinor.isNotEmpty && originalMinor == typedMinor) {
      return ComparisonStatus.minor;
    }

    return ComparisonStatus.wrong;
  }

  static String _canonical(
    String token, {
    bool foldCase = false,
    bool stripPunctuation = false,
    bool foldEszett = false,
  }) {
    var value = token.trim();
    if (stripPunctuation) {
      value = value.split('').where(_isLetterOrNumber).join();
    }
    if (foldCase) {
      value = value.toLowerCase();
    }
    if (foldEszett) {
      value = value.replaceAll('ß', 'ss');
    }
    return value;
  }

  static bool _isLetterOrNumber(String char) {
    return RegExp(r'[A-Za-z0-9ÄÖÜäöüß]').hasMatch(char);
  }
}
