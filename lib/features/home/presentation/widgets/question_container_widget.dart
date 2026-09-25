import 'package:flutter/material.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../controllers/home_controller.dart';

/// Unified Question Container Widget
/// Contains: Question title, desc (actual question), difficulty,
/// input type (select, text, voice, scan) and interactive input controls based on input type.
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
  bool _isRecordingVoice = false;

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerLow.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AptiquColors.primaryContainer.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Cyber Accent Line
          Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AptiquColors.primaryContainer,
                  AptiquColors.secondary,
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Header: Question Title + Difficulty Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(q.inputType),
                      size: 15,
                      color: AptiquColors.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        q.title.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: AptiquTypography.labelCapsBold.copyWith(
                          color: AptiquColors.tertiary,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(maxWidth: 130),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AptiquColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AptiquColors.outlineVariant),
                ),
                child: Text(
                  q.difficulty.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AptiquTypography.labelCaps.copyWith(
                    color: AptiquColors.secondary,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Actual Question / Description
          Text(
            q.desc,
            style: AptiquTypography.bodyMd.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
              color: AptiquColors.onSurface,
            ),
          ),
          const SizedBox(height: 14),

          const Divider(color: AptiquColors.outlineVariant, height: 1),
          const SizedBox(height: 12),

          // Dynamic Input Section based on inputType
          _buildInputSection(q),
        ],
      ),
    );
  }

  Widget _buildInputSection(QuestionData q) {
    switch (q.inputType) {
      case QuestionInputType.select:
        return _buildSelectInput(q);
      case QuestionInputType.text:
        return _buildTextInput(q);
      case QuestionInputType.voice:
        return _buildVoiceInput(q);
      case QuestionInputType.scan:
        return _buildScanInput(q);
      case QuestionInputType.none:
        return const SizedBox.shrink();
    }
  }

  /// 1. SELECT INPUT TYPE (Buttons/Options)
  Widget _buildSelectInput(QuestionData q) {
    final isBinaryChoice = q.options.length <= 2;

    if (isBinaryChoice) {
      return Row(
        children: List.generate(q.options.length, (idx) {
          final optionText = q.options[idx];
          final isSelected = q.selectedOptionIndex == idx;
          final isPrimaryAction = idx == 0;

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: idx > 0 ? 8 : 0),
              child: InkWell(
                onTap: q.isCompleted
                    ? null
                    : () => widget.controller.handleOptionSelection(
                          widget.messageId,
                          idx,
                        ),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: (isSelected || (isPrimaryAction && !q.isCompleted))
                        ? AptiquColors.primaryGradient
                        : null,
                    color: (isSelected || (isPrimaryAction && !q.isCompleted))
                        ? null
                        : AptiquColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (isSelected || (isPrimaryAction && !q.isCompleted))
                          ? AptiquColors.primaryContainer
                          : AptiquColors.outlineVariant,
                      width: 1.2,
                    ),
                    boxShadow: (isSelected ||
                            (isPrimaryAction && !q.isCompleted))
                        ? [
                            BoxShadow(
                              color: AptiquColors.primaryContainer
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      optionText,
                      textAlign: TextAlign.center,
                      style: AptiquTypography.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            (isSelected || (isPrimaryAction && !q.isCompleted))
                                ? Colors.white
                                : AptiquColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
    }

    // Grid for 4-option MCQs (A, B, C, D)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemCount: q.options.length,
      itemBuilder: (context, optIdx) {
        final optionText = q.options[optIdx];
        final optionLetter = String.fromCharCode(65 + optIdx); // A, B, C, D
        final isSelected = q.selectedOptionIndex == optIdx;

        return InkWell(
          onTap: q.isCompleted
              ? null
              : () => widget.controller.handleOptionSelection(
                    widget.messageId,
                    optIdx,
                  ),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AptiquColors.secondary.withValues(alpha: 0.18)
                  : AptiquColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AptiquColors.secondary
                    : AptiquColors.outlineVariant.withValues(alpha: 0.8),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected ? AptiquColors.secondaryGlow : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AptiquColors.secondary.withValues(alpha: 0.25)
                        : AptiquColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    optionLetter,
                    style: AptiquTypography.labelCapsBold.copyWith(
                      fontSize: 10,
                      color: isSelected
                          ? AptiquColors.secondary
                          : AptiquColors.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    optionText,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AptiquTypography.metricMd.copyWith(
                      fontSize: 13,
                      color: isSelected ? Colors.white : AptiquColors.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 2. TEXT INPUT TYPE (Inline input inside card)
  Widget _buildTextInput(QuestionData q) {
    if (q.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AptiquColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AptiquColors.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Submitted: ${q.submittedText ?? ""}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AptiquColors.primaryContainer.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inlineTextController,
              style: AptiquTypography.bodyMd.copyWith(
                color: AptiquColors.onSurface,
                fontSize: 13,
              ),
              cursorColor: AptiquColors.primaryContainer,
              decoration: InputDecoration(
                hintText: q.placeholder ?? 'Enter your answer...',
                hintStyle: AptiquTypography.bodyMd.copyWith(
                  color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12.5,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (text) =>
                  widget.controller.handleTextSubmission(widget.messageId, text),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => widget.controller.handleTextSubmission(
              widget.messageId,
              _inlineTextController.text,
            ),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: AptiquColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AptiquColors.primaryGlow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Submit',
                    style: AptiquTypography.labelCapsBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. VOICE INPUT TYPE (Viva/Speaking Mode)
  Widget _buildVoiceInput(QuestionData q) {
    if (q.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AptiquColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_none_rounded,
                color: AptiquColors.tertiary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Viva Voice Response Submitted ✓',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.tertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() => _isRecordingVoice = true);
            Future.delayed(const Duration(milliseconds: 1400), () {
              if (mounted) {
                setState(() => _isRecordingVoice = false);
                widget.controller.handleVoiceSubmission(widget.messageId);
              }
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isRecordingVoice
                    ? [Colors.redAccent, const Color(0xFFB91C1C)]
                    : [
                        AptiquColors.tertiaryContainer,
                        const Color(0xFFB45309),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _isRecordingVoice
                      ? Colors.redAccent.withValues(alpha: 0.5)
                      : AptiquColors.tertiary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isRecordingVoice ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _isRecordingVoice
                        ? 'Listening & Transcribing Reasoning...'
                        : 'Tap to Speak & Explain Concept (Viva)',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AptiquTypography.bodySm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AptiQu AI analyzes clarity, step reasoning, and technical terms.',
          style: AptiquTypography.bodySm.copyWith(
            fontSize: 10.5,
            color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  /// 4. SCAN INPUT TYPE (Scratchpad Notes Upload)
  Widget _buildScanInput(QuestionData q) {
    if (q.isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AptiquColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AptiquColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.document_scanner_rounded,
                color: AptiquColors.secondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Handwritten Solution Uploaded & Verified ✓',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => widget.controller.handleScanSubmission(widget.messageId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
        decoration: BoxDecoration(
          color: AptiquColors.secondary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AptiquColors.secondary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: AptiquColors.secondaryGlow,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_rounded,
                color: AptiquColors.secondary, size: 20),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'Scan Scratchpad / Upload Notes',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: AptiquTypography.bodySm.copyWith(
                  color: AptiquColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(QuestionInputType type) {
    switch (type) {
      case QuestionInputType.select:
        return Icons.checklist_rounded;
      case QuestionInputType.text:
        return Icons.edit_note_rounded;
      case QuestionInputType.voice:
        return Icons.record_voice_over_rounded;
      case QuestionInputType.scan:
        return Icons.draw_rounded;
      case QuestionInputType.none:
        return Icons.help_outline_rounded;
    }
  }
}
