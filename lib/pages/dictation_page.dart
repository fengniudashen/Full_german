import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../services/text_comparator.dart';
import '../utils/time_format.dart';
import '../widgets/comparison_result_sheet.dart';
import '../widgets/responsive_page.dart';
import '../widgets/surface_panel.dart';

class DictationPage extends StatefulWidget {
  const DictationPage({super.key, required this.projectId});

  final int projectId;

  @override
  State<DictationPage> createState() => _DictationPageState();
}

class _DictationPageState extends State<DictationPage> {
  static const List<String> _quickChars = ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü'];

  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _answerFocusNode = FocusNode();
  StreamSubscription<Duration>? _positionSubscription;

  StudyProject? _project;
  List<StudySentence> _sentences = const [];
  Map<int, String> _answers = {};
  int _index = 0;
  Duration? _stopAt;
  bool _loading = true;
  bool _checking = false;
  String? _error;

    StudySentence? get _currentSentence =>
      _sentences.isEmpty ? null : _sentences[_clampIndex(_index)];

  @override
  void initState() {
    super.initState();
    _positionSubscription = _player.positionStream.listen(_handlePosition);
    _load();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _player.dispose();
    _answerController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_project?.name ?? '听写练习')),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final sentence = _currentSentence;
    if (sentence == null) {
      return const Center(child: Text('没有可练习的句子'));
    }

    return ResponsivePage(
      maxWidth: 980,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressCard(context, sentence),
          const SizedBox(height: 16),
          _buildAnswerCard(context),
          const SizedBox(height: 16),
          _buildNavigation(context),
        ],
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, StudySentence sentence) {
    final theme = Theme.of(context);
    return SurfacePanel(
      padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '第 ${_index + 1} / ${_sentences.length} 句',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${formatDurationMs(sentence.startMs)} - ${formatDurationMs(sentence.endMs)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: (_index + 1) / _sentences.length),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sentence.hasValidRange ? _playCurrentSentence : null,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('播放当前句'),
            ),
          ],
      ),
    );
  }

  Widget _buildAnswerCard(BuildContext context) {
    return SurfacePanel(
      padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickChars
                  .map(
                    (char) => SizedBox(
                      width: 46,
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _insertQuickChar(char),
                        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(char),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _answerController,
              focusNode: _answerFocusNode,
              minLines: 6,
              maxLines: 10,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _checkAnswer(),
              decoration: const InputDecoration(
                labelText: '听写输入',
                alignLabelWithHint: true,
                hintText: '输入你听到的德语句子',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _checking ? null : _checkAnswer,
              icon: _checking
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fact_check_outlined),
              label: const Text('核对'),
            ),
          ],
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
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
            onPressed: _index >= _sentences.length - 1 ? null : () => _goTo(_index + 1),
            icon: const Icon(Icons.chevron_right),
            label: const Text('下一句'),
          ),
        ),
      ],
    );
  }

  Future<void> _load() async {
    try {
      final database = context.read<AppState>().database;
      final project = await database.getProject(widget.projectId);
      if (project == null) {
        setState(() {
          _loading = false;
          _error = '项目不存在或已被删除。';
        });
        return;
      }

      final sentences = await database.getSentencesForProject(widget.projectId);
      final answers = await database.getLatestDictations(widget.projectId);
      await _player.setFilePath(project.audioPath);

      if (!mounted) {
        return;
      }
      setState(() {
        _project = project;
        _sentences = sentences;
        _answers = answers;
        _loading = false;
      });
      _syncAnswerController();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = '加载失败：$error';
      });
    }
  }

  Future<void> _reloadSentences() async {
    final sentences = await context
        .read<AppState>()
        .database
        .getSentencesForProject(widget.projectId);
    if (!mounted) {
      return;
    }
    setState(() => _sentences = sentences);
  }

  void _handlePosition(Duration position) {
    final stopAt = _stopAt;
    if (stopAt == null) {
      return;
    }
    if (position >= stopAt) {
      _stopAt = null;
      _player.pause();
      _player.seek(stopAt);
    }
  }

  Future<void> _playCurrentSentence() async {
    final sentence = _currentSentence;
    if (sentence == null || !sentence.hasValidRange) {
      return;
    }
    _cacheCurrentAnswer();
    final start = Duration(milliseconds: sentence.startMs);
    final end = Duration(milliseconds: sentence.endMs);
    _stopAt = end;
    await _player.pause();
    await _player.seek(start);
    await _player.play();
  }

  Future<void> _checkAnswer() async {
    final sentence = _currentSentence;
    if (sentence == null) {
      return;
    }

    _cacheCurrentAnswer();
    setState(() => _checking = true);
    try {
      final appState = context.read<AppState>();
      final database = appState.database;
      final answer = _answerController.text.trim();
      final result = TextComparator.compare(sentence.text, answer);
      await database.saveDictation(
        projectId: widget.projectId,
        sentenceId: sentence.id,
        userInput: answer,
      );
      await database.insertWrongWords(
        projectId: widget.projectId,
        sentenceId: sentence.id,
        sentenceText: sentence.text,
        errors: result.redErrors,
      );
      await appState.loadWrongWords();

      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => ComparisonResultSheet(
          sentence: sentence,
          result: result,
          onSaveNote: (note) async {
            await database.updateSentenceNote(sentence.id, note);
            await _reloadSentences();
          },
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  void _insertQuickChar(String char) {
    final text = _answerController.text;
    final selection = _answerController.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final next = text.replaceRange(start, end, char);
    _answerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + char.length),
    );
    _answerFocusNode.requestFocus();
  }

  void _goTo(int nextIndex) {
    _cacheCurrentAnswer();
    setState(() => _index = _clampIndex(nextIndex));
    _syncAnswerController();
  }

  void _cacheCurrentAnswer() {
    final sentence = _currentSentence;
    if (sentence == null) {
      return;
    }
    _answers = Map<int, String>.from(_answers)
      ..[sentence.id] = _answerController.text;
  }

  void _syncAnswerController() {
    final sentence = _currentSentence;
    final text = sentence == null ? '' : _answers[sentence.id] ?? '';
    _answerController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int _clampIndex(int value) {
    if (_sentences.isEmpty) {
      return 0;
    }
    return value.clamp(0, _sentences.length - 1).toInt();
  }
}
