import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/layout/text_fit.dart';
import '../../models/lesson_node_model.dart';

/// Native choices keep whole labels; rows depend on measured content, not length.
class ChoiceInputWidget extends StatelessWidget {
  final LessonNodeModel node;
  final Function(String optionId, String label) onSelect;
  final bool isSubmitting;
  final String? primaryId;
  const ChoiceInputWidget({
    super.key,
    required this.node,
    required this.onSelect,
    this.isSubmitting = false,
    this.primaryId,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final options = node.choiceOptions;
      if (options.isEmpty) {
        return const Text('No choices are available for this step.');
      }
      final beside =
          options.length == 2 &&
          options.every(
            (o) => textFits(
              context,
              o.label,
              context.type.labelLarge!,
              (box.maxWidth - 12) / 2 - 32,
            ),
          );
      Widget choice(ChoiceOptionModel o) => o.id == primaryId
          ? FilledButton(
              onPressed: isSubmitting ? null : () => onSelect(o.id, o.label),
              child: Text(o.label, textAlign: TextAlign.center),
            )
          : OutlinedButton(
              onPressed: isSubmitting ? null : () => onSelect(o.id, o.label),
              child: Text(o.label, textAlign: TextAlign.center),
            );
      return beside
          ? Row(
              children: [
                Expanded(child: choice(options[0])),
                const SizedBox(width: 12),
                Expanded(child: choice(options[1])),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final o in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: choice(o),
                  ),
              ],
            );
    },
  );
}
