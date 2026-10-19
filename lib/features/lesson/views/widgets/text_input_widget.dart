import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../models/lesson_node_model.dart';

class TextInputWidget extends StatefulWidget {
  final LessonNodeModel node;
  final Function(String text) onSubmit;
  final VoidCallback onVoiceTap;
  final bool isSubmitting;
  const TextInputWidget({
    super.key,
    required this.node,
    required this.onSubmit,
    required this.onVoiceTap,
    this.isSubmitting = false,
  });
  @override
  State<TextInputWidget> createState() => _TextInputWidgetState();
}

class _TextInputWidgetState extends State<TextInputWidget> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isNotEmpty && !widget.isSubmitting) widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _controller,
    builder: (context, value, _) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !widget.isSubmitting,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: context.type.bodyLarge,
            decoration: InputDecoration(
              labelText: 'Your answer',
              hintText: widget.node.inputPlaceholder ?? 'Type your answer',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: widget.isSubmitting ? 'Sending answer' : 'Send answer',
          onPressed: widget.isSubmitting || value.text.trim().isEmpty
              ? null
              : _send,
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
      ],
    ),
  );
}
