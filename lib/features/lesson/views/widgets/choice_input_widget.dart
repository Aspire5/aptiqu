import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/lesson_node_model.dart';

class ChoiceInputWidget extends StatelessWidget {
  final LessonNodeModel node;
  final Function(String optionId, String label) onSelect;
  final bool isSubmitting;

  const ChoiceInputWidget({
    super.key,
    required this.node,
    required this.onSelect,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    if (node.choiceOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: node.choiceOptions.map((opt) {
          return SizedBox(
            width: node.choiceOptions.length > 2 ? 140 : 160,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AptiquColors.surfaceContainerHigh,
                foregroundColor: AptiquColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AptiquColors.primaryContainer),
                ),
                elevation: 2,
              ),
              onPressed: isSubmitting ? null : () => onSelect(opt.id, opt.label),
              child: Text(
                opt.label,
                textAlign: TextAlign.center,
                style: AptiquTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
