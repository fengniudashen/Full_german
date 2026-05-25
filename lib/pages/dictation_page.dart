import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider.dart';
import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/text_comparator.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/comparison_result_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';
import 'analysis_page.dart';
import 'shadowing_page.dart';

class DictationPage extends StatefulWidget {
  const DictationPage({super.key, required this.projectId});
  final int projectId;

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  static const _quickChars = ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü', 'ẞ'];
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _answerCtrl = TextEditingController();
  final FocusNode _answerFocus = FocusNode();
  StreamSubscription<Duration>? _posSub;

  StudyProject? _project;
  List<StudySentence> _sentences = const [];
  Map<int, String> _answers = {};
  int _index = 0;
  double _speed = 1.0;
  Duration? _stopAt;
  bool _loading = true;
  bool _checking = false;
  bool _focusMode = false; // Immersion mode: hide hints & progress
  bool _showFullText = false; // Reveal full sentence for interactive analysis
  String? _error;
  int _sessionId = 0;
  int _sessionCorrect = 0;
  int _sessionWrong = 0;
  DateTime? _sessionStart;

  // Audio progress & loop state
  Duration _currentPos = Duration.zero;
  bool _loopSentence = false;
  bool _rangeLoopEnabled = false;
  double _loopStartFrac = 0.0; // 0.0–1.0 within sentence
  double _loopEndFrac = 1.0;   // 0.0–1.0 within sentence

