import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// Animated 3-dot bouncing indicator matching the Stitch splash screen design.
class AppLoadingIndicator extends StatefulWidget {
  final double dotSize;

  const AppLoadingIndicator({super.key, this.dotSize = 10.0});

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(Color color, double delay) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = (_controller.value + delay) % 1.0;
        final double bounce = (1 - (progress - 0.5).abs() * 2) * -6.0;

        return Transform.translate(
          offset: Offset(0, bounce),
          child: Container(
            width: widget.dotSize,
            height: widget.dotSize,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(AppColors.primaryCoral, 0.0),
        _buildDot(AppColors.softYellow, 0.2),
        _buildDot(AppColors.primaryNavy, 0.4),
      ],
    );
  }
}
