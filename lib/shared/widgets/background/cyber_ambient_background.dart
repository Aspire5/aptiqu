import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_colors.dart';

/// Lightweight, 60fps Cyber Ambient Animated Background.
/// Emulates the Stitch CSS ambient drift with soft radial glowing blobs
/// and a delicate cyber grid overlay.
class CyberAmbientBackground extends StatefulWidget {
  final Widget child;

  const CyberAmbientBackground({
    super.key,
    required this.child,
  });

  @override
  State<CyberAmbientBackground> createState() => _CyberAmbientBackgroundState();
}

class _CyberAmbientBackgroundState extends State<CyberAmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final driftX = math.sin(progress * math.pi) * 30;
        final driftY = math.cos(progress * math.pi) * 25;

        return CustomPaint(
          painter: _CyberGridPainter(
            driftX: driftX,
            driftY: driftY,
            progress: progress,
          ),
          child: widget.child,
        );
      },
      child: widget.child,
    );
  }
}

class _CyberGridPainter extends CustomPainter {
  final double driftX;
  final double driftY;
  final double progress;

  _CyberGridPainter({
    required this.driftX,
    required this.driftY,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base dark fill
    final basePaint = Paint()..color = AptiquColors.surfaceDim;
    canvas.drawRect(Offset.zero & size, basePaint);

    // 2. Top-Left Violet Aurora Blob
    final violetCenter = Offset(
      size.width * 0.15 + driftX,
      size.height * 0.20 + driftY,
    );
    final violetRadius = size.width * 0.65;
    final violetPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AptiquColors.primaryContainer.withValues(alpha: 0.12 + 0.04 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: violetCenter, radius: violetRadius));

    canvas.drawCircle(violetCenter, violetRadius, violetPaint);

    // 3. Bottom-Right Cyan Aurora Blob
    final cyanCenter = Offset(
      size.width * 0.85 - driftX,
      size.height * 0.80 - driftY,
    );
    final cyanRadius = size.width * 0.70;
    final cyanPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AptiquColors.secondary.withValues(alpha: 0.10 + 0.03 * (1 - progress)),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: cyanCenter, radius: cyanRadius));

    canvas.drawCircle(cyanCenter, cyanRadius, cyanPaint);

    // 4. Subtle Cyber Grid
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;

    const step = 36.0;
    final offsetX = (driftX * 0.4) % step;
    final offsetY = (driftY * 0.4) % step;

    for (double x = offsetX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = offsetY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberGridPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