  StudySentence? get _current =>
      _sentences.isEmpty ? null : _sentences[_clamp(_index)];

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen(_handlePosition);
    _load();
  }

  @override
  void dispose() {
    _saveSession();
    _posSub?.cancel();
    _player.dispose();
    _answerCtrl.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showHints = context.watch<AppState>().settings.showHints;

    return Scaffold(
      appBar: AppBar(
        title: Text(_focusMode ? '专注听写' : (_project?.name ?? '听写练习')),
        actions: [
          // Focus mode toggle
          IconButton(
            icon: Icon(_focusMode
                ? Icons.visibility_off
                : Icons.visibility),
            tooltip: _focusMode ? '退出专注模式' : '专注模式（隐藏提示）',
            onPressed: () => setState(() => _focusMode = !_focusMode),
          ),
          // Shadowing mode
          if (_project != null)
            IconButton(
              icon: const Icon(Icons.record_voice_over),
              tooltip: '跟读模式',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ShadowingPage(projectId: widget.projectId),
                  ),
                );
              },
            ),
          // AI analysis
          if (_project != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 分析 (查词/语法/翻译)',
              onPressed: () {
                final sentence = _current?.text;
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AnalysisPage(
                      initialSentence: sentence,
                    ),
                  ),
                );
              },
            ),
          // Speed control
          PopupMenuButton<double>(
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.speed, size: 18),
                const SizedBox(width: 4),
                Text('${_speed}x',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
            onSelected: _setSpeed,
            itemBuilder: (_) => _speeds
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text('${s}x',
                          style: TextStyle(
                              fontWeight: s == _speed
                                  ? FontWeight.w800
                                  : FontWeight.w500)),
                    ))
                .toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.f5): _playCurrentSentence,
          const SingleActivator(LogicalKeyboardKey.enter, control: true):
              _checkAnswer,
        },
        child: Focus(
          autofocus: true,
          child: _buildBody(context, showHints),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool showHints) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final s = _current;
    if (s == null) return const Center(child: Text('没有可练习的句子'));

    return ResponsivePage(
      maxWidth: 980,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressCard(s),
          const SizedBox(height: 16),
          if (showHints && !_focusMode) ...[
            _buildHintCard(s),
            const SizedBox(height: 16),
          ],
          _buildAnswerCard(),
          const SizedBox(height: 16),
          if (!_focusMode) _buildNavigation(),
          // Round indicator
          if (!_focusMode && s.attemptCount > 0) ...[
            const SizedBox(height: 12),
            _buildRoundIndicator(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressCard(StudySentence s) {
    final theme = Theme.of(context);
    final progress = _sentences.isEmpty ? 0.0 : (_index + 1) / _sentences.length;
    final sentenceDur = s.endMs - s.startMs;
    final posInSentence =
        (_currentPos.inMilliseconds - s.startMs).clamp(0, sentenceDur);
    final posFrac = sentenceDur > 0 ? posInSentence / sentenceDur : 0.0;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppTheme.borderSm,
                ),
                child: Text(
                  '第 ${_index + 1} / ${_sentences.length} 句',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const Spacer(),
              // Bookmark button
              IconButton(
                icon: Icon(
                  s.bookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: s.bookmarked ? AppTheme.gold : null,
                ),
                tooltip: s.bookmarked ? '取消收藏' : '收藏此句',
                onPressed: () => _toggleBookmark(s),
              ),
              Text(
                '${formatDurationMs(s.startMs)} – ${formatDurationMs(s.endMs)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 14),

          // ── Audio progress bar with loop region ──
          if (s.hasValidRange) ...[
            _buildAudioProgressBar(s, theme, sentenceDur, posFrac),
            const SizedBox(height: 6),
            // Time labels
            Row(
              children: [
                Text(
                  formatDurationMs(s.startMs + posInSentence),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDurationMs(s.endMs),
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFeatures: [const FontFeature.tabularFigures()],
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Control buttons row
            Row(
              children: [
                // Play / Pause
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _playCurrentSentence,
                    icon: StreamBuilder<bool>(
                      stream: _player.playingStream,
                      builder: (_, snap) => Icon(
                        (snap.data ?? false) ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                    label: const Text('播放'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Sentence loop toggle
                _LoopButton(
                  icon: Icons.repeat_one,
                  tooltip: '整句循环',
                  active: _loopSentence,
                  onPressed: () {
                    setState(() {
                      _loopSentence = !_loopSentence;
                      if (_loopSentence) _rangeLoopEnabled = false;
                    });
                  },
                ),
                const SizedBox(width: 4),
                // Range loop toggle
                _LoopButton(
                  icon: Icons.repeat,
                  tooltip: '区间循环 (拖拽下方滑块)',
                  active: _rangeLoopEnabled,
                  onPressed: () {
                    setState(() {
                      _rangeLoopEnabled = !_rangeLoopEnabled;
                      if (_rangeLoopEnabled) _loopSentence = false;
                    });
                  },
                ),
              ],
            ),
            // Range slider for custom loop (only when range loop enabled)
            if (_rangeLoopEnabled) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.linear_scale,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('拖拽设置循环区间',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                ],
              ),
              RangeSlider(
                values: RangeValues(_loopStartFrac, _loopEndFrac),
                onChanged: (v) {
                  setState(() {
                    _loopStartFrac = v.start;
                    _loopEndFrac = v.end;
                  });
                },
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.surfaceContainerHighest,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatDurationMs(
                          s.startMs + (sentenceDur * _loopStartFrac).round()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      formatDurationMs(
                          s.startMs + (sentenceDur * _loopEndFrac).round()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontFeatures: [const FontFeature.tabularFigures()],
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('播放当前句'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],

          if (s.attemptCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 14,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '已练习 ${s.attemptCount} 次 · 正确 ${s.correctCount} 次',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Build the audio waveform-style progress bar.
  Widget _buildAudioProgressBar(
      StudySentence s, ThemeData theme, int sentenceDur, double posFrac) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onTapDown: (details) {
            if (sentenceDur <= 0) return;
            final frac = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final seekMs = s.startMs + (sentenceDur * frac).round();
            _player.seek(Duration(milliseconds: seekMs));
          },
          onHorizontalDragUpdate: (details) {
            if (sentenceDur <= 0) return;
            final frac = (details.localPosition.dx / width).clamp(0.0, 1.0);
            final seekMs = s.startMs + (sentenceDur * frac).round();
            _player.seek(Duration(milliseconds: seekMs));
          },
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                size: Size(width, 36),
                painter: _AudioProgressPainter(
                  progress: posFrac,
                  loopStart: _rangeLoopEnabled ? _loopStartFrac : null,
                  loopEnd: _rangeLoopEnabled ? _loopEndFrac : null,
                  progressColor: theme.colorScheme.primary,
                  loopColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                  cursorColor: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHintCard(StudySentence s) {
    final theme = Theme.of(context);
    final words = s.text.split(RegExp(r'\s+'));
    final hintText = words
        .map((w) => w.length <= 2
            ? w
            : '${w[0]}${'·' * (w.length - 2)}${w[w.length - 1]}')
        .join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          borderColor: AppTheme.gold.withValues(alpha: 0.3),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppTheme.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(hintText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ),
              // Toggle full text
              IconButton(
                icon: Icon(
                  _showFullText ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                tooltip: _showFullText ? '隐藏原文' : '显示原文 (点击词汇可AI分析)',
                onPressed: () => setState(() => _showFullText = !_showFullText),
              ),
            ],
          ),
        ),
        // Full interactive text
        if (_showFullText) ...[
          const SizedBox(height: 8),
          _buildInteractiveText(s),
        ],
      ],
    );
  }

  /// Build interactive text where each word is tappable for AI actions.
  Widget _buildInteractiveText(StudySentence s) {
    final theme = Theme.of(context);
    final words = s.text.split(RegExp(r'\s+'));

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('点击词汇即可 AI 分析 · 长按框选片段',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: words.map((word) {
              return _WordChip(
                word: word,
                sentenceContext: s.text,
                onAiAction: _handleAiAction,
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          // Phrase selection: full sentence tap for grammar/translate
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAiAction(
                    _AiAction.grammar, s.text, s.text,
                  ),
                  icon: const Icon(Icons.schema_outlined, size: 16),
                  label: const Text('整句语法'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAiAction(
                    _AiAction.translate, s.text, s.text,
                  ),
                  icon: const Icon(Icons.g_translate, size: 16),
                  label: const Text('整句翻译'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAiAction(
                    _AiAction.rewrite, s.text, s.text,
                  ),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('改写'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleAiAction(
                    _AiAction.pronunciation, s.text, s.text,
                  ),
                  icon: const Icon(Icons.record_voice_over, size: 16),
                  label: const Text('口语教练'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Handle an AI action triggered from word/phrase interaction.
  void _handleAiAction(_AiAction action, String text, String sentenceCtx) {
    switch (action) {
      case _AiAction.openAnalysis:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AnalysisPage(
              initialSentence: sentenceCtx,
              initialWord: text != sentenceCtx ? text : null,
            ),
          ),
        );
      case _AiAction.lookup:
      case _AiAction.grammar:
      case _AiAction.translate:
      case _AiAction.phrase:
      case _AiAction.makeSentences:
      case _AiAction.synonyms:
      case _AiAction.antonyms:
      case _AiAction.conjugate:
      case _AiAction.rewrite:
      case _AiAction.pronunciation:
        _showAiQuickResult(action, text, sentenceCtx);
    }
  }

  /// Show AI result in a bottom sheet without leaving the page.
  Future<void> _showAiQuickResult(
      _AiAction action, String text, String sentenceCtx) async {
    final provider = context.read<AppState>().settings.activeProvider;
    if (!provider.hasKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('请先在设置中配置 ${provider.name} 的 API Key'),
        ),
      );
      return;
    }

    // Show bottom sheet with loading state
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AiResultSheet(
        action: action,
        text: text,
        sentenceContext: sentenceCtx,
        provider: provider,
      ),
    );
  }

  Widget _buildAnswerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Quick character buttons
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickChars
                .map((c) => SizedBox(
                      width: 44,
                      height: 38,
                      child: OutlinedButton(
                        onPressed: () => _insertChar(c),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: Text(c),
                      ),
                    ))
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _answerCtrl,
            focusNode: _answerFocus,
            minLines: 4,
            maxLines: 8,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _checkAnswer(),
            decoration: const InputDecoration(
              labelText: '听写输入',
              alignLabelWithHint: true,
              hintText: '输入你听到的德语句子…',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _checking ? null : _checkAnswer,
            icon: _checking
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fact_check_outlined),
            label: const Text('核对'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigation() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _index == 0 ? null : () => _goTo(_index - 1),
            icon: const Icon(Icons.chevron_left),
            label: const Text('上一句'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed:
                _index >= _sentences.length - 1 ? null : () => _goTo(_index + 1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('下一句'),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundIndicator() {
    final theme = Theme.of(context);
    // Calculate round: how many complete passes through all sentences
    final totalAttempts = _sentences.fold<int>(0, (s, e) => s + e.attemptCount);
    final round = _sentences.isEmpty
        ? 1
        : (totalAttempts / _sentences.length).floor() + 1;
    final perfectCount =
        _sentences.where((s) => s.attemptCount > 0 && s.correctCount > 0).length;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.loop, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('第 $round 轮',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              )),
          const SizedBox(width: 16),
          Icon(Icons.check_circle_outline, size: 14,
              color: AppTheme.emerald),
          const SizedBox(width: 4),
          Text('$perfectCount / ${_sentences.length} 全对',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
          const Spacer(),
          Text('尚雯婕法 · 第1步：盲听听写',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              )),
        ],
      ),
    );
  }

  // ─── Logic ──────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final db = context.read<AppState>().database;
      final project = await db.getProject(widget.projectId);
      if (project == null) {
        setState(() {
          _loading = false;
          _error = '项目不存在或已被删除。';
        });
        return;
      }
      final sentences = await db.getSentencesForProject(widget.projectId);
      final answers = await db.getLatestDictations(widget.projectId);

      // Load audio file with error handling
      final audioPath = project.audioPath;
      if (audioPath.isEmpty) {
        setState(() {
          _loading = false;
          _error = '音频文件路径为空。请重新导入音频。';
        });
        return;
      }

      final audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        setState(() {
          _loading = false;
          _error = '音频文件不存在：\n$audioPath\n\n请删除此项目后重新下载。';
        });
        return;
      }

      try {
        await _player.setFilePath(audioPath);
      } catch (e) {
        setState(() {
          _loading = false;
          _error = '无法加载音频文件：\n$audioPath\n\n'
              '文件大小：${(audioFile.lengthSync() / 1024).toStringAsFixed(0)} KB\n'
              '错误：$e';
        });
        return;
      }

      // Start session
      _sessionId = await db.createSession(widget.projectId);
      _sessionStart = DateTime.now();

      // Apply saved speed
      final appState = context.read<AppState>();
      _speed = appState.settings.playbackSpeed;
      await _player.setSpeed(_speed);

      if (!mounted) return;
      setState(() {
        _project = project;
        _sentences = sentences;
        _answers = answers;
        _loading = false;
      });
      _syncAnswer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败：$e';
      });
    }
  }

  Future<void> _reloadSentences() async {
    final sentences = await context
        .read<AppState>()
        .database
        .getSentencesForProject(widget.projectId);
    if (!mounted) return;
    setState(() => _sentences = sentences);
  }

  void _handlePosition(Duration pos) {
    if (mounted) setState(() => _currentPos = pos);

    final s = _current;
    if (s == null || !s.hasValidRange) return;

    final sentenceEnd = Duration(milliseconds: s.endMs);
    final sentenceStart = Duration(milliseconds: s.startMs);
    final sentenceDur = s.endMs - s.startMs;

    if (_rangeLoopEnabled && sentenceDur > 0) {
      final loopEnd = Duration(
        milliseconds: s.startMs + (sentenceDur * _loopEndFrac).round(),
      );
      final loopStart = Duration(
        milliseconds: s.startMs + (sentenceDur * _loopStartFrac).round(),
      );
      if (pos >= loopEnd) {
        _player.seek(loopStart);
        return;
      }
    } else if (_loopSentence) {
      if (pos >= sentenceEnd) {
        _player.seek(sentenceStart);
        return;
      }
    }

    // Non-loop: stop at sentence end
    final stop = _stopAt;
    if (stop != null && pos >= stop) {
      _stopAt = null;
      _player.pause();
      _player.seek(stop);
    }
  }

  Future<void> _playCurrentSentence() async {
    final s = _current;
    if (s == null || !s.hasValidRange) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
            '无法播放：句子没有有效的时间范围 '
            '(start=${s?.startMs ?? 0}ms, end=${s?.endMs ?? 0}ms)',
          )),
        );
      }
      return;
    }
    _cacheAnswer();

    // Toggle play/pause
    if (_player.playing) {
      await _player.pause();
      return;
    }

    // Determine start position
    final sentenceDur = s.endMs - s.startMs;
    int seekMs;
    if (_rangeLoopEnabled) {
      seekMs = s.startMs + (sentenceDur * _loopStartFrac).round();
    } else {
      seekMs = s.startMs;
    }

    _stopAt = (_loopSentence || _rangeLoopEnabled)
        ? null // Loop modes handle stopping in _handlePosition
        : Duration(milliseconds: s.endMs);
    try {
      await _player.pause();
      await _player.seek(Duration(milliseconds: seekMs));
      await _player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败：$e')),
        );
      }
    }
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _speed = speed);
    await _player.setSpeed(speed);
    await context.read<AppState>().updatePlaybackSpeed(speed);
  }

  Future<void> _checkAnswer() async {
    final s = _current;
    if (s == null) return;
    _cacheAnswer();
    setState(() => _checking = true);
    try {
      final appState = context.read<AppState>();
      final db = appState.database;
      final answer = _answerCtrl.text.trim();
      final result = TextComparator.compare(s.text, answer);

      await db.saveDictation(
        projectId: widget.projectId,
        sentenceId: s.id,
        userInput: answer,
        correctCount: result.correctCount,
        wrongCount: result.wrongCount,
      );
      await db.insertWrongWords(
        projectId: widget.projectId,
        sentenceId: s.id,
        sentenceText: s.text,
        errors: result.redErrors,
      );

      _sessionCorrect += result.correctCount;
      _sessionWrong += result.wrongCount;

      await appState.loadWrongWords();

      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ComparisonResultSheet(
          sentence: s,
          result: result,
          onSaveNote: (note) async {
            await db.updateSentenceNote(s.id, note);
            await _reloadSentences();
          },
        ),
      );

      // Auto-advance
      final autoAdv = appState.settings.autoAdvance;
      if (autoAdv && _index < _sentences.length - 1) {
        _goTo(_index + 1);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _toggleBookmark(StudySentence s) async {
    await context.read<AppState>().database.toggleBookmark(s.id, !s.bookmarked);
    await _reloadSentences();
  }

  void _insertChar(String char) {
    final text = _answerCtrl.text;
    final sel = _answerCtrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final next = text.replaceRange(start, end, char);
    _answerCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + char.length),
    );
    _answerFocus.requestFocus();
  }

  void _goTo(int next) {
    _cacheAnswer();
    _player.pause();
    setState(() {
      _index = _clamp(next);
      // Reset loop range when changing sentences
      _loopStartFrac = 0.0;
      _loopEndFrac = 1.0;
    });
    _syncAnswer();
  }

  void _cacheAnswer() {
    final s = _current;
    if (s == null) return;
    _answers = Map<int, String>.from(_answers)..[s.id] = _answerCtrl.text;
  }

  void _syncAnswer() {
    final s = _current;
    final t = s == null ? '' : _answers[s.id] ?? '';
    _answerCtrl.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
    );
  }

  Future<void> _saveSession() async {
    if (_sessionId == 0 || _sessionStart == null) return;
    try {
      final dur = DateTime.now().difference(_sessionStart!).inMilliseconds;
      await context.read<AppState>().database.updateSession(
            sessionId: _sessionId,
            sentencesPracticed: _index + 1,
            correctCount: _sessionCorrect,
            wrongCount: _sessionWrong,
            durationMs: dur,
          );
    } catch (_) {}
  }

  int _clamp(int v) {
    if (_sentences.isEmpty) return 0;
    return v.clamp(0, _sentences.length - 1).toInt();
  }
}

