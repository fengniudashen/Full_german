import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  final String label;
  final Color? color;
  final IconData? icon;

  factory StatusBadge.fromStatus(String status) {
    return switch (status) {
      '可听写' => StatusBadge(
          label: status,
          color: AppTheme.emerald,
          icon: Icons.headphones,
        ),
      '已完成' => StatusBadge(
          label: status,
          color: AppTheme.sky,
          icon: Icons.check_circle_outline,
        ),
      '进行中' => StatusBadge(
          label: status,
          color: AppTheme.gold,
          icon: Icons.edit_note,
        ),
      _ => StatusBadge(
          label: status,
          color: AppTheme.accent,
          icon: Icons.schedule,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: AppTheme.borderSm,
        border: Border.all(color: c.withValues(alpha: isDark ? 0.4 : 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
