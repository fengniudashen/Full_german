import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MiniActivityChart extends StatelessWidget {
  const MiniActivityChart({
    super.key,
    required this.data,
    this.height = 80,
    this.barWidth = 6,
    this.maxValue,
  });

  final List<double> data;
  final double height;
  final double barWidth;
  final double? maxValue;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(height: height);
    }

    final maxVal = maxValue ?? data.reduce(math.max);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((v) {
          final fraction = (v / safeMax).clamp(0.0, 1.0);
          final barHeight = math.max(3.0, fraction * (height - 8));
          return Tooltip(
            message: v.toStringAsFixed(0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    scheme.primary,
                    AppTheme.emerald,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
