import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../services/text_comparator.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/comparison_result_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/responsive_page.dart';

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
  String? _error;
  int _sessionId = 0;
  int _sessionCorrect = 0;
  int _sessionWrong = 0;
  DateTime? _sessionStart;

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
        title: Text(_project?.name ?? '听写练习'),
        actions: [
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
          if (showHints) ...[_buildHintCard(s), const SizedBox(height: 16)],
          _buildAnswerCard(),
          const SizedBox(height: 16),
          _buildNavigation(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProgressCard(StudySentence s) {
    final theme = Theme.of(context);
    final progress = _sentences.isEmpty ? 0.0 : (_index + 1) / _sentences.length;

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
          FilledButton.icon(
            onPressed: s.hasValidRange ? _playCurrentSentence : null,
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('播放当前句'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
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

  Widget _buildHintCard(StudySentence s) {
    final theme = Theme.of(context);
    final words = s.text.split(RegExp(r'\s+'));
    final hintText = words
        .map((w) => w.length <= 2
            ? w
            : '${w[0]}${'·' * (w.length - 2)}${w[w.length - 1]}')
        .join(' ');

    return GlassCard(
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
        ],
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
      await _player.setFilePath(project.audioPath);

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
    final stop = _stopAt;
    if (stop == null) return;
    if (pos >= stop) {
      _stopAt = null;
      _player.pause();
      _player.seek(stop);
    }
  }

  Future<void> _playCurrentSentence() async {
    final s = _current;
    if (s == null || !s.hasValidRange) return;
    _cacheAnswer();
    _stopAt = Duration(milliseconds: s.endMs);
    await _player.pause();
    await _player.seek(Duration(milliseconds: s.startMs));
    await _player.play();
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
    setState(() => _index = _clamp(next));
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
