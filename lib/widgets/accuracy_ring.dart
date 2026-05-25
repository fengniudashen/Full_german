import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AccuracyRing extends StatelessWidget {
  const AccuracyRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 5,
    this.label,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = value >= 0.8
        ? AppTheme.emerald
        : value >= 0.5
            ? AppTheme.gold
            : AppTheme.accent;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            label ?? '${(value * 100).toInt()}%',
            style: TextStyle(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
