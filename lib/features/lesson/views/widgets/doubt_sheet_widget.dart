import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../../shared/widgets/sheets/app_sheet.dart';
import '../../controllers/lesson_feed_controller.dart';

class DoubtSheetWidget extends StatefulWidget {
  final LessonFeedController controller;
  const DoubtSheetWidget({super.key, required this.controller});
  static Future<void> show(
    BuildContext context,
    LessonFeedController controller,
  ) async {
    await showAppSheet<void>(
      context: context,
      title: 'Ask tutor',
      builder: (_) => DoubtSheetWidget(controller: controller),
    );
  }

  @override
  State<DoubtSheetWidget> createState() => _DoubtSheetWidgetState();
}

class _DoubtSheetWidgetState extends State<DoubtSheetWidget> {
  final _question = TextEditingController();
  bool _loading = false, _unavailable = false;
  String? _reply, _error;
  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    final query = _question.text.trim();
    if (query.isEmpty || _loading || _unavailable) return;
    setState(() {
      _loading = true;
      _reply = null;
      _error = null;
    });
    try {
      final reply = await widget.controller.submitDoubt(query);
      if (!mounted) return;
      setState(() {
        _unavailable = widget.controller.doubtUnavailable.value;
        _reply = widget.controller.doubtError.value == null && !_unavailable
            ? reply
            : null;
        _error = widget.controller.doubtError.value;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not reach your tutor. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Tutor preview',
        style: context.type.labelLarge?.copyWith(color: context.colors.primary),
      ),
      const SizedBox(height: 8),
      Text(
        'What would you like help with on this step?',
        style: context.type.bodyLarge,
      ),
      const SizedBox(height: 16),
      if (_unavailable) ...[
        Semantics(
          liveRegion: true,
          child: Text('Tutor · Coming soon', style: context.type.titleSmall),
        ),
        const SizedBox(height: 8),
        Text(
          'Personal tutor explanations are not available yet. Continue with your lesson for now.',
          style: context.type.bodyLarge,
        ),
        const SizedBox(height: 16),
      ],
      if (_reply != null) ...[
        Semantics(
          liveRegion: true,
          child: Text('Tutor reply', style: context.type.titleSmall),
        ),
        const SizedBox(height: 8),
        Text(_reply!, style: context.type.bodyLarge),
        const SizedBox(height: 24),
      ],
      if (_error != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: context.type.bodyMedium?.copyWith(
              color: context.colors.error,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      TextField(
        controller: _question,
        enabled: !_loading,
        readOnly: _unavailable,
        maxLength: 500,
        minLines: 1,
        maxLines: 4,
        style: context.type.bodyLarge,
        decoration: const InputDecoration(
          labelText: 'Your question',
          hintText: 'What would you like explained?',
        ),
      ),
      const SizedBox(height: 16),
      if (!_unavailable)
        ValueListenableBuilder(
          valueListenable: _question,
          builder: (context, value, _) => AptiquButton(
            label: _loading
                ? 'Asking tutor…'
                : _error != null
                ? 'Try again'
                : 'Ask tutor',
            isLoading: _loading,
            onPressed: _loading || value.text.trim().isEmpty ? null : _ask,
          ),
        ),
    ],
  );
}