/// Toggle button for loop modes.
class _LoopButton extends StatelessWidget {
  const _LoopButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? theme.colorScheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the audio progress bar with optional loop region.
class _AudioProgressPainter extends CustomPainter {
  _AudioProgressPainter({
    required this.progress,
    this.loopStart,
    this.loopEnd,
    required this.progressColor,
    required this.loopColor,
    required this.cursorColor,
  });

  final double progress;
  final double? loopStart;
  final double? loopEnd;
  final Color progressColor;
  final Color loopColor;
  final Color cursorColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Draw loop region highlight
    if (loopStart != null && loopEnd != null) {
      final loopRect = Rect.fromLTWH(
        size.width * loopStart!,
        0,
        size.width * (loopEnd! - loopStart!),
        size.height,
      );
      canvas.drawRect(
        loopRect,
        Paint()..color = loopColor,
      );
      // Draw loop boundary lines
      final boundaryPaint = Paint()
        ..color = progressColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(loopRect.left, 0),
        Offset(loopRect.left, size.height),
        boundaryPaint,
      );
      canvas.drawLine(
        Offset(loopRect.right, 0),
        Offset(loopRect.right, size.height),
        boundaryPaint,
      );
    }

    // Draw progress fill
    final progressRect = Rect.fromLTWH(
      0,
      0,
      size.width * progress.clamp(0.0, 1.0),
      size.height,
    );
    canvas.drawRect(
      progressRect,
      Paint()..color = progressColor.withValues(alpha: 0.3),
    );

