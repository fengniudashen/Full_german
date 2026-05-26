import 'dart:async';

import 'package:flutter/material.dart';

import '../widgets/glass_card.dart';

/// Pomodoro focus timer — 25 min work + 5 min break cycles,
/// with motivational German quotes.
class PomodoroPage extends StatefulWidget {
  const PomodoroPage({super.key});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  static const _workMinutes = 25;
  static const _breakMinutes = 5;

  int _secondsRemaining = _workMinutes * 60;
  bool _isRunning = false;
  bool _isBreak = false;
  int _completedPomodoros = 0;
  Timer? _timer;

  static const _quotes = [
    '"Übung macht den Meister." — 熟能生巧',
    '"Der Anfang ist die Hälfte des Ganzen." — 万事开头难',
    '"Wer rastet, der rostet." — 不进则退',
    '"Ohne Fleiß kein Preis." — 不劳无获',
    '"Aller Anfang ist schwer." — 凡事开头难',
    '"Es ist noch kein Meister vom Himmel gefallen." — 没有天生的大师',
    '"Steter Tropfen höhlt den Stein." — 滴水穿石',
    '"Morgenstund hat Gold im Mund." — 一日之计在于晨',
  ];

  String get _currentQuote => _quotes[_completedPomodoros % _quotes.length];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _isRunning = false;
          if (!_isBreak) {
            _completedPomodoros++;
            _isBreak = true;
            _secondsRemaining = _breakMinutes * 60;
          } else {
            _isBreak = false;
            _secondsRemaining = _workMinutes * 60;
          }
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isBreak = false;
      _secondsRemaining = _workMinutes * 60;
    });
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totalSeconds = _isBreak ? _breakMinutes * 60 : _workMinutes * 60;
    final progress = 1.0 - (_secondsRemaining / totalSeconds);
    final timerColor = _isBreak ? Colors.green : scheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('番茄钟')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Status label
                Text(
                  _isBreak ? '☕ 休息时间' : '🎯 专注学习',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 40),

                // Timer ring
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 10,
                          backgroundColor: timerColor.withValues(alpha: 0.15),
                          valueColor: AlwaysStoppedAnimation(timerColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(_secondsRemaining),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontFeatures: [const FontFeature.tabularFigures()],
                            ),
                          ),
                          if (_secondsRemaining == 0)
                            Text(
                              _isBreak ? '休息结束!' : '专注完成!',
                              style: TextStyle(color: timerColor, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: _reset,
                      icon: const Icon(Icons.stop),
                      tooltip: '重置',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 20),
                    FloatingActionButton.large(
                      onPressed: _isRunning ? _pause : _start,
                      backgroundColor: timerColor,
                      child: Icon(
                        _isRunning ? Icons.pause : Icons.play_arrow,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton.filled(
                      onPressed: () {
                        _timer?.cancel();
                        setState(() {
                          _isRunning = false;
                          if (_isBreak) {
                            _isBreak = false;
                            _secondsRemaining = _workMinutes * 60;
                          } else {
                            _completedPomodoros++;
                            _isBreak = true;
                            _secondsRemaining = _breakMinutes * 60;
                          }
                        });
                      },
                      icon: const Icon(Icons.skip_next),
                      tooltip: '跳过',
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surfaceContainerHighest,
                        foregroundColor: scheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Completed pomodoros
                GlassCard(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ...List.generate(
                        _completedPomodoros.clamp(0, 8),
                        (_) => const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Text('🍅', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      if (_completedPomodoros == 0)
                        Text('完成第一个番茄钟吧！',
                            style: theme.textTheme.bodySmall),
                      if (_completedPomodoros > 0)
                        Text(' × $_completedPomodoros',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // German quote
                Text(
                  _currentQuote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
