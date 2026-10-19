import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../core/progression/models/xp_models.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../../shared/widgets/layout/text_fit.dart';
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
  late final AnimationController _animation;
  bool _continued = false;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_animation.status == AnimationStatus.dismissed) {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) {
      final user = Get.isRegistered<AuthController>()
          ? Get.find<AuthController>().currentUser.value
          : null;
      return AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Dialog(
          insetPadding: const EdgeInsets.all(24),
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
                        LayoutBuilder(
                          builder: (context, box) {
                            final level =
                                'LEVEL ${_animation.isCompleted ? widget.levelUp.toLevel : widget.levelUp.fromLevel}';
                            final beside =
                                textFits(
                                  context,
                                  level,
                                  context.type.headlineSmall!,
                                  box.maxWidth - 80,
                                ) &&
                                textFits(
                                  context,
                                  'LEVEL UP!',
                                  context.type.labelLarge!,
                                  box.maxWidth - 80,
                                );
                            final heading = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    'LEVEL UP!',
                                    style: context.type.labelLarge?.copyWith(
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    level,
                                    style: context.type.headlineSmall,
                                  ),
                                ),
                              ],
                            );
                            return beside
                                ? Row(
                                    children: [
                                      LearnerAvatar(
                                        person: {
                                          'name': user?.firstName ?? 'Learner',
                                          'avatarUrl': user?.avatarUrl,
                                        },
                                        radius: 32,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(child: heading),
                                    ],
                                  )
                                : heading;
                          },
                        ),
                        if (MediaQuery.sizeOf(context).height >= 400) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Keep building your skills.',
                            style: context.type.bodyLarge,
                          ),
                        ],
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
        ),
      );
    },
  );
}
