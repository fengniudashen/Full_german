import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../models/word_comparison.dart';
import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/text_comparator.dart';
import '../services/whisper_service.dart';
import '../theme/app_theme.dart';
import '../widgets/accuracy_ring.dart';
import '../widgets/glass_card.dart';

class SpeakingPage extends StatefulWidget {
  const SpeakingPage({
    super.key,
    required this.projectId,
    required this.sentences,
    this.audioPath,
  });

  final int projectId;
  final List<String> sentences;
  final String? audioPath;

  @override
  State<SpeakingPage> createState() => _SpeakingPageState();
}

class _SpeakingPageState extends State<SpeakingPage> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;

  int _index = 0;
  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isFetchingFeedback = false;
  Duration _recordDuration = Duration.zero;
  String? _recordedPath;
  String? _transcription;
  ComparisonResult? _comparison;
  String? _feedback;
  String? _error;

  String get _currentSentence => widget.sentences[_index];

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ─── Recording ──────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = '没有麦克风权限，请在系统设置中允许。');
        return;
      }

      final useLocal = context.read<AppState>().settings.useLocalWhisper;
      final dir = await getTemporaryDirectory();
      final ext = useLocal ? 'wav' : 'm4a';
      final filePath = p.join(
          dir.path, 'speaking_${DateTime.now().millisecondsSinceEpoch}.$ext');

      await _recorder.start(
        RecordConfig(
          encoder: useLocal ? AudioEncoder.wav : AudioEncoder.aacLc,
          sampleRate: useLocal ? 16000 : 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
        _recordedPath = null;
        _transcription = null;
        _comparison = null;
        _feedback = null;
        _error = null;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      setState(() => _error = '录音启动失败: $e');
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
      if (path != null) {
        _transcribe(path);
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _error = '录音停止失败: $e';
      });
    }
  }

  // ─── Transcription ─────────────────────────────────────────

  Future<void> _transcribe(String filePath) async {
    setState(() {
      _isTranscribing = true;
      _error = null;
    });

    try {
      final settings = context.read<AppState>().settings;
      String text;

      if (settings.useLocalWhisper) {
        // Local whisper.cpp transcription
        final model = WhisperModel.values.firstWhere(
          (m) => m.label == settings.whisperModel,
          orElse: () => WhisperModel.base,
        );
        final whisper = WhisperService();
        text = await whisper.transcribe(filePath, model: model);
      } else {
        // API-based transcription
        final provider = settings.activeProvider;
        final service = AiService(provider: provider);
        text = await service.transcribeAudio(filePath);
      }

      if (!mounted) return;
      final result = TextComparator.compare(_currentSentence, text);
      setState(() {
        _transcription = text;
        _comparison = result;
        _isTranscribing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranscribing = false;
        _error = '转写失败: $e';
      });
    } finally {
      // Clean up temp file
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
  }

  // ─── AI Feedback ────────────────────────────────────────────

  Future<void> _fetchFeedback() async {
    if (_transcription == null) return;

    setState(() {
      _isFetchingFeedback = true;
      _error = null;
    });

    try {
      final provider = context.read<AppState>().settings.activeProvider;
      final service = AiService(provider: provider);
      final result = await service.speakingCoach(_currentSentence);

      if (!mounted) return;
      setState(() {
        _feedback = result;
        _isFetchingFeedback = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFetchingFeedback = false;
        _error = '获取反馈失败: $e';
      });
    }
  }

  // ─── Navigation ─────────────────────────────────────────────

  void _goTo(int index) {
    if (index < 0 || index >= widget.sentences.length) return;
    setState(() {
      _index = index;
      _recordedPath = null;
      _transcription = null;
      _comparison = null;
      _feedback = null;
      _error = null;
      _recordDuration = Duration.zero;
    });
  }

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('口语练习'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '${_index + 1}/${widget.sentences.length}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Progress bar ──
                LinearProgressIndicator(
                  value: (_index + 1) / widget.sentences.length,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 20),

                // ── Target sentence card ──
                GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 28, color: theme.colorScheme.primary),
                      const SizedBox(height: 12),
                      Text(
                        _currentSentence,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Microphone button + timer ──
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isTranscribing
                            ? null
                            : (_isRecording
                                ? _stopRecording
                                : _startRecording),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording
                                ? AppTheme.accent
                                : theme.colorScheme.surfaceContainerHighest,
                            boxShadow: _isRecording
                                ? [
                                    BoxShadow(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic,
                            size: 40,
                            color: _isRecording
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _isRecording
                            ? _formatDuration(_recordDuration)
                            : (_isTranscribing ? '转写中...' : '点击录音'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isRecording
                              ? AppTheme.accent
                              : theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Transcribing indicator ──
                if (_isTranscribing)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                // ── Error ──
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GlassCard(
                      borderColor: isDark
                          ? AppTheme.wrongBorderDark
                          : AppTheme.wrongBorder,
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(_error!,
                                style: theme.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Transcription result + comparison ──
                if (_transcription != null && _comparison != null) ...[
                  // Accuracy header
                  GlassCard(
                    child: Row(
                      children: [
                        AccuracyRing(value: _comparison!.accuracy, size: 56),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('识别结果',
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  _statChip(
                                    '正确 ${_comparison!.correctCount}',
                                    isDark
                                        ? AppTheme.correctFgDark
                                        : AppTheme.correctFg,
                                    isDark
                                        ? AppTheme.correctBgDark
                                        : AppTheme.correctBg,
                                  ),
                                  _statChip(
                                    '轻微 ${_comparison!.minorCount}',
                                    isDark
                                        ? AppTheme.minorFgDark
                                        : AppTheme.minorFg,
                                    isDark
                                        ? AppTheme.minorBgDark
                                        : AppTheme.minorBg,
                                  ),
                                  _statChip(
                                    '错误 ${_comparison!.wrongCount}',
                                    isDark
                                        ? AppTheme.wrongFgDark
                                        : AppTheme.wrongFg,
                                    isDark
                                        ? AppTheme.wrongBgDark
                                        : AppTheme.wrongBg,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Word-by-word comparison
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('逐词对比',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 8,
                          children: _comparison!.items
                              .map((w) => _wordChip(w, isDark))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Your transcription
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('你说的：',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(_transcription!,
                            style: theme.textTheme.bodyLarge
                                ?.copyWith(height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // AI feedback button
                  if (_feedback == null)
                    FilledButton.icon(
                      onPressed:
                          _isFetchingFeedback ? null : _fetchFeedback,
                      icon: _isFetchingFeedback
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.psychology),
                      label: Text(_isFetchingFeedback
                          ? '分析中...'
                          : 'AI 发音指导'),
                    ),

                  // AI feedback result
                  if (_feedback != null) ...[
                    const SizedBox(height: 12),
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology,
                                  size: 20,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('AI 发音指导',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          MarkdownBody(
                            data: _feedback!,
                            selectable: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // ── Navigation buttons ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _index > 0 ? () => _goTo(_index - 1) : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('上一句'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _index < widget.sentences.length - 1
                          ? () => _goTo(_index + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('下一句'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────

  Widget _wordChip(WordComparison w, bool isDark) {
    final Color bg, fg, border;
    switch (w.status) {
      case ComparisonStatus.correct:
        bg = isDark ? AppTheme.correctBgDark : AppTheme.correctBg;
        fg = isDark ? AppTheme.correctFgDark : AppTheme.correctFg;
        border = isDark ? AppTheme.correctBorderDark : AppTheme.correctBorder;
      case ComparisonStatus.minor:
        bg = isDark ? AppTheme.minorBgDark : AppTheme.minorBg;
        fg = isDark ? AppTheme.minorFgDark : AppTheme.minorFg;
        border = isDark ? AppTheme.minorBorderDark : AppTheme.minorBorder;
      case ComparisonStatus.wrong:
        bg = isDark ? AppTheme.wrongBgDark : AppTheme.wrongBg;
        fg = isDark ? AppTheme.wrongFgDark : AppTheme.wrongFg;
        border = isDark ? AppTheme.wrongBorderDark : AppTheme.wrongBorder;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Text(
        w.displayText,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _statChip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
