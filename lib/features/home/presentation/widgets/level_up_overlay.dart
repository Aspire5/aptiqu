import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../../../core/progression/models/xp_models.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';

/// Gamified, minimal, and premium Level-Up Celebration Dialog
class LevelUpOverlay extends StatefulWidget {
  final LevelUpModel levelUp;
  final VoidCallback onContinue;

  const LevelUpOverlay({
    super.key,
    required this.levelUp,
    required this.onContinue,
  });

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pipeProgressAnimation;

  late int _displayedLevel;
  int _targetLevel = 1;
  int _startLevel = 1;

  @override
  void initState() {
    super.initState();
    _startLevel = widget.levelUp.fromLevel;
    _targetLevel = widget.levelUp.toLevel;
    _displayedLevel = _startLevel;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Phase 1-2: Avatar / Card entry lift & scale (0.0 -> 0.35)
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
    );

    // Phase 4: Ring pipe fill (0.35 -> 0.85)
    _pipeProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeInOutCubic),
      ),
    );

    // Phase 5: Level increment trigger when pipe finishes
    _controller.addListener(() {
      if (_controller.value >= 0.85 && _displayedLevel != _targetLevel) {
        setState(() {
          _displayedLevel = _targetLevel;
        });
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String avatarUrl =
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=250&q=80';

    if (Get.isRegistered<AuthController>()) {
      final user = Get.find<AuthController>().currentUser.value;
      if (user != null && user.avatarUrl.isNotEmpty) {
        avatarUrl = user.avatarUrl;
      }
    }

    return Center(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 320,
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceDim,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AptiquColors.primaryContainer.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.7),
                      blurRadius: 36,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: AptiquColors.primaryContainer.withValues(alpha: 0.25),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar surrounded by circular progress pipe
                    SizedBox(
                      width: 104,
                      height: 104,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Clockwise filling circular pipe
                          CustomPaint(
                            size: const Size(104, 104),
                            painter: _LevelPipePainter(
                              progress: _pipeProgressAnimation.value,
                              isCompleted: _controller.value >= 0.85,
                            ),
                          ),
                          // User Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AptiquColors.surfaceDim,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AptiquColors.secondary.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AptiquColors.surfaceContainerHigh,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: AptiquColors.primary,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // "LEVEL UP!" Banner
                    Text(
                      'LEVEL UP!',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        fontSize: 13,
                        color: AptiquColors.secondary,
                        letterSpacing: 2.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Level Number with subtle scale animation upon transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) => ScaleTransition(
                        scale: animation,
                        child: child,
                      ),
                      child: Text(
                        'LEVEL $_displayedLevel',
                        key: ValueKey<int>(_displayedLevel),
                        style: AptiquTypography.displayHero.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AptiquColors.onSurface,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Exactly ONE visible action: Continue
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AptiquColors.primary,
                          foregroundColor: AptiquColors.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: widget.onContinue,
                        child: Text(
                          'Continue',
                          style: AptiquTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Custom painter for the clockwise circular progress tube / pipe
class _LevelPipePainter extends CustomPainter {
  final double progress;
  final bool isCompleted;

  _LevelPipePainter({
    required this.progress,
    required this.isCompleted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;

    // Track Background Pipe
    final trackPaint = Paint()
      ..color = AptiquColors.outlineVariant.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      // Filling Gradient Pipe (starts at top -pi/2, sweeps clockwise)
      final sweepAngle = 2 * math.pi * progress;
      final fillPaint = Paint()
        ..color = isCompleted ? AptiquColors.secondary : AptiquColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelPipePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.isCompleted != isCompleted;
  }
}
