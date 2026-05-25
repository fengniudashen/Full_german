import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.large = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(minHeight: large ? 72 : 54),
      padding: EdgeInsets.symmetric(
        horizontal: large ? 16 : 12,
        vertical: large ? 12 : 9,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: isDark ? 0.15 : 0.08),
            accent.withValues(alpha: isDark ? 0.08 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.borderMd,
        border: Border.all(color: accent.withValues(alpha: isDark ? 0.3 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 40 : 32,
            height: large ? 40 : 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: AppTheme.borderSm,
            ),
            child: Icon(icon, color: accent, size: large ? 20 : 16),
          ),
          SizedBox(width: large ? 12 : 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: large ? 20 : 15,
                  fontWeight: FontWeight.w900,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: large ? 12 : 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
