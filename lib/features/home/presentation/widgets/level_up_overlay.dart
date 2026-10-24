import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/feedback/app_feedback_service.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../core/progression/models/xp_models.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../social/widgets/social_widgets.dart';

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
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _continued = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
      final award = widget.levelUp;
      AppFeedbackService.maybe?.levelUp(
        '${award.fromLevel}:${award.toLevel}:${award.afterProgress?.total ?? 'unknown'}',
      );
    });
  }

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
    AppFeedbackService.maybe?.dismissLevelUp();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) {
      final user = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value
          : null;
      final award = widget.levelUp;
      final before = award.beforeProgress;
      final after = award.afterProgress;
      final validBefore =
          before != null &&
          before.level == award.fromLevel &&
          before.xpRequiredForNextLevel > 0 &&
          before.progress.isFinite;
      final avatar = LearnerAvatar(
        person: {
          'name': user?.firstName ?? 'Learner',
          'avatarUrl': user?.avatarUrl,
        },
        radius: 38,
      );
      return Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'LEVEL UP!',
                        textAlign: TextAlign.center,
                        style: context.type.labelLarge?.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      AnimatedBuilder(
                        animation: _animation,
                        child: avatar,
                        builder: (context, avatar) {
                          final t = _animation.value;
                          final reveal = !validBefore || t >= .6;
                          final fill = !validBefore
                              ? (after?.progress ?? user?.progress ?? 0) *
                                    Curves.easeOutCubic.transform(t)
                              : !reveal
                              ? before.progress +
                                    (1 - before.progress) *
                                        Curves.easeInOutCubic.transform(
                                          ((t - .1) / .4).clamp(0.0, 1.0),
                                        )
                              : (after?.progress ?? user?.progress ?? 0) *
                                    Curves.easeOutCubic.transform(
                                      ((t - .64) / .34).clamp(0.0, 1.0),
                                    );
                          final pulse =
                              math.sin(
                                ((t - .45) / .25).clamp(0.0, 1.0) * math.pi,
                              ) *
                              .075;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Transform.scale(
                                  scale: 1 + pulse,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: context.colors.primary
                                            .withValues(alpha: .55),
                                        width: 2,
                                      ),
                                      gradient: RadialGradient(
                                        colors: [
                                          context.colors.primaryContainer,
                                          context.colors.surfaceContainerHigh,
                                        ],
                                      ),
                                    ),
                                    child: avatar,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Semantics(
                                header: true,
                                liveRegion: reveal,
                                child: Text(
                                  'LEVEL ${reveal ? award.toLevel : award.fromLevel}',
                                  textAlign: TextAlign.center,
                                  style: context.type.headlineSmall,
                                ),
                              ),
                              if (award.levelsGained > 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  '+${award.levelsGained} levels',
                                  textAlign: TextAlign.center,
                                  style: context.type.titleSmall?.copyWith(
                                    color: context.colors.primary,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AptiquRadius.chip,
                                ),
                                child: LinearProgressIndicator(
                                  key: ValueKey(
                                    reveal
                                        ? 'new-level-xp'
                                        : 'previous-level-xp',
                                  ),
                                  value: fill.clamp(0.0, 1.0),
                                  minHeight: 9,
                                  semanticsLabel: reveal
                                      ? 'New level XP progress'
                                      : 'Previous level completed',
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                reveal
                                    ? after == null
                                          ? 'Keep building your skills.'
                                          : '${after.xpIntoCurrentLevel} / ${after.xpRequiredForNextLevel} XP'
                                    : 'Completing level ${award.fromLevel}',
                                textAlign: TextAlign.center,
                                style: context.type.bodyMedium?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: AptiquButton(
                  label: 'Continue',
                  onPressed: _continued
                      ? null
                      : () {
                          setState(() => _continued = true);
                          widget.onContinue();
                        },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
