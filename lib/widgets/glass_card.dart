import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.borderColor,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: AppTheme.borderLg,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  colors: isDark
                      ? [
                          scheme.surfaceContainerLow.withValues(alpha: 0.8),
                          scheme.surfaceContainer.withValues(alpha: 0.5),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          scheme.surfaceContainerLow.withValues(alpha: 0.7),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            borderRadius: AppTheme.borderLg,
            border: Border.all(
              color: borderColor ??
                  scheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
            ),
            boxShadow: AppTheme.shadowSm(Theme.of(context).brightness),
          ),
          child: child,
        ),
      ),
    );
  }
}
