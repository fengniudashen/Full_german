import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wrong_word.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import 'analysis_page.dart';

/// 句海拾遗 & 词海拾遗 — Random rediscovery of sentences and words.
class DiscoveryPage extends StatefulWidget {
  const DiscoveryPage({super.key});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

class _DiscoveryPageState extends State<DiscoveryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  List<Map<String, dynamic>> _sentences = [];
  List<WrongWord> _words = [];
  bool _loadingSentences = true;
  bool _loadingWords = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSentences();
    _loadWords();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSentences() async {
    setState(() => _loadingSentences = true);
    final rows =
        await context.read<AppState>().database.getRandomSentences(10);
    if (!mounted) return;
    setState(() {
      _sentences = rows;
      _loadingSentences = false;
    });
  }

  Future<void> _loadWords() async {
    setState(() => _loadingWords = true);
    final words =
        await context.read<AppState>().database.getRandomWrongWords(10);
    if (!mounted) return;
    setState(() {
      _words = words;
      _loadingWords = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🌊 拾遗'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: '句海拾遗'),
            Tab(text: '词海拾遗'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildSentenceTab(theme),
          _buildWordTab(theme),
        ],
      ),
    );
  }

  Widget _buildSentenceTab(ThemeData theme) {
    if (_loadingSentences) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_sentences.isEmpty) {
      return const EmptyState(
        icon: Icons.waves,
        title: '还没有句子',
        message: '先导入一些项目开始学习吧',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSentences,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sentences.length + 1,
        itemBuilder: (context, i) {
          if (i == _sentences.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: FilledButton.tonal(
                  onPressed: _loadSentences,
                  child: const Text('🎲 换一批'),
                ),
              ),
            );
          }
          final s = _sentences[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: ListTile(
                title: Text(
                  s['text'] as String,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
                subtitle: Text(
                  s['project_name'] as String,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: s['text'] as String));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.auto_awesome, size: 20),
                      tooltip: 'AI 分析',
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => AnalysisPage(
                            initialSentence: s['text'] as String,
                          ),
                        ));
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWordTab(ThemeData theme) {
    if (_loadingWords) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty) {
      return const EmptyState(
        icon: Icons.text_fields,
        title: '还没有错词',
        message: '完成一些听写练习后这里会出现待复习的词',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadWords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _words.length + 1,
        itemBuilder: (context, i) {
          if (i == _words.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: FilledButton.tonal(
                  onPressed: _loadWords,
                  child: const Text('🎲 换一批'),
                ),
              ),
            );
          }
          final w = _words[i];
          final isDark = theme.brightness == Brightness.dark;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GlassCard(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      isDark ? AppTheme.wrongBgDark : AppTheme.wrongBg,
                  child: Text(
                    w.wrongForm.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: w.wrongForm,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: isDark
                              ? AppTheme.wrongFgDark
                              : AppTheme.wrongFg,
                        ),
                      ),
                      const TextSpan(text: '  →  '),
                      TextSpan(
                        text: w.correctForm,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ],
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                subtitle: Text(
                  '${w.projectName} · ${w.sentenceText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  tooltip: 'AI 分析',
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AnalysisPage(
                        initialSentence: w.sentenceText,
                        initialWord: w.correctForm,
                      ),
                    ));
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
