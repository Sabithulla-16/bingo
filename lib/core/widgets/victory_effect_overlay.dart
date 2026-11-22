import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight animated celebration overlay for match victories.
/// Supports Classic Celebration and equipped Golden Burst cosmetic.
class VictoryEffectOverlay extends StatefulWidget {
  final bool isGoldenBurst;
  final Widget child;

  const VictoryEffectOverlay({
    super.key,
    required this.isGoldenBurst,
    required this.child,
  });

  @override
  State<VictoryEffectOverlay> createState() => _VictoryEffectOverlayState();
}

class _VictoryEffectOverlayState extends State<VictoryEffectOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _pulseAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: math.pi / 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutSine));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (widget.isGoldenBurst)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Opacity(
                  opacity: (1.0 - _controller.value * 0.3).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: CustomPaint(
                      painter: _GoldenBurstPainter(
                        progress: _pulseAnimation.value,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _GoldenBurstPainter extends CustomPainter {
  final double progress;

  _GoldenBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.28);
    final maxRadius = size.width * 0.45 * progress;

    final rayPaint = Paint()
      ..color = const Color(
        0xFFFFD700,
      ).withAlpha((180 * (1.0 - progress * 0.4)).toInt())
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final goldStarPaint = Paint()
      ..color = const Color(
        0xFFFFA500,
      ).withAlpha((200 * (1.0 - progress * 0.3)).toInt())
      ..style = PaintingStyle.fill;

    // Draw 16 radial golden burst rays
    const rayCount = 16;
    for (int i = 0; i < rayCount; i++) {
      final angle = (i * 2 * math.pi) / rayCount;
      final start = Offset(
        center.dx + math.cos(angle) * (maxRadius * 0.2),
        center.dy + math.sin(angle) * (maxRadius * 0.2),
      );
      final end = Offset(
        center.dx + math.cos(angle) * maxRadius,
        center.dy + math.sin(angle) * maxRadius,
      );
      canvas.drawLine(start, end, rayPaint);

      // Draw sparkles at ray endpoints
      if (progress > 0.4) {
        canvas.drawCircle(end, 4.0 * progress, goldStarPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_GoldenBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
