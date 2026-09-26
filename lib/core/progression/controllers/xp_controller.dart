import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/xp_models.dart';
import '../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../features/home/presentation/widgets/level_up_overlay.dart';
import '../../routing/app_router.dart';

class XpController extends GetxController {
  static XpController get to => Get.find<XpController>();

  final Rx<XpProgressModel> progress = const XpProgressModel().obs;
  final RxBool isLevelUpDialogActive = false.obs;
  int _lastCelebratedLevel = 1;

  @override
  void onInit() {
    super.onInit();
    // Reactively listen to AuthController currentUser changes
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      ever(authController.currentUser, (user) {
        if (user != null) {
          progress.value = XpProgressModel(
            level: user.level,
            total: user.totalXp,
            xpIntoCurrentLevel: user.xpIntoCurrentLevel,
            xpRequiredForNextLevel: user.xpRequiredForNextLevel,
            progress: user.progress,
          );
        }
      });

      final initialUser = authController.currentUser.value;
      if (initialUser != null) {
        progress.value = XpProgressModel(
          level: initialUser.level,
          total: initialUser.totalXp,
          xpIntoCurrentLevel: initialUser.xpIntoCurrentLevel,
          xpRequiredForNextLevel: initialUser.xpRequiredForNextLevel,
          progress: initialUser.progress,
        );
        _lastCelebratedLevel = initialUser.level;
      }
    }
  }

  /// Updates local XP state and triggers level-up celebration if occurred == true or level increased.
  void handleXpUpdate({
    required XpProgressModel xp,
    LevelUpModel? levelUp,
    BuildContext? context,
  }) {
    final previousLevel = progress.value.level;
    progress.value = xp;

    debugPrint('[XP] handleXpUpdate: earned=${xp.earned}, level=${xp.level}, previousLevel=$previousLevel, levelUpOccurred=${levelUp?.occurred}');

    // Synchronize with AuthController user model
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      final currentUser = auth.currentUser.value;
      if (currentUser != null) {
        auth.currentUser.value = currentUser.copyWith(
          level: xp.level,
          totalXp: xp.total,
          xpIntoCurrentLevel: xp.xpIntoCurrentLevel,
          xpRequiredForNextLevel: xp.xpRequiredForNextLevel,
          progress: xp.progress,
        );
      }
    }

    final didLevelUp = (levelUp != null && levelUp.occurred) ||
        (previousLevel > 0 && xp.level > previousLevel && xp.level > _lastCelebratedLevel);

    if (didLevelUp && !isLevelUpDialogActive.value) {
      _lastCelebratedLevel = xp.level;
      final effectiveLevelUp = (levelUp != null && levelUp.occurred)
          ? levelUp
          : LevelUpModel(
              occurred: true,
              fromLevel: previousLevel,
              toLevel: xp.level,
              levelsGained: math.max(1, xp.level - previousLevel),
            );

      final targetContext = context ?? AppRouter.navigatorKey.currentContext ?? Get.context;
      debugPrint('[XP] Target context for celebration: $targetContext');
      if (targetContext != null) {
        showLevelUpCelebration(targetContext, effectiveLevelUp);
      }
    }
  }

  /// Trigger celebration for current level (used for preview or missed triggers)
  void triggerCelebrationForCurrentLevel() {
    final currentLevel = progress.value.level;
    final targetContext = AppRouter.navigatorKey.currentContext;
    if (targetContext != null && currentLevel > 1) {
      showLevelUpCelebration(
        targetContext,
        LevelUpModel(
          occurred: true,
          fromLevel: currentLevel - 1,
          toLevel: currentLevel,
          levelsGained: 1,
        ),
      );
    }
  }

  /// Displays the single, polished level-up modal celebration.
  void showLevelUpCelebration(BuildContext context, LevelUpModel levelUp) {
    if (isLevelUpDialogActive.value) return;
    isLevelUpDialogActive.value = true;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => LevelUpOverlay(
        levelUp: levelUp,
        onContinue: () {
          Navigator.of(ctx, rootNavigator: true).pop();
        },
      ),
    ).then((_) {
      isLevelUpDialogActive.value = false;
    });
  }
}
