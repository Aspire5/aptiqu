import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../controllers/daily_challenge_controller.dart';
import '../../models/daily_challenge_models.dart';

class DailyChallengeQuizScreen extends StatelessWidget {
  const DailyChallengeQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DailyChallengeController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmationDialog(context, controller);
      },
      child: Scaffold(
        backgroundColor: AptiquColors.surfaceDim,
        appBar: AppBar(
          backgroundColor: AptiquColors.surfaceDim,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AptiquColors.onSurface),
            onPressed: () => _showExitConfirmationDialog(context, controller),
          ),
          title: Obx(() {
            final session = controller.activeSession.value;
            if (session == null) return const Text('Daily Challenge');
            final current = controller.currentQuestionIndex.value + 1;
            final total = session.totalQuestions;
            return Text(
              'Question $current of $total',
              style: AptiquTypography.titleMedium.copyWith(
                color: AptiquColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            );
          }),
          actions: [
            // 60-Second Radial Countdown Timer
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Obx(() {
                final seconds = controller.secondsRemaining.value;
                final progress = seconds / 60.0;

                Color timerColor = AptiquColors.primary;
                if (seconds <= 15) {
                  timerColor = AptiquColors.error;
                } else if (seconds <= 30) {
                  timerColor = AptiquColors.tertiary;
                }

                return Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                            backgroundColor: AptiquColors.surfaceContainerHigh,
                            valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                          ),
                        ),
                        Text(
                          '$seconds',
                          style: AptiquTypography.labelCaps.copyWith(
                            color: timerColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
        body: Obx(() {
          final session = controller.activeSession.value;
          if (session == null || session.questions.isEmpty) {
            return const Center(child: Text('No active questions.'));
          }

          final question = session.questions[controller.currentQuestionIndex.value];
          final isSubmitting = controller.isSubmitting.value;

          return Column(
            children: [
              // Linear Progress Indicator
              LinearProgressIndicator(
                value: (controller.currentQuestionIndex.value + 1) / session.totalQuestions,
                backgroundColor: AptiquColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(AptiquColors.tertiary),
                minHeight: 3,
              ),

              // Scrollable Question & Options Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getDifficultyColor(question.difficulty).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getDifficultyColor(question.difficulty).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              question.difficulty,
                              style: AptiquTypography.labelCaps.copyWith(
                                color: _getDifficultyColor(question.difficulty),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AptiquColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.flash_on_rounded, color: AptiquColors.tertiary, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  'SPEED TRICK (<60s)',
                                  style: AptiquTypography.labelCaps.copyWith(
                                    color: AptiquColors.onSurfaceVariant,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Question Prompt Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AptiquColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AptiquColors.outlineVariant),
                        ),
                        child: Text(
                          question.prompt,
                          style: AptiquTypography.bodyLarge.copyWith(
                            color: AptiquColors.onSurface,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Options List
                      ...question.options.map((opt) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildOptionTile(controller, opt.id, opt.text),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: const BoxDecoration(
                  color: AptiquColors.surfaceDim,
                  border: Border(top: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
                ),
                child: Obx(() {
                  final hasSelected = controller.selectedOptionId.value != null;
                  return ElevatedButton(
                    onPressed: hasSelected && !isSubmitting
                        ? () => controller.submitAnswer(context)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AptiquColors.tertiary,
                      disabledBackgroundColor: AptiquColors.surfaceContainerHigh,
                      foregroundColor: Colors.black,
                      disabledForegroundColor: AptiquColors.outline,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                          )
                        : Text(
                            'CONFIRM & REVEAL TRICK',
                            style: AptiquTypography.labelCaps.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                              fontSize: 13,
                              color: hasSelected ? Colors.black : AptiquColors.outline,
                            ),
                          ),
                  );
                }),
              ),
            ],
          );
        }),
        bottomSheet: Obx(() {
          if (!controller.showExplanation.value) return const SizedBox.shrink();
          final result = controller.lastAnswerResult.value;
          if (result == null) return const SizedBox.shrink();

          return _buildExplanationSheet(context, controller, result);
        }),
      ),
    );
  }

  Widget _buildOptionTile(DailyChallengeController controller, String optionId, String text) {
    return Obx(() {
      final isSelected = controller.selectedOptionId.value == optionId;

      return InkWell(
        onTap: () => controller.selectOption(optionId),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? AptiquColors.tertiary.withValues(alpha: 0.15)
                : AptiquColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AptiquColors.tertiary
                  : AptiquColors.outlineVariant,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AptiquColors.tertiary : AptiquColors.surfaceContainerHigh,
                ),
                alignment: Alignment.center,
                child: Text(
                  optionId,
                  style: AptiquTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.black : AptiquColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: AptiquTypography.bodyMedium.copyWith(
                    color: isSelected ? AptiquColors.onSurface : AptiquColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildExplanationSheet(
    BuildContext context,
    DailyChallengeController controller,
    DailyChallengeAnswerResultModel result,
  ) {
    final isCorrect = result.isCorrect;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AptiquColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result Header Pill
          Row(
            children: [
              Icon(
                isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: isCorrect ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                isCorrect ? 'Correct! Trick Solved.' : 'Incorrect or Timed Out',
                style: AptiquTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? Colors.green : Colors.red,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ans: ${result.correctAnswer}',
                  style: AptiquTypography.labelCaps.copyWith(
                    color: AptiquColors.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Shortcut Trick Callout Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AptiquColors.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AptiquColors.tertiary.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_rounded, color: AptiquColors.tertiary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '60-SECOND SPEED SHORTCUT',
                        style: AptiquTypography.labelCaps.copyWith(
                          color: AptiquColors.tertiary,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.method.isNotEmpty ? result.method : 'Mathematical elimination trick',
                        style: AptiquTypography.bodySmall.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Step-by-Step Explanation
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step-by-Step Breakdown:',
                    style: AptiquTypography.labelCaps.copyWith(
                      color: AptiquColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.explanation,
                    style: AptiquTypography.bodySmall.copyWith(
                      color: AptiquColors.onSurface,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Button
          ElevatedButton(
            onPressed: () {
              if (result.isComplete) {
                _showCompletionModal(context, controller, result);
              } else {
                controller.proceedNext(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AptiquColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              result.isComplete ? 'FINISH & CLAIM REWARDS' : 'NEXT QUESTION',
              style: AptiquTypography.labelCaps.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCompletionModal(
    BuildContext context,
    DailyChallengeController controller,
    DailyChallengeAnswerResultModel result,
  ) {
    final isSuccess = result.streakIncremented;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AptiquColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSuccess ? AptiquColors.tertiary : Colors.redAccent.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        title: Column(
          children: [
            Icon(
              isSuccess ? Icons.local_fire_department_rounded : Icons.cancel_outlined,
              color: isSuccess ? AptiquColors.tertiary : Colors.redAccent,
              size: 54,
            ),
            const SizedBox(height: 12),
            Text(
              isSuccess ? 'Daily Challenge Complete!' : 'Challenge Incomplete',
              style: AptiquTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: AptiquColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isSuccess ? 'Streak Increased to' : 'Streak Status',
              style: AptiquTypography.bodySmall.copyWith(color: AptiquColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              isSuccess ? '${result.streak} DAYS' : '0 DAYS',
              style: AptiquTypography.headlineLarge.copyWith(
                color: isSuccess ? AptiquColors.tertiary : Colors.redAccent,
                fontWeight: FontWeight.w900,
                fontSize: 34,
              ),
            ),
            const SizedBox(height: 12),
            if (isSuccess) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRewardBadge(Icons.bolt_rounded, '+${result.xpAwarded} XP', AptiquColors.primary),
                  _buildRewardBadge(Icons.monetization_on_rounded, '+${result.coinsAwarded} Coins', AptiquColors.tertiary),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'All questions must be answered correctly to maintain your daily streak and earn rewards. Streak has reset to 0.',
                  style: AptiquTypography.bodySmall.copyWith(
                    color: AptiquColors.onSurface,
                    fontSize: 12,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close dialog
              context.pop(); // Pop quiz screen back to hub
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? AptiquColors.tertiary : AptiquColors.surfaceContainerHigh,
              foregroundColor: isSuccess ? Colors.black : AptiquColors.onSurface,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('BACK TO ARENA', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            text,
            style: AptiquTypography.labelCaps.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmationDialog(BuildContext context, DailyChallengeController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AptiquColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Abandon Challenge?'),
        content: const Text(
          'Leaving now will leave this question unanswered. You can resume before midnight UTC to complete your streak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('STAY'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AptiquColors.error),
            child: const Text('LEAVE'),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toUpperCase()) {
      case 'HARD':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'EASY':
      default:
        return Colors.green;
    }
  }
}
