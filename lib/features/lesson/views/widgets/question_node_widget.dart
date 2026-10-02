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
              margin: EdgeInsets.only(bottom: (inline.pyq != null && inline.pyq!.trim().isNotEmpty) ? 6 : 12),
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
            if (inline.pyq != null && inline.pyq!.trim().isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            inline.pyq!,
                            style: AptiquTypography.labelSmall.copyWith(
                              color: const Color(0xFF92400E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
