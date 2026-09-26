import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/xp_models.dart';
import '../../../features/auth/presentation/controllers/auth_controller.dart';
import '../../../features/home/presentation/widgets/level_up_overlay.dart';

class XpController extends GetxController {
  static XpController get to => Get.find<XpController>();

  final Rx<XpProgressModel> progress = const XpProgressModel().obs;
  final RxBool isLevelUpDialogActive = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize from AuthController if current user exists
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      final user = authController.currentUser.value;
      if (user != null) {
        progress.value = XpProgressModel(
          level: user.level,
          total: user.totalXp,
        );
      }
    }
  }

  /// Updates local XP state and triggers level-up celebration if occurred == true.
  void handleXpUpdate({
    required XpProgressModel xp,
    LevelUpModel? levelUp,
    BuildContext? context,
  }) {
    progress.value = xp;

    // Synchronize with AuthController user model
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      final currentUser = auth.currentUser.value;
      if (currentUser != null) {
        auth.currentUser.value = currentUser.copyWith(
          level: xp.level,
          totalXp: xp.total,
        );
      }
    }

    if (levelUp != null && levelUp.occurred && !isLevelUpDialogActive.value) {
      final targetContext = context ?? Get.context;
      if (targetContext != null) {
        showLevelUpCelebration(targetContext, levelUp);
      }
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
