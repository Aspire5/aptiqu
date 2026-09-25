import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';

/// Reusable Cyber Glowing Loading / Progress Indicator
class AptiquLoadingIndicator extends StatefulWidget {
  final double size;
  final String? message;

  const AptiquLoadingIndicator({
    super.key,
    this.size = 48.0,
    this.message,
  });

  @override
  State<AptiquLoadingIndicator> createState() => _AptiquLoadingIndicatorState();
}

class _AptiquLoadingIndicatorState extends State<AptiquLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _CyberLoaderPainter(
                progress: _controller.value,
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.message!.toUpperCase(),
            style: AptiquTypography.labelCapsBold.copyWith(
              color: AptiquColors.secondary,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}

class _CyberLoaderPainter extends CustomPainter {
  final double progress;

  _CyberLoaderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background track ring
    final trackPaint = Paint()
      ..color = AptiquColors.outlineVariant.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, trackPaint);

    // Orbiting Primary Violet Arc
    final violetPaint = Paint()
      ..color = AptiquColors.primaryContainer
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    final startAngleViolet = progress * 2 * math.pi;
    const sweepAngleViolet = 1.2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngleViolet,
      sweepAngleViolet,
      false,
      violetPaint,
    );

    // Counter-orbiting Cyan Arc
    final cyanPaint = Paint()
      ..color = AptiquColors.secondary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    final startAngleCyan = -progress * 2 * math.pi;
    const sweepAngleCyan = 0.8 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.72),
      startAngleCyan,
      sweepAngleCyan,
      false,
      cyanPaint,
    );

    // Center pulsing cyber core
    final pulseScale = 0.8 + 0.3 * math.sin(progress * 2 * math.pi);
    final corePaint = Paint()
      ..color = AptiquColors.secondary.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5 * pulseScale, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CyberLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
