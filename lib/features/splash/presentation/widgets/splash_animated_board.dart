import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_typography.dart';

/// Pixel-faithful Stitch Splash Screen 5×5 Animated Bingo Board
/// (Stitch Screen ID: `97875f5450c745e9afb99ca9389aa94d`)
///
/// Features:
/// - Exact 2D matrix matching Stitch design tokens
/// - Daubed Coral cells on diagonal (01, 07, 19, 25)
/// - Center Golden Star free space [2, 2]
/// - Accent Yellow cells (09, 21)
/// - Animated SVG diagonal strike-through vector with sparkle nodes
class SplashAnimatedBingoBoard extends StatefulWidget {
  final double size;

  const SplashAnimatedBingoBoard({super.key, this.size = 256.0});

  @override
  State<SplashAnimatedBingoBoard> createState() =>
      _SplashAnimatedBingoBoardState();
}

class _SplashAnimatedBingoBoardState extends State<SplashAnimatedBingoBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _strokeAnimation;
  late final Animation<double> _sparkleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _strokeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _sparkleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.roundedXl,
        border: Border.all(color: AppColors.structuralBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1420243A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 5x5 Grid Cells Matrix
          _buildCellsMatrix(),

          // Animated Winning Diagonal Strikethrough Vector Overlay
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _DiagonalStrikePainter(
                  progress: _strokeAnimation.value,
                  sparkleScale: _sparkleAnimation.value,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCellsMatrix() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: 25,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 5.0,
        mainAxisSpacing: 5.0,
      ),
      itemBuilder: (context, index) {
        final row = index ~/ 5;
        final col = index % 5;
        final number = index + 1;

        // Winning Diagonal indices: [0,0]=0, [1,1]=6, [2,2]=12, [3,3]=18, [4,4]=24
        final isDiagonal = row == col;
        final isCenter = row == 2 && col == 2;
        final isYellowAccent = number == 9 || number == 21;

        Color bgColor;
        Color textColor;
        Widget content;

        if (isCenter) {
          bgColor = AppColors.softYellow;
          textColor = AppColors.primaryNavy;
          content = const Icon(
            Icons.star_rounded,
            color: AppColors.primaryNavy,
            size: 20,
          );
        } else if (isDiagonal) {
          bgColor = AppColors.primaryCoral;
          textColor = AppColors.textLight;
          content = Text(
            number.toString().padLeft(2, '0'),
            style: AppTypography.labelSm.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          );
        } else if (isYellowAccent) {
          bgColor = AppColors.softYellow.withAlpha(180);
          textColor = AppColors.primaryNavy;
          content = Text(
            number.toString().padLeft(2, '0'),
            style: AppTypography.labelSm.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          );
        } else {
          bgColor = AppColors.surfaceContainerLow;
          textColor = AppColors.primaryNavy;
          content = Text(
            number.toString().padLeft(2, '0'),
            style: AppTypography.labelSm.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadii.roundedMd,
            boxShadow: isDiagonal
                ? [
                    BoxShadow(
                      color: AppColors.primaryCoral.withAlpha(60),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        );
      },
    );
  }
}

class _DiagonalStrikePainter extends CustomPainter {
  final double progress;
  final double sparkleScale;

  _DiagonalStrikePainter({required this.progress, required this.sparkleScale});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    // Line anchors based on 5x5 geometry matching Stitch 256x256 frame
    final start = Offset(size.width * 0.11, size.height * 0.11);
    final end = Offset(size.width * 0.89, size.height * 0.89);
    final currentEnd = Offset.lerp(start, end, progress)!;

    // 1. Draw glowing background shadow line
    final shadowPaint = Paint()
      ..color = AppColors.primaryCoral.withAlpha(50)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, currentEnd, shadowPaint);

    // 2. Draw sharp primary coral strike vector
    final strokePaint = Paint()
      ..color = AppColors.primaryCoral
      ..strokeWidth = 4.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(start, currentEnd, strokePaint);

    // 3. Draw Sparkle Nodes along the diagonal
    final nodes = [
      (0.00, AppColors.primaryCoral, 3.8),
      (0.25, AppColors.primaryCoral, 3.2),
      (0.50, AppColors.softYellow, 4.8),
      (0.75, AppColors.primaryCoral, 3.2),
      (1.00, AppColors.primaryCoral, 3.8),
    ];

    for (final node in nodes) {
      final t = node.$1;
      final color = node.$2;
      final baseRadius = node.$3;

      if (progress >= t) {
        final nodePos = Offset.lerp(start, end, t)!;
        final scale = math.min(1.0, (progress - t) / 0.25) * sparkleScale;
        final radius = baseRadius * scale;

        if (radius > 0.1) {
          // Sparkle halo
          final haloPaint = Paint()
            ..color = color.withAlpha((70 * scale).toInt())
            ..style = PaintingStyle.fill;
          canvas.drawCircle(nodePos, radius + 2.5, haloPaint);

          // Sparkle core
          final nodePaint = Paint()
            ..color = color
            ..style = PaintingStyle.fill;
          canvas.drawCircle(nodePos, radius, nodePaint);

          // White center specular reflection
          final centerWhite = Paint()
            ..color = Colors.white.withAlpha((180 * scale).toInt())
            ..style = PaintingStyle.fill;
          canvas.drawCircle(nodePos, radius * 0.45, centerWhite);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DiagonalStrikePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.sparkleScale != sparkleScale;
  }
}
