import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLowest,
        borderRadius: AppTheme.borderMd,
        border: Border.all(color: borderColor ?? scheme.outlineVariant),
        boxShadow: AppTheme.shadowSm(Theme.of(context).brightness),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
