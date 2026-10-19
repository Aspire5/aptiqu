import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import '../controllers/home_controller.dart';

class QuestionContainerWidget extends StatefulWidget {
  final String messageId;
  final QuestionData question;
  final HomeController controller;
  const QuestionContainerWidget({
    super.key,
    required this.messageId,
    required this.question,
    required this.controller,
  });

  @override
  State<QuestionContainerWidget> createState() =>
      _QuestionContainerWidgetState();
}

class _QuestionContainerWidgetState extends State<QuestionContainerWidget> {
  late final TextEditingController _inlineTextController;
  @override
  void initState() {
    super.initState();
    _inlineTextController = TextEditingController();
  }

  @override
  void dispose() {
    _inlineTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                q.questionType.displayName,
                style: context.type.labelMedium!.copyWith(
                  color: context.colors.primary,
                ),
              ),
              Text(
                q.difficultyLevel.displayName,
                style: context.type.labelMedium!.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (!q.isCompleted && q.xp > 0)
                Text(
                  '+${q.xp} XP',
                  style: context.type.labelMedium!.copyWith(
                    color: context.status.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(q.desc, style: context.type.bodyLarge),
          if (q.hints.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() {
                  if (q.revealedHintsCount < q.hints.length) {
                    q.revealedHintsCount++;
                  } else {
                    q.revealedHintsCount = 0;
                  }
                }),
                icon: const Icon(Icons.lightbulb_outline_rounded, size: 20),
                label: Text(
                  q.revealedHintsCount == 0
                      ? 'Hint (${q.hints.length})'
                      : 'Hint ${q.revealedHintsCount}/${q.hints.length}',
                ),
              ),
            ),
            if (q.revealedHintsCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.status.warningContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < q.revealedHintsCount; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Hint ${i + 1}: ${q.hints[i]}',
                          style: context.type.bodyLarge!.copyWith(
                            color: context.status.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
          Obx(() => _buildInputSection(q)),
        ],
      ),
    );
  }

  bool _isOptionCorrect(QuestionData q, int index) {
    if (!q.hasEvaluated) return false;
    if (q.correctOptionId != null &&
        q.optionIds.isNotEmpty &&
        index < q.optionIds.length) {
      return q.optionIds[index].toLowerCase() ==
          q.correctOptionId!.toLowerCase();
    }
    return q.isUserCorrect == true && q.selectedOptionIndex == index;
  }

  bool _isOptionWrongSelected(QuestionData q, int index) =>
      q.hasEvaluated &&
      q.selectedOptionIndex == index &&
      q.isUserCorrect == false;

  Widget _buildInputSection(QuestionData q) {
    final busy = widget.controller.isSubmittingAction.value;
    return switch (q.inputType) {
      QuestionInputType.select => _buildSelectInput(q),
      QuestionInputType.text => _buildTextInput(q, busy),
      QuestionInputType.voice => _unavailable(
        q,
        'Voice answers',
        Icons.mic_none_rounded,
      ),
      QuestionInputType.scan => _unavailable(
        q,
        'Scan notes',
        Icons.document_scanner_outlined,
      ),
      QuestionInputType.none => const SizedBox.shrink(),
    };
  }

  Widget _unavailable(QuestionData q, String label, IconData icon) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: null,
        icon: Icon(icon),
        label: Text('$label · Coming soon'),
      ),
      const SizedBox(height: 8),
      Text(
        'This tool is not available yet. Use Close lesson to return to Home.',
        style: context.type.bodyMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );

  // Flexible rows avoid the previous fixed-aspect grid at enlarged text sizes.
  Widget _buildSelectInput(QuestionData q) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < q.options.length; index++)
        Padding(
          padding: EdgeInsets.only(
            bottom: index < q.options.length - 1 ? 8 : 0,
          ),
          child: _option(q, index),
        ),
    ],
  );

  Widget _option(QuestionData q, int index) {
    final selected = q.selectedOptionIndex == index;
    final correct = _isOptionCorrect(q, index);
    final wrong = _isOptionWrongSelected(q, index);
    final bg = correct
        ? context.status.successContainer
        : wrong
        ? context.colors.errorContainer
        : selected
        ? context.colors.primaryContainer
        : context.colors.surface;
    final fg = correct
        ? context.status.success
        : wrong
        ? context.colors.onErrorContainer
        : selected
        ? context.colors.onPrimaryContainer
        : context.colors.onSurface;
    final state = correct
        ? 'Correct answer'
        : wrong
        ? 'Your answer · incorrect'
        : selected
        ? 'Selected'
        : q.isCompleted
        ? 'Answer locked'
        : null;
    return Semantics(
      selected: selected,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledForegroundColor: fg,
          disabledBackgroundColor: bg,
          minimumSize: const Size(48, 56),
          padding: const EdgeInsets.all(12),
          side: BorderSide(
            color: correct || wrong || selected ? fg : context.colors.outline,
            width: correct || wrong || selected ? 2 : 1,
          ),
        ),
        onPressed: q.isCompleted || widget.controller.isSubmittingAction.value
            ? null
            : () => widget.controller.handleOptionSelection(
                widget.messageId,
                index,
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              String.fromCharCode(65 + index),
              style: context.type.labelLarge!.copyWith(color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    q.options[index],
                    style: context.type.bodyLarge!.copyWith(color: fg),
                  ),
                  if (state != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        state,
                        style: context.type.labelMedium!.copyWith(color: fg),
                      ),
                    ),
                ],
              ),
            ),
            if (correct || wrong || selected) ...[
              const SizedBox(width: 8),
              Icon(
                correct
                    ? Icons.check_circle_outline
                    : wrong
                    ? Icons.cancel_outlined
                    : Icons.radio_button_checked,
                size: 20,
                color: fg,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextInput(QuestionData q, bool busy) {
    if (q.isCompleted) {
      return Text(
        'Submitted: ${q.submittedText ?? ""}',
        style: context.type.bodyLarge,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _inlineTextController,
          style: context.type.bodyLarge,
          decoration: InputDecoration(
            labelText: 'Your answer',
            hintText: q.placeholder ?? 'Enter your answer',
          ),
          enabled: !busy,
          textInputAction: TextInputAction.send,
          onSubmitted: (text) =>
              widget.controller.handleTextSubmission(widget.messageId, text),
        ),
        const SizedBox(height: 12),
        AptiquButton(
          label: 'Submit',
          isLoading: busy,
          onPressed: () => widget.controller.handleTextSubmission(
            widget.messageId,
            _inlineTextController.text,
          ),
        ),
      ],
    );
  }
}
