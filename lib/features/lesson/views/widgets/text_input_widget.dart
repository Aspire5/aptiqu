import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
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
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isSubmitting) return;
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onVoiceTap,
            icon: const Icon(Icons.mic_none, color: AptiquColors.secondary),
            tooltip: 'Voice input (Coming soon)',
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              style: AptiquTypography.bodyLg.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: widget.node.inputPlaceholder ?? 'Type your answer...',
                hintStyle: AptiquTypography.bodyMd.copyWith(color: AptiquColors.onSurfaceDisabled),
                filled: true,
                fillColor: AptiquColors.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AptiquColors.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AptiquColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AptiquColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: widget.isSubmitting ? null : _handleSend,
            style: IconButton.styleFrom(
              backgroundColor: AptiquColors.primaryContainer,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}
