import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';
import '../../controllers/lesson_feed_controller.dart';

class DoubtSheetWidget extends StatefulWidget {
  final LessonFeedController controller;

  const DoubtSheetWidget({super.key, required this.controller});

  static Future<void> show(BuildContext context, LessonFeedController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DoubtSheetWidget(controller: controller),
    );
  }

  @override
  State<DoubtSheetWidget> createState() => _DoubtSheetWidgetState();
}

class _DoubtSheetWidgetState extends State<DoubtSheetWidget> {
  final TextEditingController _questionController = TextEditingController();
  bool _isLoading = false;
  String? _tutorReply;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _handleAskDoubt() async {
    final query = _questionController.text.trim();
    if (query.isEmpty || _isLoading) return;

    setState(() {
      _isLoading = true;
      _tutorReply = null;
    });

    final reply = await widget.controller.submitDoubt(query);

    setState(() {
      _isLoading = false;
      _tutorReply = reply;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: bottomInset + 20,
      ),
      decoration: const BoxDecoration(
        color: AptiquColors.surfaceContainerHigh,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline, color: AptiquColors.tertiary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Ask Tutor a Doubt',
                    style: AptiquTypography.headlineSm.copyWith(
                      color: AptiquColors.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AptiquColors.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Stuck on this step? Type what you are confused about and your AI tutor will assist you.',
            style: AptiquTypography.bodyMd.copyWith(color: AptiquColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          if (_tutorReply != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AptiquColors.tertiaryContainer),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: AptiquColors.tertiary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tutorReply!,
                      style: AptiquTypography.bodyMd.copyWith(
                        color: AptiquColors.onSurface,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _questionController,
            maxLines: 3,
            minLines: 1,
            style: AptiquTypography.bodyLg.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. Why is 4:8 the same as 1:2?',
              hintStyle: AptiquTypography.bodyMd.copyWith(color: AptiquColors.onSurfaceDisabled),
              filled: true,
              fillColor: AptiquColors.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AptiquColors.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AptiquColors.tertiaryContainer,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleAskDoubt,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Ask Tutor'),
          ),
        ],
      ),
    );
  }
}
