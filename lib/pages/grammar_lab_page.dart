import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

/// German grammar visualization — compound word splitter, gender color coding,
/// and Satzklammer (sentence bracket) arc visualization.
class GrammarLabPage extends StatefulWidget {
  const GrammarLabPage({super.key, this.initialText});
  final String? initialText;

  @override
  State<GrammarLabPage> createState() => _GrammarLabPageState();
}

class _GrammarLabPageState extends State<GrammarLabPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _inputCtrl = TextEditingController();

  // Compound splitter
  String? _compoundResult;
  bool _compoundLoading = false;

  // Gender color coding
  String? _genderResult;
  bool _genderLoading = false;

  // Satzklammer
  String? _bracketResult;
  bool _bracketLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    if (widget.initialText != null) {
      _inputCtrl.text = widget.initialText!;
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _inputCtrl.dispose();
    super.dispose();
  }

  AiService get _ai {
    final provider = context.read<AppState>().settings.activeProvider;
    return AiService(provider: provider);
  }

  Future<void> _analyzeCompound() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _compoundLoading = true; _compoundResult = null; });
    try {
      final result = await _ai.chatRaw(
        '请拆解以下德语复合词，并给出详细分析：\n\n$text\n\n'
        '对每个词(如果有多个)，请给出：\n'
        '1. **完整词**: 原词 + 词性 + 中文释义\n'
        '2. **拆解**: 用 + 号连接各词根，标注每个词根的词性和含义\n'
        '3. **构词规律**: 解释复合词的构成规则（如连接元素 -s-, -n- 等）\n'
        '4. **记忆技巧**: 联想记忆或词根故事\n'
        '5. **同类复合词**: 列出3个类似结构的复合词\n\n'
        '用Markdown格式，德语加粗。如果输入的不是复合词，也请说明词根词源。',
        systemMessage: '你是一位德语词汇学专家，擅长词根词缀分析和复合词拆解。'
            '不要输出<think>标签。',
      );
      if (mounted) setState(() { _compoundResult = result; _compoundLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _compoundResult = '分析失败: $e'; _compoundLoading = false; });
    }
  }

  Future<void> _analyzeGender() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _genderLoading = true; _genderResult = null; });
    try {
      final result = await _ai.chatRaw(
        '请对以下德语文本中的每个名词进行词性标注和格分析：\n\n$text\n\n'
        '请用以下格式输出：\n\n'
        '## 🔵🔴🟢 名词词性标注\n'
        '列出文本中所有名词，用颜色emoji标记：\n'
        '- 🔵 阳性 (der) → 蓝色\n'
        '- 🔴 阴性 (die) → 红色\n'
        '- 🟢 中性 (das) → 绿色\n'
        '- 🟡 复数 (die/Plural) → 黄色\n\n'
        '每个名词给出：emoji + 原文形式 + 原形(主格单数) + 词性 + 该句中的格(N/A/D/G) + 复数形式\n\n'
        '## 📝 介词+格 搭配\n'
        '列出文本中所有介词及其支配的格\n\n'
        '## 💡 词性记忆规律\n'
        '指出文本中符合词性规律的名词(如 -ung结尾必为阴性)\n\n'
        '用Markdown格式，保留emoji颜色标记。',
        systemMessage: '你是一位德语语法专家，精通名词词性和四格系统。'
            '不要输出<think>标签。',
      );
      if (mounted) setState(() { _genderResult = result; _genderLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _genderResult = '分析失败: $e'; _genderLoading = false; });
    }
  }

  Future<void> _analyzeBracket() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _bracketLoading = true; _bracketResult = null; });
    try {
      final result = await _ai.chatRaw(
        '请分析以下德语句子的框形结构(Satzklammer)和语序：\n\n$text\n\n'
        '请提供：\n\n'
        '## 🌉 框形结构分析\n'
        '对每个句子：\n'
        '1. 标出**变位动词**位置（V2位/末尾）\n'
        '2. 如有框形结构，用 【…】 标出左括号和右括号\n'
        '   例如: Er 【hat】 gestern ein Buch 【gelesen】.\n'
        '3. 标注可分动词的前缀分离情况\n\n'
        '## 📐 句法结构\n'
        '- 标出前场(Vorfeld)、中场(Mittelfeld)、后场(Nachfeld)\n'
        '- 标明主从句关系\n'
        '- 从句中的动词末尾语序\n\n'
        '## 🔗 主从句连接\n'
        '- 列出连词(因为/虽然/当…)及其对语序的影响\n\n'
        '## 💡 语序口诀\n'
        '- 总结该句涉及的德语语序规则\n\n'
        '用Markdown格式，关键德语结构加粗。',
        systemMessage: '你是一位德语句法学专家，擅长框形结构和语序分析。'
            '不要输出<think>标签。',
      );
      if (mounted) setState(() { _bracketResult = result; _bracketLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _bracketResult = '分析失败: $e'; _bracketLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('语法实验室'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.broken_image_outlined, size: 18), text: '复合词拆解'),
            Tab(icon: Icon(Icons.palette, size: 18), text: '词性色彩'),
            Tab(icon: Icon(Icons.architecture, size: 18), text: '框形结构'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Shared input area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '输入德语单词或句子…',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _runCurrentTab,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.science, size: 18),
                  label: const Text('分析'),
                ),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTab(_compoundResult, _compoundLoading, _compoundQuickWords, theme),
                _buildTab(_genderResult, _genderLoading, _genderQuickSentences, theme),
                _buildTab(_bracketResult, _bracketLoading, _bracketQuickSentences, theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool get _isLoading => _compoundLoading || _genderLoading || _bracketLoading;

  void _runCurrentTab() {
    switch (_tabCtrl.index) {
      case 0: _analyzeCompound(); break;
      case 1: _analyzeGender(); break;
      case 2: _analyzeBracket(); break;
    }
  }

  static const _compoundQuickWords = [
    'Handschuh', 'Kühlschrank', 'Krankenhaus', 'Sehenswürdigkeit',
    'Ausbildungsplatz', 'Steuererklärung', 'Geschwindigkeitsbegrenzung',
  ];

  static const _genderQuickSentences = [
    'Der Mann gibt dem Kind das Buch der Lehrerin.',
    'Die Entscheidung des Präsidenten überraschte die Bevölkerung.',
    'Wegen des schlechten Wetters blieben wir zu Hause.',
  ];

  static const _bracketQuickSentences = [
    'Er hat gestern ein neues Auto gekauft.',
    'Sie ruft ihre Mutter an, weil sie Hilfe braucht.',
    'Obwohl er müde war, hat er die Arbeit fertig gemacht.',
  ];

  Widget _buildTab(String? result, bool loading, List<String> quickItems, ThemeData theme) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (result != null) {
      return ResponsivePage(
        maxWidth: 900,
        child: MarkdownBody(
          data: result,
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            strong: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }
    // Quick suggestions
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: quickItems.map((s) => ActionChip(
          label: Text(s, style: const TextStyle(fontSize: 13)),
          onPressed: () {
            _inputCtrl.text = s;
            _runCurrentTab();
          },
        )).toList(),
      ),
    );
  }
}
