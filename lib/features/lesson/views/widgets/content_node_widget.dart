import 'package:flutter/material.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../models/lesson_node_model.dart';
import 'choice_input_widget.dart';

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
  Widget build(BuildContext context) => node.choiceOptions.isEmpty
      ? AptiquButton(
          label: 'Continue',
          isLoading: isSubmitting,
          onPressed: isSubmitting
              ? null
              : () => onAction('continue', 'Continue'),
        )
      : ChoiceInputWidget(
          node: node,
          primaryId: node.choiceOptions
              .where((o) => !o.id.toLowerCase().contains('doubt'))
              .firstOrNull
              ?.id,
          isSubmitting: isSubmitting,
          onSelect: (id, label) => id.toLowerCase().contains('doubt')
              ? onDoubt()
              : onAction(id, label),
        );
}
