import 'package:flutter/material.dart';
import '../../models/lesson_node_model.dart';
import 'content_node_widget.dart';
import 'choice_input_widget.dart';
import 'question_node_widget.dart';
import 'text_input_widget.dart';
import 'completion_node_widget.dart';

class NodeRendererFactory {
  static Widget buildNodeInput({
    required LessonNodeModel node,
    required Function(String actionType, {String? actionId, String? answer, String? displayText, int? responseTimeMs}) onActionSubmitted,
    required VoidCallback onDoubtRequested,
    required VoidCallback onVoiceRequested,
    bool isSubmitting = false,
  }) {
    switch (node.type) {
      case 'CONTENT':
        return ContentNodeWidget(
          node: node,
          isSubmitting: isSubmitting,
          onAction: (optId, label) => onActionSubmitted(
            'CHOICE',
            actionId: optId,
            displayText: label,
          ),
          onDoubt: onDoubtRequested,
        );

      case 'CHOICE':
        return ChoiceInputWidget(
          node: node,
          isSubmitting: isSubmitting,
          onSelect: (optId, label) => onActionSubmitted(
            'CHOICE',
            actionId: optId,
            displayText: label,
          ),
        );

      case 'QUESTION':
        return QuestionNodeWidget(
          node: node,
          isSubmitting: isSubmitting,
          onAnswerSubmitted: (ansId, label, responseTimeMs) => onActionSubmitted(
            'QUESTION_ANSWER',
            answer: ansId,
            displayText: label,
            responseTimeMs: responseTimeMs,
          ),
          onDoubt: onDoubtRequested,
        );

      case 'TEXT_INPUT':
        return TextInputWidget(
          node: node,
          isSubmitting: isSubmitting,
          onSubmit: (text) => onActionSubmitted(
            'TEXT_SUBMISSION',
            answer: text,
            displayText: text,
          ),
          onVoiceTap: onVoiceRequested,
        );

      case 'COMPLETION':
        return CompletionNodeWidget(node: node);

      default:
        return const SizedBox.shrink();
    }
  }
}
