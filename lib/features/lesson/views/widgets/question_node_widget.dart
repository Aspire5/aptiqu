import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/lesson_node_model.dart';

class QuestionNodeWidget extends StatefulWidget {
  final LessonNodeModel node;
  final Function(String answerId, String displayText, int responseTimeMs) onAnswerSubmitted;
  final VoidCallback onDoubt;
  final bool isSubmitting;

  const QuestionNodeWidget({
    super.key,
    required this.node,
    required this.onAnswerSubmitted,
    required this.onDoubt,
    this.isSubmitting = false,
  });

  @override
  State<QuestionNodeWidget> createState() => _QuestionNodeWidgetState();
}

class _QuestionNodeWidgetState extends State<QuestionNodeWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  String? _selectedOptionId;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
  }

  @override
  Widget build(BuildContext context) {
    final inline = widget.node.inlineQuestion;
    final options = inline?.options ?? widget.node.choiceOptions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inline != null && inline.prompt.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AptiquColors.outlineVariant),
              ),
              child: Text(
                inline.prompt,
                style: AptiquTypography.headlineSm.copyWith(
                  color: AptiquColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          ...options.map((opt) {
            final isSelected = _selectedOptionId == opt.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _selectedOptionId = opt.id;
                        });
                        _stopwatch.stop();
                        widget.onAnswerSubmitted(
                          opt.id,
                          opt.label,
                          _stopwatch.elapsedMilliseconds,
                        );
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AptiquColors.primaryDark
                        : AptiquColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AptiquColors.primary
                          : AptiquColors.outlineVariant,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AptiquColors.primary
                              : AptiquColors.surfaceContainerLowest,
                        ),
                        child: Center(
                          child: Text(
                            opt.id.toUpperCase().replaceAll('ANS_', '').replaceAll('OPT_', ''),
                            style: AptiquTypography.metricMd.copyWith(
                              color: isSelected ? Colors.black : AptiquColors.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          opt.label,
                          style: AptiquTypography.bodyLg.copyWith(
                            color: isSelected ? Colors.white : AptiquColors.onSurface,
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
        ],
      ),
    );
  }
}
