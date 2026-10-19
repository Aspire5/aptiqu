import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/feedback/app_state_view.dart';
import '../../../shared/widgets/layout/text_fit.dart';
import '../../../shared/widgets/tutor_thinking_bubble.dart';
import '../../../shared/widgets/sheets/app_sheet.dart';
import '../controllers/lesson_feed_controller.dart';
import 'widgets/chat_bubble_widget.dart';
import 'widgets/node_renderer_factory.dart';
import 'widgets/doubt_sheet_widget.dart';
import 'widgets/voice_stub_sheet.dart';
import 'widgets/image_stub_dialog.dart';

class LessonFeedScreen extends StatefulWidget {
  final String? slug, roadmapStepId;
  const LessonFeedScreen({super.key, this.slug, this.roadmapStepId});
  @override
  State<LessonFeedScreen> createState() => _LessonFeedScreenState();
}

class _LessonFeedScreenState extends State<LessonFeedScreen> {
  late final LessonFeedController _controller;
  late final String _tag;
  bool _helpOpen = false;
  @override
  void initState() {
    super.initState();
    _tag = 'routed-lesson-${UniqueKey()}';
    _controller = Get.put(LessonFeedController(), tag: _tag);
    _load();
  }

  void _load() => _controller.initLesson(
    scriptSlug: widget.slug,
    roadmapStepId: widget.roadmapStepId,
  );
  @override
  void didUpdateWidget(covariant LessonFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.roadmapStepId != widget.roadmapStepId) {
      _load();
    }
  }

  @override
  void dispose() {
    Get.delete<LessonFeedController>(tag: _tag);
    super.dispose();
  }

  Future<void> _ask(BuildContext context) async {
    if (_helpOpen ||
        _controller.currentNode.value == null ||
        _controller.status.value == FeedStatus.submitting) {
      return;
    }
    _helpOpen = true;
    try {
      await DoubtSheetWidget.show(context, _controller);
    } finally {
      _helpOpen = false;
    }
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _tools(BuildContext context) async {
    final choice = await showAppSheet<String>(
      context: context,
      title: 'Lesson tools',
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.mic_none_rounded),
            title: const Text('Voice · Coming soon'),
            onTap: () => Navigator.of(context).pop('voice'),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Scan work · Coming soon'),
            onTap: () => Navigator.of(context).pop('scan'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (choice == 'voice') {
      await VoiceStubSheet.show(context);
    } else if (choice == 'scan') {
      await ImageStubDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Obx(() {
      final status = _controller.status.value;
      final node = _controller.currentNode.value;
      final canAsk =
          node != null &&
          status != FeedStatus.loading &&
          status != FeedStatus.submitting;
      final compact = !textFits(
        context,
        'Lesson',
        context.type.titleLarge!,
        MediaQuery.sizeOf(context).width - 250,
      );
      Widget ask() => TextButton.icon(
        onPressed: canAsk ? () => _ask(context) : null,
        icon: const Icon(Icons.help_outline_rounded),
        label: const Text('Ask tutor'),
      );
      return Scaffold(
        appBar: AppBar(
          toolbarHeight:
              (MediaQuery.textScalerOf(context).scale(22) * 1.25 + 16).clamp(
                56.0,
                double.infinity,
              ),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => _back(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: compact ? ask() : const Text('Lesson'),
          actions: [
            if (!compact) ask(),
            IconButton(
              tooltip: 'Lesson tools · Coming soon',
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: () => _tools(context),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child:
                  status == FeedStatus.loading || status == FeedStatus.initial
                  ? const SingleChildScrollView(
                      child: AppStateView(
                        title: 'Loading lesson',
                        loading: true,
                      ),
                    )
                  : status == FeedStatus.error && _controller.feedItems.isEmpty
                  ? SingleChildScrollView(
                      child: AppStateView(
                        title: 'Could not load this lesson',
                        message: 'Check your connection and try again.',
                        actionLabel: 'Retry',
                        onAction: _load,
                      ),
                    )
                  : CustomScrollView(
                      controller: _controller.scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (_controller.lessonTitle.value != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                20,
                              ),
                              child: Semantics(
                                header: true,
                                child: Text(
                                  _controller.lessonTitle.value!,
                                  style: context.type.titleLarge,
                                ),
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          sliver: SliverList.builder(
                            itemCount: _controller.feedItems.length,
                            itemBuilder: (context, index) {
                              final item = _controller.feedItems[index];
                              if (item.isThinking) {
                                return const TutorThinkingBubble(
                                  horizontalPadding: 0,
                                );
                              }
                              if (node?.isCompletion == true &&
                                  identical(item.node, node)) {
                                return const SizedBox.shrink();
                              }
                              return ChatBubbleWidget(
                                isUser: item.isUser,
                                text: item.text,
                                avatarPersona:
                                    item.node?.avatarPersona ?? 'TUTOR',
                              );
                            },
                          ),
                        ),
                        if (_controller.errorMessage.value != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _controller.errorMessage.value!,
                                  style: context.type.bodyMedium?.copyWith(
                                    color: context.colors.error,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (node != null)
                          SliverToBoxAdapter(
                            key: const ValueKey('lesson-input'),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: KeyedSubtree(
                                key: ValueKey(
                                  '${_controller.sessionId}:${node.id}',
                                ),
                                child: NodeRendererFactory.buildNodeInput(
                                  node: node,
                                  next: _controller.nextStep.value,
                                  canRetry:
                                      _controller.errorMessage.value != null,
                                  isSubmitting:
                                      status == FeedStatus.submitting ||
                                      status == FeedStatus.completed,
                                  onActionSubmitted:
                                      (
                                        actionType, {
                                        actionId,
                                        answer,
                                        displayText,
                                        responseTimeMs,
                                      }) {
                                        _controller.submitAction(
                                          actionType: actionType,
                                          actionId: actionId,
                                          answer: answer,
                                          userDisplayText: displayText,
                                          responseTimeMs: responseTimeMs,
                                        );
                                      },
                                  onDoubtRequested: () => _ask(context),
                                  onVoiceRequested: () =>
                                      VoiceStubSheet.show(context),
                                ),
                              ),
                            ),
                          ),
                        if (node == null)
                          const SliverToBoxAdapter(
                            child: AppStateView(
                              title: 'No lesson step available',
                              message:
                                  'Return to Home and open the lesson again.',
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }),
  );
}
