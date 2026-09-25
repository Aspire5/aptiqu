import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../controllers/lesson_feed_controller.dart';
import 'widgets/chat_bubble_widget.dart';
import 'widgets/node_renderer_factory.dart';
import 'widgets/doubt_sheet_widget.dart';
import 'widgets/voice_stub_sheet.dart';
import 'widgets/image_stub_dialog.dart';

class LessonFeedScreen extends StatefulWidget {
  final String? slug;
  final String? roadmapStepId;

  const LessonFeedScreen({
    super.key,
    this.slug,
    this.roadmapStepId,
  });

  @override
  State<LessonFeedScreen> createState() => _LessonFeedScreenState();
}

class _LessonFeedScreenState extends State<LessonFeedScreen> {
  late final LessonFeedController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(LessonFeedController());
    _controller.initLesson(
      scriptSlug: widget.slug,
      roadmapStepId: widget.roadmapStepId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      appBar: AppBar(
        backgroundColor: AptiquColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AptiquColors.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interactive AI Tutor',
              style: AptiquTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              (widget.slug ?? widget.roadmapStepId ?? 'Lesson')
                  .replaceAll('_', ' ')
                  .replaceAll('-', ' ')
                  .toUpperCase(),
              style: AptiquTypography.labelCaps.copyWith(
                color: AptiquColors.secondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: AptiquColors.onSurfaceVariant),
            tooltip: 'Scan Work',
            onPressed: () => ImageStubDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none, color: AptiquColors.onSurfaceVariant),
            tooltip: 'Voice Input',
            onPressed: () => VoiceStubSheet.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AptiquColors.tertiary),
            tooltip: 'Ask Doubt',
            onPressed: () => DoubtSheetWidget.show(context, _controller),
          ),
        ],
      ),
      body: Obx(() {
        final status = _controller.status.value;

        if (status == FeedStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: AptiquColors.primary),
          );
        }

        if (status == FeedStatus.error && _controller.feedItems.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _controller.errorMessage.value ?? 'An error occurred.',
                    textAlign: TextAlign.center,
                    style: AptiquTypography.bodyLg.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _controller.initLesson(
                      scriptSlug: widget.slug,
                      roadmapStepId: widget.roadmapStepId,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final currentNode = _controller.currentNode.value;

        return Column(
          children: [
            // Chat feed list
            Expanded(
              child: ListView.builder(
                controller: _controller.scrollController,
                padding: const EdgeInsets.only(top: 12, bottom: 20),
                itemCount: _controller.feedItems.length,
                itemBuilder: (context, index) {
                  final item = _controller.feedItems[index];
                  return ChatBubbleWidget(
                    isUser: item.isUser,
                    text: item.text,
                    avatarPersona: item.node?.avatarPersona ?? 'TUTOR',
                  );
                },
              ),
            ),

            // Active Interactive Input Area
            if (currentNode != null && status != FeedStatus.completed)
              SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: AptiquColors.surface,
                    border: Border(
                      top: BorderSide(color: AptiquColors.outlineVariant),
                    ),
                  ),
                  child: NodeRendererFactory.buildNodeInput(
                    node: currentNode,
                    isSubmitting: status == FeedStatus.submitting,
                    onActionSubmitted: (actionType, {actionId, answer, displayText, responseTimeMs}) {
                      _controller.submitAction(
                        actionType: actionType,
                        actionId: actionId,
                        answer: answer,
                        userDisplayText: displayText,
                        responseTimeMs: responseTimeMs,
                      );
                    },
                    onDoubtRequested: () => DoubtSheetWidget.show(context, _controller),
                    onVoiceRequested: () => VoiceStubSheet.show(context),
                  ),
                ),
              ),

            if (status == FeedStatus.completed && currentNode != null)
              SafeArea(
                top: false,
                child: NodeRendererFactory.buildNodeInput(
                  node: currentNode,
                  onActionSubmitted: (_, {actionId, answer, displayText, responseTimeMs}) {},
                  onDoubtRequested: () {},
                  onVoiceRequested: () {},
                ),
              ),
          ],
        );
      }),
    );
  }
}
