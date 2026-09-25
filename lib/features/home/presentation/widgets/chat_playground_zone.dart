import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/background/cyber_ambient_background.dart';
import '../controllers/home_controller.dart';
import 'question_container_widget.dart';

/// ZONE 2: CENTER 76% SECTION - CONVERSATIONAL AI PLAYGROUND
/// The AI naturally leads the conversation and embeds question/input controls
/// directly into the dialogue stream. Persistent buttons are removed.
class ChatPlaygroundZone extends StatelessWidget {
  final double height;

  const ChatPlaygroundZone({
    super.key,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return SizedBox(
      height: height,
      child: CyberAmbientBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          child: Column(
            children: [
              // Quick Launch Live Lesson Banner
              _buildActiveLessonBanner(context),
              const SizedBox(height: 6),

              // Scrollable Chat Messages Area
              Expanded(
                child: Obx(() {
                  return ListView.builder(
                    controller: controller.scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: controller.messages.length,
                    itemBuilder: (context, index) {
                      final msg = controller.messages[index];

                      // 1. Topic Heading Divider
                      if (msg.isTopicDivider) {
                        return _buildTopicDivider(msg.topicTitle ?? 'TOPIC');
                      }

                      // 2. AI Message Bubble
                      if (msg.sender == MessageSender.ai) {
                        return _buildAiMessageItem(context, controller, msg);
                      }

                      // 3. User Message Bubble
                      return _buildUserMessageItem(msg);
                    },
                  );
                }),
              ),

              /*
              // =========================================================================
              // COMMENTED OUT: Persistent floating action dock & textfield
              // As requested: The AI leads the conversation naturally and presents
              // interactions right inside the question container based on expected input.
              // =========================================================================
              _buildAdaptiveActionDock(context, controller),
              const SizedBox(height: 8),
              _buildFloatingInputField(controller),
              */
            ],
          ),
        ),
      ),
    );
  }

  /// Topic Divider acting as a heading with topic name at center
  Widget _buildTopicDivider(String topicTitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AptiquColors.outlineVariant.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AptiquColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AptiquColors.primaryContainer.withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AptiquColors.primaryContainer.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 13,
                    color: AptiquColors.secondary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      topicTitle,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AptiquTypography.labelCapsBold.copyWith(
                        fontSize: 10,
                        color: AptiquColors.secondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AptiquColors.outlineVariant.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// AI Tutor Message Bubble (Left Aligned with Mascot Avatar & AptiQu branding)
  Widget _buildAiMessageItem(
    BuildContext context,
    HomeController controller,
    ChatMessageModel msg,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Mascot Head Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AptiquColors.surface,
              border: Border.all(
                color: AptiquColors.primaryContainer.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AptiquColors.primaryContainer.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: AptiquColors.secondary,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Message & Dynamic Question Container
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text Bubble Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AptiquColors.surfaceContainer.withValues(alpha: 0.95),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(
                      color: AptiquColors.outlineVariant.withValues(alpha: 0.8),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AI Header: Dot + AptiQu Name + Timestamp
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AptiquColors.secondary,
                                  shape: BoxShape.circle,
                                  boxShadow: AptiquColors.secondaryGlow,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AptiQu', // Updated as requested: instead of AERO AI TUTOR
                                style: AptiquTypography.labelCapsBold.copyWith(
                                  fontSize: 10.5,
                                  color: AptiquColors.secondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          Flexible(
                            child: Text(
                              msg.time,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: AptiquTypography.metricSm.copyWith(
                                fontSize: 10,
                                color: AptiquColors.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        msg.text,
                        style: AptiquTypography.bodyMd.copyWith(
                          fontSize: 13.5,
                          height: 1.45,
                          color: AptiquColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Dynamic Interactive Question Container (One unified widget for select, text, voice, scan)
                if (msg.question != null) ...[
                  QuestionContainerWidget(
                    messageId: msg.id,
                    question: msg.question!,
                    controller: controller,
                  ),
                ],

                /*
                // =========================================================================
                // COMMENTED OUT: Old hardcoded speed deduction teaser container
                // =========================================================================
                // _buildOldSpeedDeductionTeaserCard(context, controller, msg),
                */
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// User Message Bubble (Right Aligned, Gradient, No Avatar)
  Widget _buildUserMessageItem(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 40.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AptiquColors.primaryContainer, AptiquColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg.text,
                style: AptiquTypography.bodyMd.copyWith(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.time,
                    style: AptiquTypography.metricSm.copyWith(
                      color: AptiquColors.primary.withValues(alpha: 0.8),
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.done_all_rounded,
                    size: 13,
                    color: AptiquColors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sleek, responsive quick-launch banner for active AI Tutor lesson
  Widget _buildActiveLessonBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AptiquColors.primaryContainer.withValues(alpha: 0.7),
          width: 1.2,
        ),
        boxShadow: AptiquColors.primaryGlow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AptiquColors.primaryContainer.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: AptiquColors.secondary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI TUTOR READY',
                      style: AptiquTypography.labelCapsBold.copyWith(
                        fontSize: 9,
                        color: Colors.greenAccent,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Ratio & Proportion 101 • 15 min',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AptiquTypography.bodySm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => context.push('/lesson/math_ratios_101'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: AptiquColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Start',
                    style: AptiquTypography.labelCapsBold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
