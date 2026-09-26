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

          // Header: Question Type & Difficulty & XP Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AptiquColors.primaryContainer.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AptiquColors.primaryContainer.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(q.inputType),
                            size: 13,
                            color: AptiquColors.primary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            q.questionType.displayName.toUpperCase(),
                            style: AptiquTypography.labelCapsBold.copyWith(
                              color: AptiquColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(q.difficultyLevel).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getDifficultyColor(q.difficultyLevel).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      q.difficultyLevel.displayName.toUpperCase(),
                      style: AptiquTypography.labelCapsBold.copyWith(
                        color: _getDifficultyColor(q.difficultyLevel),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFFF59E0B)),
                        Text(
                          '+${q.xp} XP',
                          style: AptiquTypography.labelCapsBold.copyWith(
                            color: const Color(0xFFFCD34D),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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

          // Hints section (1, 2, or more hints)
          if (q.hints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (q.revealedHintsCount < q.hints.length) {
                        q.revealedHintsCount++;
                      } else {
                        q.revealedHintsCount = 0;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: q.revealedHintsCount > 0
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                          : AptiquColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: q.revealedHintsCount > 0
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                            : AptiquColors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lightbulb_outline_rounded,
                            size: 13, color: Color(0xFFFCD34D)),
                        const SizedBox(width: 4),
                        Text(
                          q.revealedHintsCount == 0
                              ? '💡 Hint (${q.hints.length})'
                              : '💡 Hint ${q.revealedHintsCount}/${q.hints.length}',
                          style: AptiquTypography.labelCapsBold.copyWith(
                            color: const Color(0xFFFCD34D),
                            fontSize: 10,
                          ),
                        ),
                        if (q.revealedHintsCount > 0 &&
                            q.revealedHintsCount < q.hints.length) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(tap for next)',
                            style: AptiquTypography.labelCaps.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (q.revealedHintsCount > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int hIdx = 0; hIdx < q.revealedHintsCount; hIdx++) ...[
                      if (hIdx > 0) const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hint ${hIdx + 1}: ',
                            style: AptiquTypography.bodySm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFCD34D),
                              fontSize: 11.5,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              q.hints[hIdx],
                              style: AptiquTypography.bodySm.copyWith(
                                color: AptiquColors.onSurface,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 14),

          const Divider(color: AptiquColors.outlineVariant, height: 1),
          const SizedBox(height: 12),

          // Dynamic Input Section based on inputType
          _buildInputSection(q),
        ],
      ),
    );
  }

  Color _getDifficultyColor(QuestionDifficultyLevel level) {
    switch (level) {
      case QuestionDifficultyLevel.easy:
        return const Color(0xFF10B981);
      case QuestionDifficultyLevel.medium:
        return const Color(0xFFF59E0B);
      case QuestionDifficultyLevel.hard:
        return const Color(0xFFEF4444);
    }
  }

  bool _isOptionCorrect(QuestionData q, int optIdx) {
    if (!q.hasEvaluated) return false;
    if (q.correctOptionId != null &&
        q.optionIds.isNotEmpty &&
        optIdx < q.optionIds.length) {
      return q.optionIds[optIdx].toLowerCase() ==
          q.correctOptionId!.toLowerCase();
    }
    return q.isUserCorrect == true && q.selectedOptionIndex == optIdx;
  }

  bool _isOptionWrongSelected(QuestionData q, int optIdx) {
    if (!q.hasEvaluated) return false;
    return q.selectedOptionIndex == optIdx && q.isUserCorrect == false;
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
          final isCorrect = _isOptionCorrect(q, idx);
          final isWrongSelected = _isOptionWrongSelected(q, idx);
          final isPrimaryAction = idx == 0;

          Color? bgColor;
          Color borderColor;
          Widget? statusIcon;
          List<BoxShadow>? shadows;

          if (isCorrect) {
            bgColor = const Color(0xFF10B981).withValues(alpha: 0.22);
            borderColor = const Color(0xFF10B981);
            statusIcon = const Icon(Icons.check_circle_rounded,
                color: Color(0xFF10B981), size: 16);
            shadows = [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 10,
              )
            ];
          } else if (isWrongSelected) {
            bgColor = const Color(0xFFEF4444).withValues(alpha: 0.22);
            borderColor = const Color(0xFFEF4444);
            statusIcon = const Icon(Icons.cancel_rounded,
                color: Color(0xFFEF4444), size: 16);
            shadows = [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 10,
              )
            ];
          } else if (isSelected || (isPrimaryAction && !q.isCompleted)) {
            borderColor = AptiquColors.primaryContainer;
            shadows = [
              BoxShadow(
                color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
            ];
          } else {
            bgColor = AptiquColors.surfaceContainer;
            borderColor = AptiquColors.outlineVariant;
          }

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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: (bgColor == null &&
                            (isSelected || (isPrimaryAction && !q.isCompleted)))
                        ? AptiquColors.primaryGradient
                        : null,
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: (isCorrect || isWrongSelected) ? 1.8 : 1.2,
                    ),
                    boxShadow: shadows,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          optionText,
                          textAlign: TextAlign.center,
                          style: AptiquTypography.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: (isCorrect ||
                                    isWrongSelected ||
                                    isSelected ||
                                    (isPrimaryAction && !q.isCompleted))
                                ? Colors.white
                                : AptiquColors.onSurface,
                          ),
                        ),
                      ),
                      if (statusIcon != null) ...[
                        const SizedBox(width: 6),
                        statusIcon,
                      ],
                    ],
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
        final isCorrect = _isOptionCorrect(q, optIdx);
        final isWrongSelected = _isOptionWrongSelected(q, optIdx);

        Color bgColor;
        Color borderColor;
        Color letterBgColor;
        Color letterTextColor;
        Widget? trailingIcon;
        List<BoxShadow>? shadows;

        if (isCorrect) {
          bgColor = const Color(0xFF10B981).withValues(alpha: 0.22);
          borderColor = const Color(0xFF10B981);
          letterBgColor = const Color(0xFF10B981).withValues(alpha: 0.35);
          letterTextColor = const Color(0xFF34D399);
          trailingIcon = const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 17);
          shadows = [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 8,
            )
          ];
        } else if (isWrongSelected) {
          bgColor = const Color(0xFFEF4444).withValues(alpha: 0.22);
          borderColor = const Color(0xFFEF4444);
          letterBgColor = const Color(0xFFEF4444).withValues(alpha: 0.35);
          letterTextColor = const Color(0xFFF87171);
          trailingIcon = const Icon(Icons.cancel_rounded,
              color: Color(0xFFEF4444), size: 17);
          shadows = [
            BoxShadow(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              blurRadius: 8,
            )
          ];
        } else if (isSelected) {
          bgColor = AptiquColors.secondary.withValues(alpha: 0.18);
          borderColor = AptiquColors.secondary;
          letterBgColor = AptiquColors.secondary.withValues(alpha: 0.25);
          letterTextColor = AptiquColors.secondary;
          shadows = AptiquColors.secondaryGlow;
        } else {
          bgColor = AptiquColors.surfaceContainer;
          borderColor = AptiquColors.outlineVariant.withValues(alpha: 0.8);
          letterBgColor = AptiquColors.surfaceContainerHigh;
          letterTextColor = AptiquColors.onSurfaceVariant;
        }

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
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor,
                width: (isCorrect || isWrongSelected || isSelected) ? 1.5 : 1.0,
              ),
              boxShadow: shadows,
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: letterBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    optionLetter,
                    style: AptiquTypography.labelCapsBold.copyWith(
                      fontSize: 10,
                      color: letterTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    optionText,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: AptiquTypography.metricMd.copyWith(
                      fontSize: 13,
                      color: (isSelected || isCorrect || isWrongSelected)
                          ? Colors.white
                          : AptiquColors.onSurface,
                      fontWeight:
                          (isSelected || isCorrect || isWrongSelected)
                              ? FontWeight.w700
                              : FontWeight.w600,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 4),
                  trailingIcon,
                ],
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
