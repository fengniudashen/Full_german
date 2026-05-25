String formatDurationMs(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds < 0 ? 0 : milliseconds);
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final millis =
      duration.inMilliseconds.remainder(1000).toString().padLeft(3, '0');
  return '$minutes:$seconds.$millis';
}

String formatDurationCompact(Duration duration) {
  if (duration.inHours > 0) {
    return '${duration.inHours}h${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

String formatPercent(double value) {
  return '${(value * 100).toStringAsFixed(1)}%';
}
