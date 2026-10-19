import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/shared/widgets/tutor_thinking_bubble.dart';
import '../controllers/home_controller.dart';
import 'question_container_widget.dart';

/// The existing embedded conversation, with reading-focused pilot presentation.
class ChatPlaygroundZone extends StatelessWidget {
  final double height;
  const ChatPlaygroundZone({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();
    return Obx(() {
      final title = controller.activeScriptTitle.value;
      final lessonTitle = title.isNotEmpty && title != 'Playing'
          ? title
          : controller.currentSession.value?.scriptTitle ?? 'Lesson';
      final fullscreen = controller.isFullScreen.value;
      final compact = height < 240 * MediaQuery.textScalerOf(context).scale(1);
      return SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!compact && lessonTitle != 'Lesson')
                                Text(
                                  'Lesson',
                                  style: context.type.labelMedium!.copyWith(
                                    color: context.colors.primary,
                                  ),
                                ),
                              Text(
                                compact ? 'Lesson' : lessonTitle,
                                style: context.type.titleMedium,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: fullscreen
                              ? 'Exit fullscreen lesson'
                              : 'Fullscreen lesson',
                          onPressed: controller.toggleFullScreen,
                          icon: Icon(
                            fullscreen
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close lesson',
                          onPressed: controller.exitToHome,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        key: const ValueKey('embedded-conversation'),
                        controller: controller.scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        // A stable title slot keeps message indexes unchanged when
                        // fullscreen or text scaling changes the header layout.
                        itemCount: controller.messages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return compact && lessonTitle != 'Lesson'
                                ? Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        lessonTitle,
                                        style: context.type.titleMedium,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          }
                          final messageIndex = index - 1;
                          final msg = controller.messages[messageIndex];
                          if (msg.isTopicDivider) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                msg.topicTitle ?? 'Topic',
                                style: context.type.titleMedium,
                              ),
                            );
                          }
                          final targeted =
                              msg.id == controller.targetedMessageId ||
                              (controller.targetedMessageId == null &&
                                  messageIndex ==
                                      controller.messages.length - 1);
                          return KeyedSubtree(
                            key: msg.sender == MessageSender.ai && targeted
                                ? controller.latestAiMessageKey
                                : ValueKey(msg.id),
                            child: msg.sender == MessageSender.ai
                                ? _ai(context, controller, msg)
                                : _user(context, msg),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _ai(
    BuildContext context,
    HomeController controller,
    ChatMessageModel msg,
  ) {
    if (msg.isThinking) return const TutorThinkingBubble(horizontalPadding: 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      size: 18,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AptiQu',
                      style: context.type.labelMedium!.copyWith(
                        color: context.colors.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      msg.time,
                      style: context.type.bodySmall!.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(msg.text, style: context.type.bodyLarge),
                if (msg.hasContinueAction && !msg.isContinueCompleted) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: controller.isSubmittingAction.value
                          ? null
                          : () => controller.handleContinueAction(msg.id),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: const Text('Continue'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (msg.question != null)
            QuestionContainerWidget(
              messageId: msg.id,
              question: msg.question!,
              controller: controller,
            ),
        ],
      ),
    );
  }

  Widget _user(BuildContext context, ChatMessageModel msg) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 32),
    child: Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.primaryContainer,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              msg.text,
              style: context.type.bodyLarge!.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: context.type.bodySmall!.copyWith(
                color: context.colors.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