    // Draw playback cursor
    final cursorX = size.width * progress.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(cursorX, 0),
      Offset(cursorX, size.height),
      Paint()
        ..color = cursorColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // Draw small circle at cursor top
    canvas.drawCircle(
      Offset(cursorX, 3),
      3,
      Paint()..color = cursorColor,
    );
  }

  @override
  bool shouldRepaint(_AudioProgressPainter old) =>
      old.progress != progress ||
      old.loopStart != loopStart ||
      old.loopEnd != loopEnd;
}

// ─── AI Actions ─────────────────────────────────────────────

enum _AiAction {
  openAnalysis('打开 AI 助手', Icons.auto_awesome),
  lookup('查词', Icons.translate),
  grammar('语法分析', Icons.schema_outlined),
  translate('翻译', Icons.g_translate),
  phrase('片段解析', Icons.short_text),
  makeSentences('造句', Icons.edit_note),
  synonyms('近义词', Icons.swap_horiz),
  antonyms('反义词', Icons.compare_arrows),
  conjugate('变形表', Icons.table_chart_outlined),
  rewrite('改写', Icons.autorenew),
  pronunciation('口语教练', Icons.record_voice_over);

  const _AiAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Tappable word chip that shows a context menu of AI actions.
class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.sentenceContext,
    required this.onAiAction,
  });
  final String word;
  final String sentenceContext;
  final void Function(_AiAction action, String text, String ctx) onAiAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showMenu(context),
        onLongPress: () => _showMenu(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            word,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final cleanWord = word.replaceAll(RegExp(r'[.,;:!?"""()–—]'), '').trim();
    if (cleanWord.isEmpty) return;

    final actions = [
      _AiAction.lookup,
      _AiAction.makeSentences,
      _AiAction.synonyms,
      _AiAction.antonyms,
      _AiAction.conjugate,
      _AiAction.phrase,
      _AiAction.grammar,
      _AiAction.translate,
      _AiAction.openAnalysis,
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.touch_app,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      cleanWord,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ...actions.map((a) => ListTile(
                    leading: Icon(a.icon, size: 20),
                    title: Text(a.label),
                    dense: true,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      final input =
                          a == _AiAction.grammar || a == _AiAction.translate || a == _AiAction.rewrite || a == _AiAction.pronunciation
                              ? sentenceContext
                              : cleanWord;
                      onAiAction(a, input, sentenceContext);
                    },
                  )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet that fetches & displays AI result inline.
class _AiResultSheet extends StatefulWidget {
  const _AiResultSheet({
    required this.action,
    required this.text,
    required this.sentenceContext,
    required this.provider,
  });
  final _AiAction action;
  final String text;
  final String sentenceContext;
  final AiProvider provider;

  @override
  State<_AiResultSheet> createState() => _AiResultSheetState();
}

class _AiResultSheetState extends State<_AiResultSheet> {
  String _result = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final service = AiService(provider: widget.provider);
    String result;

    switch (widget.action) {
      case _AiAction.lookup:
        result =
            await service.lookupWord(widget.text, widget.sentenceContext);
      case _AiAction.grammar:
        result = await service.analyzeGrammar(widget.text);
      case _AiAction.translate:
        result = await service.translate(widget.text);
      case _AiAction.phrase:
        result = await service.analyzePhrase(
            widget.text, widget.sentenceContext);
      case _AiAction.makeSentences:
        result = await service.makeSentences(
            widget.text, widget.sentenceContext);
      case _AiAction.synonyms:
        result =
            await service.synonyms(widget.text, widget.sentenceContext);
      case _AiAction.antonyms:
        result =
            await service.antonyms(widget.text, widget.sentenceContext);
      case _AiAction.conjugate:
        result =
            await service.conjugate(widget.text, widget.sentenceContext);
      case _AiAction.rewrite:
        result = await service.rewrite(widget.text);
      case _AiAction.pronunciation:
        result = await service.speakingCoach(widget.text);
      case _AiAction.openAnalysis:
        result = ''; // Won't reach here
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
                child: Row(
                  children: [
                    Icon(widget.action.icon,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.action.label}：${widget.text.length > 30 ? '${widget.text.substring(0, 30)}…' : widget.text}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_result.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: '复制',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _result));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制到剪贴板')),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Body
              Expanded(
                child: _loading
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('AI 正在分析…'),
                          ],
                        ),
                      )
                    : ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(20),
                        children: [
                          MarkdownBody(
                            data: _result,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet.fromTheme(
                              Theme.of(context),
                            ).copyWith(
                              p: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                              listBullet: theme.textTheme.bodyMedium?.copyWith(height: 1.7),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
