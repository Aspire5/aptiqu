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
  final Rxn<LevelUpModel> pendingCelebration = Rxn<LevelUpModel>();
  bool presentationManaged = false;
  Worker? _authWorker;
  String? _owner;
  int _lastCelebratedLevel = 1;
  bool _hasProgressSnapshot = false;

  @override
  void onInit() {
    super.onInit();
    // Reactively listen to AuthController currentUser changes
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();
      _owner = authController.currentUser.value?.id;
      _authWorker = ever(authController.currentUser, (user) {
        if (user?.id != _owner) {
          _owner = user?.id;
          pendingCelebration.value = null;
          _hasProgressSnapshot = false;
          _lastCelebratedLevel = user?.level ?? 1;
        }
        if (user != null) {
          _hasProgressSnapshot = true;
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
        _hasProgressSnapshot = true;
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
    final before = levelUp?.beforeProgress ?? progress.value;
    final trustworthyBefore = _hasProgressSnapshot;
    final previousLevel = before.level;
    progress.value = xp;
    _hasProgressSnapshot = true;

    debugPrint(
      '[XP] handleXpUpdate: earned=${xp.earned}, level=${xp.level}, previousLevel=$previousLevel, levelUpOccurred=${levelUp?.occurred}',
    );

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

    final didLevelUp =
        (levelUp != null && levelUp.occurred) ||
        (previousLevel > 0 &&
            xp.level > previousLevel &&
            xp.level > _lastCelebratedLevel);

    if (didLevelUp && xp.level > _lastCelebratedLevel) {
      _lastCelebratedLevel = xp.level;
      final fromLevel = (levelUp != null && levelUp.occurred)
          ? levelUp.fromLevel
          : previousLevel;
      final effectiveLevelUp = LevelUpModel(
        occurred: true,
        fromLevel: fromLevel,
        toLevel: xp.level,
        levelsGained: math.max(1, xp.level - fromLevel),
        beforeProgress:
            trustworthyBefore &&
                before.level == fromLevel &&
                before.total <= xp.total &&
                before.xpRequiredForNextLevel > 0 &&
                before.progress.isFinite
            ? before
            : null,
        afterProgress: xp,
      );

      final targetContext =
          context ?? AppRouter.navigatorKey.currentContext ?? Get.context;
      debugPrint('[XP] Target context for celebration: $targetContext');
      if (presentationManaged) {
        queueCelebration(effectiveLevelUp);
      } else if (targetContext != null) {
        showLevelUpCelebration(targetContext, effectiveLevelUp);
      }
    } else if (pendingCelebration.value != null &&
        xp.level == pendingCelebration.value!.toLevel) {
      final pending = pendingCelebration.value!;
      pendingCelebration.value = LevelUpModel(
        occurred: true,
        fromLevel: pending.fromLevel,
        toLevel: pending.toLevel,
        levelsGained: pending.levelsGained,
        beforeProgress: pending.beforeProgress,
        afterProgress: xp,
      );
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
    if (presentationManaged) {
      queueCelebration(levelUp);
      return;
    }
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

  /// Presentation can wait for a safe boundary; progression is already applied.
  void queueCelebration(LevelUpModel award) {
    final pending = pendingCelebration.value;
    final from = pending == null
        ? award.fromLevel
        : math.min(pending.fromLevel, award.fromLevel);
    final to = pending == null
        ? award.toLevel
        : math.max(pending.toLevel, award.toLevel);
    pendingCelebration.value = LevelUpModel(
      occurred: true,
      fromLevel: from,
      toLevel: to,
      levelsGained: to - from,
      beforeProgress: pending == null
          ? award.beforeProgress
          : pending.beforeProgress,
      afterProgress: award.afterProgress ?? pending?.afterProgress,
    );
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }
}
