import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_audio_waveforms/flutter_audio_waveforms.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../models/study_project.dart';
import '../models/study_sentence.dart';
import '../providers/app_state.dart';
import '../utils/time_format.dart';
import '../widgets/surface_panel.dart';
import 'dictation_page.dart';

class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.projectId});

  final int projectId;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

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
    _positionSubscription = _player.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state.playing);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool get _allComplete =>
      _sentences.isNotEmpty && _sentences.every((sentence) => sentence.endMs > 0);

    StudySentence? get _selectedSentence =>
      _sentences.isEmpty ? null : _sentences[_clampIndex(_selectedIndex)];

  @override
  Widget build(BuildContext context) {
    final project = _project;

    return Scaffold(
      appBar: AppBar(
        title: Text(project?.name ?? '时间轴标注'),
        actions: [
          if (_allComplete)
            TextButton.icon(
              onPressed: _finishAnnotation,
              icon: const Icon(Icons.task_alt),
              label: const Text('完成标注'),
            ),
        ],
      ),
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
                _buildControls(context),
                const SizedBox(height: 12),
                Expanded(child: _buildSentenceList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final selected = _selectedSentence;
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton.filledTonal(
                  onPressed: () => _seekBy(const Duration(seconds: -2)),
                  icon: const Icon(Icons.replay_5),
                  tooltip: '快退 2 秒',
                ),
                IconButton.filled(
                  onPressed: _togglePlay,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: _isPlaying ? '暂停' : '播放',
                ),
                IconButton.filledTonal(
                  onPressed: () => _seekBy(const Duration(seconds: 2)),
                  icon: const Icon(Icons.forward_5),
                  tooltip: '快进 2 秒',
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: selected == null ? null : _markStart,
                  icon: const Icon(Icons.flag_outlined),
                  label: const Text('标记起始点 A'),
                ),
                FilledButton.tonalIcon(
                  onPressed: selected == null ? null : _markEnd,
                  icon: const Icon(Icons.outlined_flag),
                  label: const Text('标记结束点 B'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${formatDurationMs(_position.inMilliseconds)} / ${formatDurationMs(_duration.inMilliseconds)}',
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildSentenceList() {
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _sentences.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final sentence = _sentences[index];
          final selected = index == _selectedIndex;
          return ListTile(
            selected: selected,
            selectedTileColor: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.35),
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(sentence.text),
            subtitle: Text(
              'A ${formatDurationMs(sentence.startMs)}   B ${formatDurationMs(sentence.endMs)}',
            ),
            trailing: sentence.hasEndTime
                ? const Icon(Icons.check_circle, color: Colors.green)
                : const Icon(Icons.radio_button_unchecked),
            onTap: () async {
              setState(() => _selectedIndex = index);
              await _player.seek(Duration(milliseconds: sentence.startMs));
            },
          );
        },
      ),
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
      Duration? duration;
      try {
        duration = await _player.setFilePath(project.audioPath);
      } catch (error) {
        setState(() {
          _loading = false;
          _error = '音频加载失败：$error';
        });
        return;
      }

      setState(() {
        _project = project;
        _sentences = sentences;
        _duration = duration ?? Duration.zero;
        _samples = _buildSamples(720);
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _error = '加载失败：$error';
      });
    }
  }

  Future<void> _reloadSentences({int? selectedIndex}) async {
    final sentences = await context
        .read<AppState>()
        .database
        .getSentencesForProject(widget.projectId);
    if (!mounted) {
      return;
    }
    setState(() {
      _sentences = sentences;
      if (selectedIndex != null && sentences.isNotEmpty) {
        _selectedIndex = _clampIndex(selectedIndex);
      }
    });
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final target = _position + offset;
    final clamped = _clampDuration(target, Duration.zero, _duration);
    await _player.seek(clamped);
  }

  Future<void> _markStart() async {
    final sentence = _selectedSentence;
    if (sentence == null) {
      return;
    }
    await context.read<AppState>().database.updateSentenceTimes(
          sentence.id,
          startMs: _position.inMilliseconds,
        );
    await _reloadSentences(selectedIndex: _selectedIndex);
  }

  Future<void> _markEnd() async {
    final sentence = _selectedSentence;
    if (sentence == null) {
      return;
    }
    final endMs = _position.inMilliseconds;
    if (endMs <= sentence.startMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('结束点必须晚于起始点')),
      );
      return;
    }

    final database = context.read<AppState>().database;
    await database.updateSentenceTimes(sentence.id, endMs: endMs);

    final nextIndex = _selectedIndex + 1;
    if (nextIndex < _sentences.length) {
      final nextSentence = _sentences[nextIndex];
      if (nextSentence.startMs == 0) {
        await database.updateSentenceTimes(nextSentence.id, startMs: endMs);
      }
      await _reloadSentences(selectedIndex: nextIndex);
      await _player.seek(Duration(milliseconds: endMs));
    } else {
      await _reloadSentences(selectedIndex: _selectedIndex);
    }
  }

  Future<void> _finishAnnotation() async {
    await context.read<AppState>().markTimelineCompleted(widget.projectId);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => DictationPage(projectId: widget.projectId)),
    );
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) {
      return min;
    }
    if (max > Duration.zero && value > max) {
      return max;
    }
    return value;
  }

  int _clampIndex(int value) {
    if (_sentences.isEmpty) {
      return 0;
    }
    return value.clamp(0, _sentences.length - 1).toInt();
  }

  List<double> _buildSamples(int count) {
    return List<double>.generate(count, (index) {
      final primary = (math.sin(index * 0.19) + 1) / 2;
      final secondary = (math.sin(index * 0.047 + 1.2) + 1) / 2;
      final value = 0.12 + (primary * 0.58) + (secondary * 0.25);
      return value.clamp(0.06, 1).toDouble();
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
    final colorScheme = Theme.of(context).colorScheme;
    final safeDuration = duration == Duration.zero ? const Duration(seconds: 1) : duration;
    return SurfacePanel(
      padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return RectangleWaveform(
              samples: samples,
              height: 128,
              width: constraints.maxWidth,
              maxDuration: safeDuration,
              elapsedDuration: position > safeDuration ? safeDuration : position,
              activeColor: colorScheme.primary,
              inactiveColor: colorScheme.outlineVariant,
              showActiveWaveform: true,
            );
          },
      ),
    );
  }
}
