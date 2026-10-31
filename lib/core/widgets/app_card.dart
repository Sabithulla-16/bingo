import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radii.dart';

/// Flat paper-style card container with 1.5px structural border.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? AppRadii.roundedXl;

    return Material(
      color: backgroundColor ?? AppColors.surface,
      borderRadius: effectiveBorderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: effectiveBorderRadius,
            border:
                border ??
                Border.all(color: AppColors.structuralBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}
