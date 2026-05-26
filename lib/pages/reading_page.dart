import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

/// Reading mode — displays project text with tap-to-lookup for any word.
/// Tapping a word shows dictionary definition + AI grammar analysis.
class ReadingPage extends StatefulWidget {
  const ReadingPage({
    super.key,
    required this.projectId,
    required this.sentences,
    required this.projectName,
  });

  final int projectId;
  final List<String> sentences;
  final String projectName;

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage> {
  final DictionaryService _dict = DictionaryService();
  final ScrollController _scrollCtrl = ScrollController();

  String? _selectedWord;
  DictionaryEntry? _dictEntry;
  String? _aiAnalysis;
  bool _loadingDict = false;
  bool _loadingAi = false;
  int _fontSize = 18;

  @override
  void dispose() {
    _dict.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _onWordTap(String word) async {
    // Strip punctuation
    final clean = word.replaceAll(RegExp(r'[^\w\u00C0-\u024FäöüÄÖÜß]'), '');
    if (clean.isEmpty) return;

    setState(() {
      _selectedWord = clean;
      _dictEntry = null;
      _aiAnalysis = null;
      _loadingDict = true;
      _loadingAi = false;
    });

    try {
      final entry = await _dict.lookup(clean);
      if (mounted) {
        setState(() {
          _dictEntry = entry;
          _loadingDict = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingDict = false);
      }
    }
  }

  Future<void> _fetchAiAnalysis(String word, String sentence) async {
    setState(() => _loadingAi = true);
    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);
      final result = await service.lookupWord(word, sentence);
      if (mounted) {
        setState(() {
          _aiAnalysis = result;
          _loadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAnalysis = '分析失败: $e';
          _loadingAi = false;
        });
      }
    }
  }

  /// Find which sentence contains the tapped word.
  String _findContext(String word) {
    for (final s in widget.sentences) {
      if (s.toLowerCase().contains(word.toLowerCase())) return s;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('阅读: ${widget.projectName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.text_decrease),
            onPressed: () => setState(() => _fontSize = (_fontSize - 2).clamp(12, 32)),
            tooltip: '缩小字体',
          ),
          IconButton(
            icon: const Icon(Icons.text_increase),
            onPressed: () => setState(() => _fontSize = (_fontSize + 2).clamp(12, 32)),
            tooltip: '放大字体',
          ),
        ],
      ),
      body: Column(
        children: [
          // Text area
          Expanded(
            flex: _selectedWord != null ? 5 : 10,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              child: _buildText(theme, scheme),
            ),
          ),
          // Dictionary panel
          if (_selectedWord != null)
            Expanded(
              flex: 5,
              child: _buildLookupPanel(theme, scheme),
            ),
        ],
      ),
    );
  }

  Widget _buildText(ThemeData theme, ColorScheme scheme) {
    final spans = <InlineSpan>[];

    for (int si = 0; si < widget.sentences.length; si++) {
      if (si > 0) spans.add(const TextSpan(text: '  '));

      final sentence = widget.sentences[si];
      // Split preserving punctuation attached to words
      final parts = sentence.split(RegExp(r'(\s+)'));

      for (final part in parts) {
        if (part.trim().isEmpty) {
          spans.add(TextSpan(text: part));
          continue;
        }

        final isSelected = _selectedWord != null &&
            part.toLowerCase().contains(_selectedWord!.toLowerCase());

        spans.add(WidgetSpan(
          child: GestureDetector(
            onTap: () => _onWordTap(part),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
              decoration: isSelected
                  ? BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                part,
                style: TextStyle(
                  fontSize: _fontSize.toDouble(),
                  height: 1.8,
                  color: isSelected ? scheme.primary : scheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ));
        spans.add(const TextSpan(text: ' '));
      }
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _buildLookupPanel(ThemeData theme, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedWord ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ),
                if (!_loadingAi && _aiAnalysis == null)
                  TextButton.icon(
                    onPressed: () {
                      final ctx = _findContext(_selectedWord!);
                      _fetchAiAnalysis(_selectedWord!, ctx);
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('AI 解析'),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() => _selectedWord = null),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _loadingDict
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_dictEntry != null) ...[
                          Text(
                            '词典释义',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '来源: ${_dictEntry!.source}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...(_dictEntry!.definitions.map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $d',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      height: 1.5,
                                    )),
                              ))),
                        ],
                        if (_loadingAi) ...[
                          const SizedBox(height: 16),
                          const Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('AI 分析中…'),
                              ],
                            ),
                          ),
                        ],
                        if (_aiAnalysis != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'AI 分析',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.deepPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _aiAnalysis!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.6,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
