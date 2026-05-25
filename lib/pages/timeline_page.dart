import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/time_format.dart';
import '../widgets/glass_card.dart';
import 'dictation_page.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.projectId});
  final int projectId;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  StudyProject? _project;
  List<StudySentence> _sentences = const [];
  List<double> _samples = const [];
  int _selectedIndex = 0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _stateSub = _player.playerStateStream.listen((s) {
      if (mounted) setState(() => _isPlaying = s.playing);
    });
    _load();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _allComplete =>
      _sentences.isNotEmpty && _sentences.every((s) => s.endMs > 0);

  StudySentence? get _sel =>
      _sentences.isEmpty ? null : _sentences[_clamp(_selectedIndex)];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_project?.name ?? '时间轴标注'),
        actions: [
          if (_allComplete)
            FilledButton.icon(
              onPressed: _finishAnnotation,
              icon: const Icon(Icons.task_alt, size: 18),
              label: const Text('完成标注'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emerald,
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _WaveformCard(
                  samples: _samples,
                  position: _position,
                  duration: _duration,
                ),
                const SizedBox(height: 12),
                _buildControls(),
                const SizedBox(height: 12),
                Expanded(child: _buildSentenceList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final sel = _sel;
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Transport controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: () => _seekBy(const Duration(seconds: -5)),
                icon: const Icon(Icons.replay_5),
                tooltip: '快退 5 秒',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _seekBy(const Duration(seconds: -2)),
                icon: const Icon(Icons.fast_rewind),
                tooltip: '快退 2 秒',
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _togglePlay,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  iconSize: 32,
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: () => _seekBy(const Duration(seconds: 2)),
                icon: const Icon(Icons.fast_forward),
                tooltip: '快进 2 秒',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _seekBy(const Duration(seconds: 5)),
                icon: const Icon(Icons.forward_5),
                tooltip: '快进 5 秒',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: _duration == Duration.zero
                  ? 0
                  : (_position.inMilliseconds / _duration.inMilliseconds)
                      .clamp(0.0, 1.0),
              onChanged: (v) {
                final ms = (v * _duration.inMilliseconds).round();
                _player.seek(Duration(milliseconds: ms));
              },
            ),
          ),

          // Time display
          Text(
            '${formatDurationMs(_position.inMilliseconds)} / ${formatDurationMs(_duration.inMilliseconds)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),

          // A/B markers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: sel == null ? null : _markStart,
                icon: const Icon(Icons.flag, size: 16),
                label: const Text('标记 A 起始'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                ),
              ),
              FilledButton.icon(
                onPressed: sel == null ? null : _markEnd,
                icon: const Icon(Icons.outlined_flag, size: 16),
                label: const Text('标记 B 结束'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceList() {
    final theme = Theme.of(context);
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sentences.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        itemBuilder: (context, i) {
          final s = _sentences[i];
          final selected = i == _selectedIndex;
          return ListTile(
            selected: selected,
            selectedTileColor:
                theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            leading: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.hasEndTime
                    ? AppTheme.emerald.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: s.hasEndTime
                      ? AppTheme.emerald
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            title: Text(s.text, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              'A ${formatDurationMs(s.startMs)}   B ${formatDurationMs(s.endMs)}',
              style: TextStyle(
                fontFeatures: [const FontFeature.tabularFigures()],
                fontSize: 12,
              ),
            ),
            trailing: s.hasEndTime
                ? const Icon(Icons.check_circle, color: AppTheme.emerald, size: 20)
                : Icon(Icons.radio_button_unchecked,
                    size: 20, color: theme.colorScheme.outlineVariant),
            onTap: () async {
              setState(() => _selectedIndex = i);
              await _player.seek(Duration(milliseconds: s.startMs));
            },
          );
        },
      ),
    );
  }

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
      Duration? dur;
      try {
        dur = await _player.setFilePath(project.audioPath);
      } catch (e) {
        setState(() {
          _loading = false;
          _error = '音频加载失败：$e';
        });
        return;
      }
      setState(() {
        _project = project;
        _sentences = sentences;
        _duration = dur ?? Duration.zero;
        _samples = _buildSamples(720);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '加载失败：$e';
      });
    }
  }

  Future<void> _reloadSentences({int? selectedIndex}) async {
    final sentences = await context
        .read<AppState>()
        .database
        .getSentencesForProject(widget.projectId);
    if (!mounted) return;
    setState(() {
      _sentences = sentences;
      if (selectedIndex != null && sentences.isNotEmpty) {
        _selectedIndex = _clamp(selectedIndex);
      }
    });
  }

  Future<void> _togglePlay() async {
    _isPlaying ? await _player.pause() : await _player.play();
  }

  Future<void> _seekBy(Duration offset) async {
    var target = _position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    await _player.seek(target);
  }

  Future<void> _markStart() async {
    final s = _sel;
    if (s == null) return;
    await context
        .read<AppState>()
        .database
        .updateSentenceTimes(s.id, startMs: _position.inMilliseconds);
    await _reloadSentences(selectedIndex: _selectedIndex);
  }

  Future<void> _markEnd() async {
    final s = _sel;
    if (s == null) return;
    final endMs = _position.inMilliseconds;
    if (endMs <= s.startMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束点必须晚于起始点')),
      );
      return;
    }
    final db = context.read<AppState>().database;
    await db.updateSentenceTimes(s.id, endMs: endMs);

    final next = _selectedIndex + 1;
    if (next < _sentences.length) {
      final ns = _sentences[next];
      if (ns.startMs == 0) {
        await db.updateSentenceTimes(ns.id, startMs: endMs);
      }
      await _reloadSentences(selectedIndex: next);
      await _player.seek(Duration(milliseconds: endMs));
    } else {
      await _reloadSentences(selectedIndex: _selectedIndex);
    }
  }

  Future<void> _finishAnnotation() async {
    await context.read<AppState>().markTimelineCompleted(widget.projectId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DictationPage(projectId: widget.projectId),
      ),
    );
  }

  int _clamp(int v) {
    if (_sentences.isEmpty) return 0;
    return v.clamp(0, _sentences.length - 1).toInt();
  }

  List<double> _buildSamples(int count) {
    return List<double>.generate(count, (i) {
      final a = (math.sin(i * 0.19) + 1) / 2;
      final b = (math.sin(i * 0.047 + 1.2) + 1) / 2;
      return (0.12 + a * 0.58 + b * 0.25).clamp(0.06, 1.0).toDouble();
    }, growable: false);
  }
}

class _WaveformCard extends StatelessWidget {
  const _WaveformCard({
    required this.samples,
    required this.position,
    required this.duration,
  });
  final List<double> samples;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safeDur =
        duration == Duration.zero ? const Duration(seconds: 1) : duration;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return RectangleWaveform(
            samples: samples,
            height: 100,
            width: constraints.maxWidth,
            maxDuration: safeDur,
            elapsedDuration: position > safeDur ? safeDur : position,
            activeColor: scheme.primary,
            inactiveColor: scheme.outlineVariant,
            showActiveWaveform: true,
          );
        },
      ),
    );
  }
}
