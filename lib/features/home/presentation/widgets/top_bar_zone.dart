import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/progression/controllers/xp_controller.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';

class TopBarZone extends StatelessWidget {
  final double height;
  const TopBarZone({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final xp = Get.isRegistered<XpController>()
        ? Get.find<XpController>()
        : null;
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    return Obx(() {
      final user = auth.currentUser.value;
      final progress = xp?.progress.value;
      final name = user?.firstName.isNotEmpty == true
          ? user!.firstName
          : 'Learner';
      final level = progress != null && progress.level > 0
          ? progress.level
          : user?.level ?? 1;
      final levelProgress = progress != null && progress.progress > 0
          ? progress.progress
          : user != null && user.progress > 0
          ? user.progress
          : user != null &&
                user.xpRequiredForNextLevel > 0 &&
                user.xpIntoCurrentLevel > 0
          ? user.xpIntoCurrentLevel / user.xpRequiredForNextLevel
          : 0.0;
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '$name, Level $level. Open profile',
                  onTap: () => context.push(AppRoutes.profile),
                  button: true,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(AppRoutes.profile),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CircularProgressIndicator(
                                  value: levelProgress.clamp(0, 1),
                                  strokeWidth: 2,
                                  color: colors.primary,
                                  backgroundColor: colors.surfaceContainerHigh,
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: CircleAvatar(
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.onPrimaryContainer,
                                    foregroundImage:
                                        user?.avatarUrl.isNotEmpty == true
                                        ? NetworkImage(user!.avatarUrl)
                                        : null,
                                    onForegroundImageError:
                                        user?.avatarUrl.isNotEmpty == true
                                        ? (_, __) {}
                                        : null,
                                    child: Text(
                                      name.substring(0, 1).toUpperCase(),
                                      style: type.labelMedium,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.titleSmall,
                                ),
                                Text(
                                  'Level $level',
                                  style: type.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.dailyStreak),
                icon: Icon(
                  Icons.local_fire_department_outlined,
                  color: colors.tertiary,
                  size: 20,
                ),
                label: Text(user?.streak ?? '0d'),
              ),
              Semantics(
                label: '${user?.coins ?? 0} coins',
                child: Row(
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                    Text('${user?.coins ?? 0}', style: type.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
