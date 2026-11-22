import 'dart:async';
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

class QuickMatchMatrix extends StatefulWidget {
  final bool isSearching;

  const QuickMatchMatrix({super.key, required this.isSearching});

  @override
  State<QuickMatchMatrix> createState() => _QuickMatchMatrixState();
}

class _QuickMatchMatrixState extends State<QuickMatchMatrix> {
  Timer? _animTimer;
  final Set<int> _markedCells = {}; // 0..24
  final List<StrikeLine> _strikeLines = [];
  int _stepIndex = 0;

  // The 4 Stitch idle preview cell highlights
  static const Map<int, HighlightConfig> _idleHighlights = {
    6: HighlightConfig(bg: Color(0xFFFFE8E5), border: Color(0xFFFFD4CF), text: Color(0xFFFF6B5E)),
    12: HighlightConfig(bg: Color(0xFFEEF0FF), border: Color(0xFFC2C5E2), text: Color(0xFF20243A)),
    16: HighlightConfig(bg: Color(0xFFFFF4D6), border: Color(0xFFFFE59E), text: Color(0xFFB8860B)),
    21: HighlightConfig(bg: Color(0xFFF1F3F5), border: Color(0xFFDDE1E6), text: Color(0xFF20243A)),
  };

  // Deterministic animation sequence from Stitch approved code
  static const List<MatrixStep> _sequence = [
    // Step 1: Row 1 (Numbers 1 -> 2 -> 3 -> 4 -> 5)
    MatrixStep.mark(0, 350),
    MatrixStep.mark(1, 350),
    MatrixStep.mark(2, 350),
    MatrixStep.mark(3, 350),
    MatrixStep.mark(4, 200),
    MatrixStep.strike(StrikeType.row, 0, 700),

    // Step 2: Col 5 (Numbers 10 -> 15 -> 20 -> 25)
    MatrixStep.mark(9, 350),
    MatrixStep.mark(14, 350),
    MatrixStep.mark(19, 350),
    MatrixStep.mark(24, 200),
    MatrixStep.strike(StrikeType.col, 4, 700),

    // Step 3: Row 5 (Numbers 21 -> 22 -> 23 -> 24)
    MatrixStep.mark(20, 350),
    MatrixStep.mark(21, 350),
    MatrixStep.mark(22, 350),
    MatrixStep.mark(23, 200),
    MatrixStep.strike(StrikeType.row, 4, 700),

    // Step 4: Col 1 (Numbers 6 -> 11 -> 16)
    MatrixStep.mark(5, 350),
    MatrixStep.mark(10, 350),
    MatrixStep.mark(15, 200),
    MatrixStep.strike(StrikeType.col, 0, 700),

    // Step 5: Main Diagonal (Numbers 7 -> 13 -> 19)
    MatrixStep.mark(6, 350),
    MatrixStep.mark(12, 350),
    MatrixStep.mark(18, 200),
    MatrixStep.strike(StrikeType.diag, 0, 1000),

    // Reset and pause
    MatrixStep.reset(400),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isSearching) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant QuickMatchMatrix oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSearching != oldWidget.isSearching) {
      if (widget.isSearching) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  @override
  void dispose() {
    _animTimer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    _animTimer?.cancel();
    setState(() {
      _markedCells.clear();
      _strikeLines.clear();
      _stepIndex = 0;
    });
    _executeNextStep();
  }

  void _stopAnimation() {
    _animTimer?.cancel();
    setState(() {
      _markedCells.clear();
      _strikeLines.clear();
      _stepIndex = 0;
    });
  }

  void _executeNextStep() {
    if (!mounted || !widget.isSearching) return;

    if (_stepIndex >= _sequence.length) {
      _stepIndex = 0;
    }

    final step = _sequence[_stepIndex];
    _stepIndex++;

    if (step.action == StepAction.mark && step.cellIndex != null) {
      setState(() {
        _markedCells.add(step.cellIndex!);
      });
    } else if (step.action == StepAction.strike && step.strikeType != null) {
      setState(() {
        _strikeLines.add(StrikeLine(step.strikeType!, step.lineIndex ?? 0));
      });
    } else if (step.action == StepAction.reset) {
      setState(() {
        _markedCells.clear();
        _strikeLines.clear();
      });
    }

    _animTimer = Timer(Duration(milliseconds: step.delayMs), _executeNextStep);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 156,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F1).withAlpha(230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '5×5 MATRIX',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Color(0xFF46464D),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 138,
            height: 138,
            child: Stack(
              children: [
                // 5x5 Grid
                GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 25,
                  itemBuilder: (context, index) {
                    final number = index + 1;
                    final isMarked = widget.isSearching && _markedCells.contains(index);
                    final idleHighlight = !widget.isSearching ? _idleHighlights[index] : null;

                    Color bgColor = Colors.white;
                    Color borderColor = const Color(0xFFE5E7EB);
                    Color textColor = const Color(0xFF20243A);
                    FontWeight weight = FontWeight.w700;

                    if (isMarked) {
                      bgColor = AppColors.primaryCoral;
                      borderColor = AppColors.primaryCoral;
                      textColor = Colors.white;
                      weight = FontWeight.w900;
                    } else if (idleHighlight != null) {
                      bgColor = idleHighlight.bg;
                      borderColor = idleHighlight.border;
                      textColor = idleHighlight.text;
                      weight = FontWeight.w800;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: borderColor),
                        boxShadow: isMarked
                            ? const [
                                BoxShadow(
                                  color: Color(0x33FF6B5E),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$number',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 10,
                          fontWeight: weight,
                          color: textColor,
                          height: 1.0,
                        ),
                      ),
                    );
                  },
                ),

                // Strikethrough Vector Overlay
                if (widget.isSearching && _strikeLines.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: MatrixStrikePainter(_strikeLines),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum StepAction { mark, strike, reset }
enum StrikeType { row, col, diag }

class HighlightConfig {
  final Color bg;
  final Color border;
  final Color text;

  const HighlightConfig({
    required this.bg,
    required this.border,
    required this.text,
  });
}

class MatrixStep {
  final StepAction action;
  final int? cellIndex;
  final StrikeType? strikeType;
  final int? lineIndex;
  final int delayMs;

  const MatrixStep.mark(this.cellIndex, this.delayMs)
      : action = StepAction.mark,
        strikeType = null,
        lineIndex = null;

  const MatrixStep.strike(this.strikeType, this.lineIndex, this.delayMs)
      : action = StepAction.strike,
        cellIndex = null;

  const MatrixStep.reset(this.delayMs)
      : action = StepAction.reset,
        cellIndex = null,
        strikeType = null,
        lineIndex = null;
}

class StrikeLine {
  final StrikeType type;
  final int index;

  const StrikeLine(this.type, this.index);
}

class MatrixStrikePainter extends CustomPainter {
  final List<StrikeLine> lines;

  MatrixStrikePainter(this.lines);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B5E)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Centers for 5 cells in 138 width/height
    // 5 cells with size 24.4, gap 4:
    // cell 0: 12.2, cell 1: 40.6, cell 2: 69.0, cell 3: 97.4, cell 4: 125.8
    final centers = [12.2, 40.6, 69.0, 97.4, 125.8];

    for (final line in lines) {
      if (line.type == StrikeType.row) {
        final y = centers[line.index.clamp(0, 4)];
        canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), paint);
      } else if (line.type == StrikeType.col) {
        final x = centers[line.index.clamp(0, 4)];
        canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), paint);
      } else if (line.type == StrikeType.diag) {
        canvas.drawLine(const Offset(6, 6), Offset(size.width - 6, size.height - 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant MatrixStrikePainter oldDelegate) {
    return oldDelegate.lines.length != lines.length;
  }
}
