import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../features/social/widgets/social_widgets.dart';

/// Finite, dismissible in-place result accent. It never covers result controls.
class VictoryCelebration extends StatefulWidget {
  const VictoryCelebration({super.key, required this.person});
  final Map<String, dynamic> person;
  @override
  State<VictoryCelebration> createState() => _VictoryCelebrationState();
}

class _VictoryCelebrationState extends State<VictoryCelebration>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_animation.isDismissed) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Semantics(
      label: 'Match victory',
      child: AnimatedBuilder(
        animation: _animation,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LearnerAvatar(person: widget.person, radius: 30),
            const SizedBox(height: 8),
            Icon(
              Icons.emoji_events_outlined,
              size: 28,
              color: context.colors.primary,
            ),
          ],
        ),
        builder: (context, child) {
          final t = _animation.value;
          final pulse = math.sin((t.clamp(0, .32) / .32) * math.pi) * .07;
          return SizedBox(
            height: 138,
            child: CustomPaint(
              painter: _VictoryRays(
                t,
                context.colors.primary,
                context.colors.secondary,
              ),
              child: Center(
                child: Transform.scale(scale: 1 + pulse, child: child),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _VictoryRays extends CustomPainter {
  const _VictoryRays(this.progress, this.primary, this.secondary);
  final double progress;
  final Color primary, secondary;
  @override
  void paint(Canvas canvas, Size size) {
    final t = Curves.easeOutCubic.transform((progress / .7).clamp(0.0, 1.0));
    final opacity = (1 - progress).clamp(0.0, 1.0);
    if (opacity == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final spread = math.min(size.width * .4, 118.0);
    for (var i = 0; i < 16; i++) {
      final angle = i * math.pi / 8;
      final r = 38 + spread * t * (.5 + (i % 3) * .12);
      final point =
          center + Offset(math.cos(angle) * r, math.sin(angle) * r * .48);
      final paint = Paint()
        ..color = (i.isEven ? primary : secondary).withValues(
          alpha: opacity * .65,
        )
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        point,
        point + Offset(math.cos(angle) * 5, math.sin(angle) * 5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_VictoryRays old) =>
      old.progress != progress ||
      old.primary != primary ||
      old.secondary != secondary;
}
