import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../models/practice_models.dart';
import '../controllers/practice_session_controller.dart';

class PracticeSessionScreen extends StatelessWidget {
  final PracticeSessionModel initialSession;

  const PracticeSessionScreen({super.key, required this.initialSession});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PracticeSessionController(initialSession));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitConfirmation(context, controller);
      },
      child: Scaffold(
        backgroundColor: AptiquColors.surfaceDim,
        appBar: AppBar(
          backgroundColor: AptiquColors.surfaceDim,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AptiquColors.onSurface),
            onPressed: () => _showExitConfirmation(context, controller),
          ),
          title: Obx(() {
            final cur = controller.currentQuestionIndex.value + 1;
            final total = controller.session.value.totalQuestions;
            return Text(
              'Question $cur of $total',
              style: AptiquTypography.titleMedium.copyWith(color: AptiquColors.onSurface),
            );
          }),
          centerTitle: true,
          actions: [
            Obx(() {
              final curQ = controller.currentSessionQuestion;
              final hints = curQ?.question.hints ?? [];
              final revealed = controller.hintsRevealed.value;

              return TextButton.icon(
                onPressed: hints.isEmpty
                    ? null
                    : () => _showHintsSheet(context, controller, hints),
                icon: Icon(
                  Icons.lightbulb_outline_rounded,
                  color: revealed > 0 ? const Color(0xFFF59E0B) : AptiquColors.onSurfaceVariant,
                  size: 20,
                ),
                label: Text(
                  revealed > 0 ? 'Hint ($revealed/2)' : 'Hints',
                  style: AptiquTypography.labelMedium.copyWith(
                    color: revealed > 0 ? const Color(0xFFF59E0B) : AptiquColors.onSurfaceVariant,
                  ),
                ),
              );
            }),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: Obx(() {
              final cur = controller.currentQuestionIndex.value + 1;
              final total = controller.session.value.totalQuestions;
              final progress = cur / total;

              return LinearProgressIndicator(
                value: progress,
                backgroundColor: AptiquColors.surfaceContainerHigh,
                valueColor: const AlwaysStoppedAnimation<Color>(AptiquColors.primary),
                minHeight: 4,
              );
            }),
          ),
        ),
        body: Obx(() {
          if (controller.isCompleted.value) {
            return _buildCompletionView(context, controller);
          }

          final curQ = controller.currentSessionQuestion;
          if (curQ == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final question = curQ.question;
          final lastRes = controller.lastResult.value;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Difficulty & Mode Badges
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(question.difficulty).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                question.difficulty,
                                style: AptiquTypography.labelSmall.copyWith(
                                  color: _getDifficultyColor(question.difficulty),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AptiquColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                question.calculationMode.toHumanCalculationMode(),
                                style: AptiquTypography.labelSmall.copyWith(
                                  color: AptiquColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (question.pattern != null && question.pattern!.trim().isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            question.pattern!,
                            style: AptiquTypography.labelSmall.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Question Prompt Box
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AptiquColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AptiquColors.outlineVariant),
                          ),
                          child: Text(
                            question.prompt,
                            style: AptiquTypography.headlineSmall.copyWith(
                              color: AptiquColors.onSurface,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (question.pyq != null && question.pyq!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🏛️ ', style: TextStyle(fontSize: 12)),
                                Flexible(
                                  child: Text(
                                    question.pyq!,
                                    style: AptiquTypography.labelSmall.copyWith(
                                      color: const Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // 4 Multiple Choice Options
                        ...question.options.map((opt) {
                          final isSelected = controller.selectedOptionId.value == opt.id;
                          Color cardColor = AptiquColors.surfaceContainerHigh;
                          Color borderColor = AptiquColors.outlineVariant;
                          Color textColor = AptiquColors.onSurface;

                          if (lastRes != null) {
                            if (opt.id == lastRes.correctAnswer) {
                              cardColor = const Color(0xFF10B981).withValues(alpha: 0.2);
                              borderColor = const Color(0xFF10B981);
                              textColor = const Color(0xFF10B981);
                            } else if (isSelected && !lastRes.isCorrect) {
                              cardColor = const Color(0xFFEF4444).withValues(alpha: 0.2);
                              borderColor = const Color(0xFFEF4444);
                              textColor = const Color(0xFFEF4444);
                            }
                          } else if (isSelected) {
                            cardColor = AptiquColors.primary.withValues(alpha: 0.2);
                            borderColor = AptiquColors.primary;
                            textColor = AptiquColors.primary;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              onTap: lastRes != null ? null : () => controller.selectOption(opt.id),
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected ? borderColor : Colors.transparent,
                                        border: Border.all(color: borderColor, width: 1.5),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        opt.id,
                                        style: AptiquTypography.labelMedium.copyWith(
                                          color: isSelected ? Colors.white : textColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        opt.text,
                                        style: AptiquTypography.bodyLarge.copyWith(
                                          color: textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                        // Dual Solution Banner after answer
                        if (lastRes != null) ...[
                          const SizedBox(height: 16),
                          _buildDualSolutionCard(context, question, lastRes),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bottom Action Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AptiquColors.surfaceDim,
                    border: Border(top: BorderSide(color: AptiquColors.outlineVariant, width: 0.5)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: lastRes != null
                          ? controller.nextQuestion
                          : controller.selectedOptionId.value.isEmpty || controller.isSubmitting.value
                              ? null
                              : controller.submitAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lastRes != null ? const Color(0xFF10B981) : AptiquColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: controller.isSubmitting.value
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              lastRes != null
                                  ? (controller.currentQuestionIndex.value < controller.session.value.totalQuestions - 1
                                      ? 'Next Question'
                                      : 'Continue to Summary')
                                  : 'Submit Answer',
                              style: AptiquTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Color _getDifficultyColor(String diff) {
    switch (diff.toUpperCase()) {
      case 'HARD':
        return const Color(0xFFEF4444);
      case 'MEDIUM':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  void _showHintsSheet(BuildContext context, PracticeSessionController controller, List<String> hints) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AptiquColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Obx(() {
          final count = controller.hintsRevealed.value;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Strategy Hints',
                      style: AptiquTypography.titleMedium.copyWith(
                        color: AptiquColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (count >= 1 && hints.isNotEmpty) ...[
                  _buildHintCard(1, hints[0]),
                  const SizedBox(height: 12),
                ],
                if (count >= 2 && hints.length > 1) ...[
                  _buildHintCard(2, hints[1]),
                  const SizedBox(height: 12),
                ],
                if (count < 2 && count < hints.length) ...[
                  ElevatedButton(
                    onPressed: controller.revealNextHint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AptiquColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Reveal Hint ${count + 1}'),
                  ),
                ],
              ],
            ),
          );
        });
      },
    );
  }

  Widget _buildHintCard(int index, String text) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hint $index',
            style: AptiquTypography.labelSmall.copyWith(
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionView(BuildContext context, PracticeSessionController controller) {
    final res = controller.completionResult.value ?? controller.lastResult.value;
    final correct = res?.correctCount ?? controller.session.value.correctCount;
    final total = controller.session.value.totalQuestions;
    final xpEarned = res?.xpAwarded ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF10B981), width: 2),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFF10B981), size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              'Session Completed!',
              style: AptiquTypography.headlineMedium.copyWith(
                color: AptiquColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You scored $correct out of $total questions correct',
              style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.onSurfaceVariant),
            ),
            if (xpEarned > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AptiquColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AptiquColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, color: AptiquColors.primary, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      '+$xpEarned XP Earned',
                      style: AptiquTypography.titleMedium.copyWith(
                        color: AptiquColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Return to Practice Arena'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExitConfirmation(BuildContext context, PracticeSessionController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AptiquColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Exit Practice?', style: AptiquTypography.titleMedium.copyWith(color: AptiquColors.onSurface)),
        content: Text(
          'If you exit now, your session will be marked as abandoned and zero completion XP will be awarded.',
          style: AptiquTypography.bodyMedium.copyWith(color: AptiquColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Practicing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.abandon();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AptiquColors.error, foregroundColor: Colors.white),
            child: const Text('Exit (0 XP)'),
          ),
        ],
      ),
    );
  }

  Widget _buildDualSolutionCard(BuildContext context, PracticeQuestionModel question, PracticeAnswerResultModel lastRes) {
    final bookExplanation = lastRes.explanation.isNotEmpty ? lastRes.explanation : (question.explanation ?? '');
    final bookMethod = lastRes.method.isNotEmpty ? lastRes.method : (question.method ?? '');
    final altExplanation = lastRes.alternativeExplanation ?? question.alternativeExplanation;
    final preferredSol = lastRes.preferredSolution ?? question.preferredSolution;
    final preferredReason = lastRes.preferredReason ?? question.preferredReason;

    final hasDualSolutions = altExplanation != null && altExplanation.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lastRes.isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                lastRes.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: lastRes.isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lastRes.isCorrect ? 'Correct!' : 'Incorrect (Answer: Option ${lastRes.correctAnswer})',
                  style: AptiquTypography.titleSmall.copyWith(
                    color: lastRes.isCorrect ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Solution 1: Book Method
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: preferredSol == 'BOOK' ? const Color(0xFF10B981) : AptiquColors.outlineVariant,
                width: preferredSol == 'BOOK' ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '📖 Book Method',
                      style: AptiquTypography.labelMedium.copyWith(
                        color: AptiquColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (preferredSol == 'BOOK')
                      InkWell(
                        onTap: () => _showPreferredReasonBottomSheet(context, 'Book Method', preferredReason),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'AI Preferred',
                                style: AptiquTypography.labelSmall.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.info_outline, color: Color(0xFF10B981), size: 12),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (bookMethod.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Formula / Method: $bookMethod',
                    style: AptiquTypography.bodySmall.copyWith(
                      color: const Color(0xFF38BDF8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  bookExplanation.isNotEmpty ? bookExplanation : 'Standard textbook derivation.',
                  style: AptiquTypography.bodyMedium.copyWith(
                    color: AptiquColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Solution 2: Alternative Speed Shortcut (if exists)
          if (hasDualSolutions) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: preferredSol == 'ALTERNATIVE' ? const Color(0xFF10B981) : AptiquColors.outlineVariant,
                  width: preferredSol == 'ALTERNATIVE' ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '⚡ Alternative Speed Shortcut',
                        style: AptiquTypography.labelMedium.copyWith(
                          color: AptiquColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (preferredSol == 'ALTERNATIVE')
                        InkWell(
                          onTap: () => _showPreferredReasonBottomSheet(context, 'Alternative Speed Shortcut', preferredReason),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'AI Preferred',
                                  style: AptiquTypography.labelSmall.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.info_outline, color: Color(0xFF10B981), size: 12),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    altExplanation,
                    style: AptiquTypography.bodyMedium.copyWith(
                      color: AptiquColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPreferredReasonBottomSheet(BuildContext context, String preferredTitle, String? reason) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AptiquColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AptiquColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'AI Preferred: $preferredTitle',
                    style: AptiquTypography.titleMedium.copyWith(
                      color: AptiquColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reason != null && reason.trim().isNotEmpty
                    ? reason
                    : 'This method is recommended by AptiQu for maximum time efficiency and conceptual clarity under competitive exam constraints.',
                style: AptiquTypography.bodyMedium.copyWith(
                  color: AptiquColors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AptiquColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
