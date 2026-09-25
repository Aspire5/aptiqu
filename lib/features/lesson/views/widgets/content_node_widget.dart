import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../models/lesson_node_model.dart';

class ContentNodeWidget extends StatelessWidget {
  final LessonNodeModel node;
  final Function(String actionId, String label) onAction;
  final VoidCallback onDoubt;
  final bool isSubmitting;

  const ContentNodeWidget({
    super.key,
    required this.node,
    required this.onAction,
    required this.onDoubt,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (node.choiceOptions.isNotEmpty)
            Row(
              children: node.choiceOptions.map((opt) {
                final isDoubt = opt.id.toLowerCase().contains('doubt');
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDoubt
                            ? AptiquColors.surfaceContainer
                            : AptiquColors.primaryContainer,
                        foregroundColor: isDoubt
                            ? AptiquColors.tertiary
                            : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: isDoubt
                              ? const BorderSide(color: AptiquColors.tertiaryContainer)
                              : BorderSide.none,
                        ),
                      ),
                      onPressed: isSubmitting
                          ? null
                          : () {
                              if (isDoubt) {
                                onDoubt();
                              } else {
                                onAction(opt.id, opt.label);
                              }
                            },
                      child: Text(
                        opt.label,
                        style: AptiquTypography.headlineSm.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AptiquColors.primaryContainer,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () => onAction('continue', 'Continue'),
              child: Text(
                'Continue',
                style: AptiquTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
