import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import '../../models/roadmap_model.dart';
import '../controllers/home_controller.dart';
import 'topic_details_sheet.dart';
import 'topic_icon.dart';
import '../../../../shared/widgets/sheets/app_sheet.dart';
import '../../../practice/controllers/practice_catalog_controller.dart';

/// Existing curriculum canvas with theme-aware pilot styling.
/// Layout, topic state, sheet selection and lesson/practice callbacks stay local.
class ConstellationRoadmapView extends StatefulWidget {
  final SubjectLearningMapModel learningMap;
  final List<RoadmapSubjectSummary> subjects;
  final String selectedSubjectId;
  final ValueChanged<String> onSelectSubject;
  final ValueChanged<LearningMapTopicItemModel> onTopicTap;
  final Future<void> Function() onRefresh;
  final int cameraTrigger;
  final bool isFullScreen;
  final VoidCallback onToggleFullScreen;

  const ConstellationRoadmapView({
    super.key,
    required this.learningMap,
    required this.subjects,
    required this.selectedSubjectId,
    required this.onSelectSubject,
    required this.onTopicTap,
    required this.onRefresh,
    this.cameraTrigger = 0,
    this.isFullScreen = false,
    required this.onToggleFullScreen,
  });

  @override
  State<ConstellationRoadmapView> createState() =>
      _ConstellationRoadmapViewState();
}

class _ConstellationRoadmapViewState extends State<ConstellationRoadmapView>
    with TickerProviderStateMixin {
  // Canvas vertical metrics
  double get nodeSpacing =>
      190.0 + (MediaQuery.textScalerOf(context).scale(40) - 40);
  static const double topPadding = 100.0;
  static const double bottomPadding = 450.0;

  // Zoom and Pan controller
  late TransformationController _transformationController;
  late AnimationController _cameraAnimationController;
  Animation<Matrix4>? _cameraAnimation;

  // Inspected topic and live state for the modal bottom sheet.
  LearningMapTopicItemModel? _inspectedTopic;
  bool _isTopicSheetOpen = false;
  bool? _showList;
  final _sheetTopic = ValueNotifier<LearningMapTopicItemModel?>(null);

  // Viewport cached size
  Size _viewportSize = Size.zero;
  bool _hasInitialZoomAnimated = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    // Default inspected topic without opening the sheet
    _inspectedTopic = _getActiveOrFirstTopic();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    TopicIcon.precacheIcons(context);
  }

  @override
  void didUpdateWidget(covariant ConstellationRoadmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_inspectedTopic != null) {
      final updated = widget.learningMap.topics.firstWhereOrNull(
        (t) => t.roadmapStepId == _inspectedTopic!.roadmapStepId,
      );
      _inspectedTopic = updated ?? _getActiveOrFirstTopic();
    } else {
      _inspectedTopic = _getActiveOrFirstTopic();
    }

    if (_isTopicSheetOpen) {
      final updated =
          oldWidget.learningMap.subjectId == widget.learningMap.subjectId
          ? widget.learningMap.topics.firstWhereOrNull(
              (t) => t.roadmapStepId == _sheetTopic.value?.roadmapStepId,
            )
          : null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isTopicSheetOpen) _sheetTopic.value = updated;
      });
    }

    if (oldWidget.learningMap.subjectId != widget.learningMap.subjectId ||
        oldWidget.cameraTrigger != widget.cameraTrigger) {
      _inspectedTopic = _getActiveOrFirstTopic();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateCameraToActiveNode();
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _cameraAnimationController.dispose();
    _sheetTopic.dispose();
    super.dispose();
  }

  LearningMapTopicItemModel _getActiveOrFirstTopic() {
    final topics = widget.learningMap.topics;
    if (topics.isEmpty) {
      return LearningMapTopicItemModel(
        roadmapStepId: '',
        sequence: 1,
        topicId: '',
        topicName: 'Curriculum',
        topicSlug: '',
        importance: 'medium',
        teachingMinutes: 30,
        teachingDepth: 3,
        state: 'AVAILABLE',
        scriptAvailable: false,
      );
    }

    return widget.learningMap.focusTopic ?? topics.first;
  }

  int _getActiveTopicIndex() {
    final active = _getActiveOrFirstTopic();
    final index = widget.learningMap.topics.indexOf(active);
    return widget.learningMap.focusTopic == null ? -1 : index;
  }

  /// Calculates node position (x, y) on the canvas using a winding S-curve
  Offset _getNodePosition(int index, int total, double canvasWidth) {
    final y = topPadding + (index * nodeSpacing);

    // Boss gates or first/last nodes are centered
    final isBossGate = (index + 1) % 10 == 0 || index == total - 1;
    if (index == 0 || isBossGate) {
      return Offset(canvasWidth * 0.50, y);
    }

    // Serpentine winding pattern: Center -> Right -> Center -> Left
    final pattern = index % 4;
    double xFraction;
    switch (pattern) {
      case 1:
        xFraction = 0.76; // Right
        break;
      case 2:
        xFraction = 0.50; // Center
        break;
      case 3:
        xFraction = 0.24; // Left
        break;
      default:
        xFraction = 0.50;
    }
    return Offset(canvasWidth * xFraction, y);
  }

  /// Creates a clean 2D Transformation Matrix (translation + scale) without deprecated APIs
  Matrix4 _buildMatrix2D({
    required double tx,
    required double ty,
    required double scale,
  }) {
    final m = Matrix4.identity();
    m.setEntry(0, 0, scale);
    m.setEntry(1, 1, scale);
    m.setEntry(0, 3, tx);
    m.setEntry(1, 3, ty);
    return m;
  }

  /// Triggers smooth cinematic zoom-in camera animation from zoomed-out to the target node
  void _animateCameraToActiveNode({bool instant = false}) {
    if (!mounted ||
        _viewportSize == Size.zero ||
        widget.learningMap.topics.isEmpty) {
      return;
    }

    final canvasWidth = max(_viewportSize.width, 420.0);
    final targetIndex = max(0, _getActiveTopicIndex());
    final targetOffset = _getNodePosition(
      targetIndex,
      widget.learningMap.topics.length,
      canvasWidth,
    );

    const double targetScale = 1.05;
    const double startScale = 0.52;

    // Viewport center target
    final double targetViewportX = _viewportSize.width / 2;
    final double targetViewportY = _viewportSize.height * 0.28;

    // End matrix focused on active node
    final Matrix4 endMatrix = _buildMatrix2D(
      tx: targetViewportX - (targetOffset.dx * targetScale),
      ty: targetViewportY - (targetOffset.dy * targetScale),
      scale: targetScale,
    );

    _hasInitialZoomAnimated = true;
    if (instant || MediaQuery.disableAnimationsOf(context)) {
      _transformationController.value = endMatrix;
      return;
    }

    // Start matrix: zoomed out centered overview
    final Matrix4 startMatrix = _buildMatrix2D(
      tx: targetViewportX - (canvasWidth * 0.50 * startScale),
      ty: targetViewportY - (targetOffset.dy * startScale),
      scale: startScale,
    );

    _transformationController.value = startMatrix;

    _cameraAnimation = Matrix4Tween(begin: startMatrix, end: endMatrix).animate(
      CurvedAnimation(
        parent: _cameraAnimationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _cameraAnimationController.reset();
    _cameraAnimationController.forward();
    _hasInitialZoomAnimated = true;
  }

  /// Pan camera smoothly to a tapped node
  void _panCameraToNode(int index) {
    if (_viewportSize == Size.zero) return;

    final canvasWidth = max(_viewportSize.width, 420.0);
    final targetOffset = _getNodePosition(
      index,
      widget.learningMap.topics.length,
      canvasWidth,
    );
    final double currentScale = _transformationController.value
        .getMaxScaleOnAxis()
        .clamp(0.8, 1.4);

    final double targetViewportX = _viewportSize.width / 2;
    final double targetViewportY = _viewportSize.height * 0.42;

    final Matrix4 targetMatrix = _buildMatrix2D(
      tx: targetViewportX - (targetOffset.dx * currentScale),
      ty: targetViewportY - (targetOffset.dy * currentScale),
      scale: currentScale,
    );

    if (MediaQuery.disableAnimationsOf(context)) {
      _transformationController.value = targetMatrix;
      return;
    }
    _cameraAnimation =
        Matrix4Tween(
          begin: _transformationController.value,
          end: targetMatrix,
        ).animate(
          CurvedAnimation(
            parent: _cameraAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _cameraAnimationController.reset();
    _cameraAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.learningMap.topics;
    final totalTopics = topics.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final list =
            _showList ??
            (constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(14) > 18);

        final canvasWidth = max(constraints.maxWidth, 420.0);
        final canvasHeight =
            topPadding + (totalTopics * nodeSpacing) + bottomPadding;

        if (!_hasInitialZoomAnimated && totalTopics > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animateCameraToActiveNode();
          });
        }

        // Build list of node coordinates
        final List<Offset> nodePositions = List.generate(
          totalTopics,
          (i) => _getNodePosition(i, totalTopics, canvasWidth),
        );

        final activeIndex = _getActiveTopicIndex();

        return Column(
          children: [
            // 1. FIXED MINIMAL NON-TRANSPARENT SUBJECTS BAR (Slides up in fullscreen)
            _buildAnimatedFixedSubjectsBar(),
            if (!widget.isFullScreen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.map_outlined),
                        label: Text('Map'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.format_list_bulleted),
                        label: Text('List'),
                      ),
                    ],
                    selected: {list},
                    onSelectionChanged: (values) =>
                        setState(() => _showList = values.single),
                  ),
                ),
              ),
            if (list)
              Expanded(child: _buildTopicList(topics))
            else
              // 2. EXPANDED ZOOMABLE & PANNABLE MAP CANVAS
              Expanded(
                child: Stack(
                  children: [
                    // Full interactive viewer (unconstrained gives full freedom to scroll entire height)
                    AnimatedBuilder(
                      animation: _cameraAnimationController,
                      builder: (context, child) {
                        if (_cameraAnimation != null &&
                            _cameraAnimationController.isAnimating) {
                          _transformationController.value =
                              _cameraAnimation!.value;
                        }
                        return child!;
                      },
                      child: InteractiveViewer(
                        transformationController: _transformationController,
                        constrained:
                            false, // COMPLETE SCROLL FREEDOM ALL THE WAY DOWN
                        minScale: 0.35,
                        maxScale: 2.2,
                        boundaryMargin: const EdgeInsets.symmetric(
                          horizontal: 200,
                          vertical: 800,
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          child: SizedBox(
                            width: canvasWidth,
                            height: canvasHeight,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Curriculum path using resolved theme colors.
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _ConstellationPathPainter(
                                      nodePositions: nodePositions,
                                      track: context.colors.outlineVariant,
                                      progress: context.status.success,
                                      completedNodeIndices: {
                                        for (var i = 0; i < topics.length; i++)
                                          if (topics[i].isCompleted) i,
                                      },
                                    ),
                                  ),
                                ),

                                // Topic Nodes Along the Winding S-Curve
                                for (int i = 0; i < totalTopics; i++)
                                  _buildNodeItem(
                                    topic: topics[i],
                                    index: i,
                                    position: nodePositions[i],
                                    isActiveFocus: i == activeIndex,
                                    isInspected:
                                        _inspectedTopic?.roadmapStepId ==
                                        topics[i].roadmapStepId,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. FLOATING HUD CONTROLS (Fullscreen, Re-center, Zoom In, Zoom Out)
                    Positioned(
                      right: 16,
                      bottom: 16 + MediaQuery.paddingOf(context).bottom,
                      child: _buildHudControls(
                        horizontal: constraints.maxHeight < 520,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // FIXED MINIMAL SUBJECTS SELECTION BAR
  // ===========================================================================

  Widget _buildAnimatedFixedSubjectsBar() =>
      widget.isFullScreen ? const SizedBox.shrink() : _buildFixedSubjectsBar();

  Widget _buildFixedSubjectsBar() => Material(
    color: context.colors.surface,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final subject in widget.subjects)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: subject.id == widget.selectedSubjectId,
                showCheckmark: true,
                label: Text(
                  '${subject.name} · ${subject.id == widget.selectedSubjectId ? widget.learningMap.completedTopics : subject.completedTopics}/${subject.id == widget.selectedSubjectId ? widget.learningMap.totalTopics : subject.totalTopics} topics',
                ),
                labelStyle: context.type.labelMedium!.copyWith(
                  color: subject.id == widget.selectedSubjectId
                      ? context.colors.onPrimaryContainer
                      : context.colors.onSurface,
                ),
                onSelected: (_) => widget.onSelectSubject(subject.id),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildTopicList(
    List<LearningMapTopicItemModel> topics,
  ) => ListView.separated(
    key: PageStorageKey('topics-list-${widget.selectedSubjectId}'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    itemCount: topics.length,
    separatorBuilder: (_, __) => const SizedBox(height: 12),
    itemBuilder: (context, index) {
      final topic = topics[index];
      final focus =
          topic.roadmapStepId == widget.learningMap.focusTopic?.roadmapStepId;
      final state = topic.isCompleted
          ? 'Completed · Replay'
          : topic.isComingSoon
          ? 'Coming soon'
          : topic.isLocked
          ? 'Locked'
          : topic.isInProgress
          ? 'In progress'
          : 'Ready to learn';
      return Semantics(
        sortKey: OrdinalSortKey(index.toDouble()),
        child: Material(
          color: focus
              ? context.colors.primaryContainer
              : context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: focus
                ? const TopicIcon(type: TopicIconType.currentTopic, size: 40)
                : topic.isCompleted
                ? Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      const TopicIcon(type: TopicIconType.topic, size: 40),
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 15,
                          height: 15,
                          decoration: BoxDecoration(
                            color: context.status.success,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 9,
                            color: context.colors.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                : (topic.isComingSoon || topic.isLocked)
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      const Opacity(
                        opacity: 0.35,
                        child: TopicIcon(type: TopicIconType.topic, size: 40),
                      ),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: context.colors.surface.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          topic.isComingSoon
                              ? Icons.schedule_rounded
                              : Icons.lock_outline_rounded,
                          size: 12,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : const TopicIcon(type: TopicIconType.topic, size: 40),
            title: Text(
              topic.topicName,
              style: context.type.titleSmall!.copyWith(
                color: focus
                    ? context.colors.onPrimaryContainer
                    : context.colors.onSurface,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${focus ? 'Current topic · ' : ''}$state\n${topic.completedSubtopics} of ${topic.totalSubtopics} subtopics completed',
                style: context.type.bodyMedium!.copyWith(
                  color: focus
                      ? context.colors.onPrimaryContainer
                      : context.colors.onSurfaceVariant,
                ),
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              setState(() => _inspectedTopic = topic);
              _openTopicSheet(topic);
            },
          ),
        ),
      );
    },
  );

  // ===========================================================================
  // NODE WIDGETS
  // ===========================================================================

  Widget _buildNodeItem({
    required LearningMapTopicItemModel topic,
    required int index,
    required Offset position,
    required bool isActiveFocus,
    required bool isInspected,
  }) {
    void inspect() {
      setState(() => _inspectedTopic = topic);
      _panCameraToNode(index);
      _openTopicSheet(topic);
    }

    return Positioned(
      left: position.dx - 130,
      top: position.dy - 55,
      width: 260,
      child: Semantics(
        button: true,
        excludeSemantics: true,
        onTap: inspect,
        sortKey: OrdinalSortKey(index.toDouble()),
        label:
            '${topic.topicName}. ${topic.state.toLowerCase().replaceAll('_', ' ')}. ${topic.completedSubtopics} of ${topic.totalSubtopics} subtopics completed. Open topic details.',
        child: InkWell(
          onTap: inspect,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Active Focus Tag Banner
              if (isActiveFocus)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 12,
                        color: context.colors.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'CURRENT TOPIC',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.type.labelMedium!.copyWith(
                            color: context.colors.onPrimaryContainer,
                            fontSize: 12,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Node Circle
              if (isActiveFocus)
                _buildActiveFocusNodeCircle(topic)
              else if (topic.isCompleted)
                _buildCompletedNodeCircle(topic, isInspected)
              else if (topic.isAvailable || topic.isInProgress)
                _buildReadyNodeCircle(topic, isInspected)
              else
                _buildLockedNodeCircle(topic, isInspected),

              const SizedBox(height: 6),

              // Subtopics Progress Pill (e.g. 0/8 or 3/8)
              _buildSubtopicsProgressPill(topic),

              const SizedBox(height: 2),

              // Node Title
              Text(
                topic.topicName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.type.titleSmall!.copyWith(
                  fontSize: 16,
                  fontWeight: isActiveFocus ? FontWeight.w800 : FontWeight.w600,
                  color: isActiveFocus
                      ? context.colors.primary
                      : isInspected
                      ? context.colors.onSurface
                      : context.colors.onSurface,
                ),
              ),

              const SizedBox(height: 2),

              // Status Badge Pill
              _buildNodeStatusBadge(topic, isActiveFocus),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFocusNodeCircle(LearningMapTopicItemModel topic) =>
      const TopicIcon(
        type: TopicIconType.currentTopic,
        size: 64,
      );

  Widget _buildCompletedNodeCircle(
    LearningMapTopicItemModel topic,
    bool inspected,
  ) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      const TopicIcon(type: TopicIconType.topic, size: 54),
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: context.status.success,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.surface, width: 2),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 11,
            color: context.colors.onPrimary,
          ),
        ),
      ),
    ],
  );

  Widget _buildReadyNodeCircle(
    LearningMapTopicItemModel topic,
    bool inspected,
  ) => const TopicIcon(
    type: TopicIconType.topic,
    size: 54,
  );

  Widget _buildLockedNodeCircle(
    LearningMapTopicItemModel topic,
    bool inspected,
  ) => Stack(
    alignment: Alignment.center,
    children: [
      const Opacity(
        opacity: 0.35,
        child: TopicIcon(type: TopicIconType.topic, size: 54),
      ),
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.85),
          shape: BoxShape.circle,
        ),
        child: Icon(
          topic.isComingSoon
              ? Icons.schedule_rounded
              : Icons.lock_outline_rounded,
          size: 15,
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );

  Widget _buildSubtopicsProgressPill(LearningMapTopicItemModel topic) {
    final total = topic.totalSubtopics;
    final done = topic.completedSubtopics;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: topic.isCompleted
              ? context.colors.secondary.withValues(alpha: 0.6)
              : context.colors.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        total == 0 ? 'Coming soon' : '$done/$total completed',
        style: context.type.labelMedium!.copyWith(
          fontSize: 12,
          color: topic.isCompleted
              ? context.colors.secondary
              : (done > 0
                    ? context.colors.onSurface
                    : context.colors.onSurfaceVariant),
          letterSpacing: 0,
        ),
      ),
    );
  }

  Widget _buildNodeStatusBadge(
    LearningMapTopicItemModel topic,
    bool isActiveFocus,
  ) {
    if (isActiveFocus) {
      return Text(
        topic.isCompleted
            ? 'COMPLETED · REPLAY'
            : topic.isInProgress || topic.completedSubtopics > 0
            ? 'CONTINUE TOPIC'
            : 'START TOPIC',
        style: context.type.labelMedium!.copyWith(
          color: context.colors.secondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      );
    }

    if (topic.isCompleted) {
      return Text(
        'COMPLETE',
        style: context.type.labelMedium!.copyWith(
          color: context.colors.secondary,
          fontSize: 12,
        ),
      );
    }

    if (topic.isInProgress) {
      return Text(
        'IN PROGRESS',
        style: context.type.labelMedium!.copyWith(
          color: context.colors.primary,
          fontSize: 12,
        ),
      );
    }

    if (topic.isAvailable) {
      return Text(
        'UNLOCKED',
        style: context.type.labelMedium!.copyWith(
          color: context.colors.onSurfaceVariant,
          fontSize: 12,
        ),
      );
    }

    return Text(
      'COMING SOON',
      style: context.type.labelMedium!.copyWith(
        color: context.colors.onSurfaceVariant,
        fontSize: 12,
      ),
    );
  }

  // ===========================================================================
  // MAP CONTROLS (Fullscreen, Re-center, Zoom In, Zoom Out)
  // ===========================================================================

  Widget _buildHudControls({bool horizontal = false}) {
    return Flex(
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Fullscreen Toggle Button
        FloatingActionButton(
          heroTag: 'fullscreen_toggle_map',
          backgroundColor: widget.isFullScreen
              ? context.colors.primaryContainer
              : context.colors.surfaceContainerHigh,
          foregroundColor: widget.isFullScreen
              ? context.colors.onSurface
              : context.colors.secondary,
          elevation: 0,
          shape: CircleBorder(
            side: BorderSide(
              color: widget.isFullScreen
                  ? context.colors.primary
                  : context.colors.outlineVariant,
            ),
          ),
          onPressed: widget.onToggleFullScreen,
          tooltip: widget.isFullScreen ? 'Exit Fullscreen' : 'Fullscreen Map',
          child: Icon(
            widget.isFullScreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            size: 20,
          ),
        ),
        SizedBox(height: horizontal ? 0 : 8, width: horizontal ? 8 : 0),

        // 2. Re-center Target Button
        FloatingActionButton(
          heroTag: 'recenter_node',
          backgroundColor: context.colors.surfaceContainerHigh,
          foregroundColor: context.colors.primary,
          elevation: 0,
          shape: CircleBorder(
            side: BorderSide(color: context.colors.outlineVariant),
          ),
          onPressed: () {
            final active = _getActiveOrFirstTopic();
            setState(() {
              _inspectedTopic = active;
            });
            _animateCameraToActiveNode();
            if (widget.learningMap.focusTopic != null) _openTopicSheet(active);
          },
          tooltip: 'Focus Active Level',
          child: Icon(Icons.my_location_rounded, size: 19),
        ),
        SizedBox(height: horizontal ? 0 : 8, width: horizontal ? 8 : 0),

        // 3. Zoom In
        FloatingActionButton(
          heroTag: 'zoom_in_map',
          backgroundColor: context.colors.surfaceContainerHigh,
          foregroundColor: context.colors.onSurface,
          elevation: 0,
          shape: CircleBorder(
            side: BorderSide(color: context.colors.outlineVariant),
          ),
          onPressed: () => _zoom(1.25),
          tooltip: 'Zoom In',
          child: Icon(Icons.add, size: 18),
        ),
        SizedBox(height: horizontal ? 0 : 8, width: horizontal ? 8 : 0),

        // 4. Zoom Out
        FloatingActionButton(
          heroTag: 'zoom_out_map',
          backgroundColor: context.colors.surfaceContainerHigh,
          foregroundColor: context.colors.onSurface,
          elevation: 0,
          shape: CircleBorder(
            side: BorderSide(color: context.colors.outlineVariant),
          ),
          onPressed: () => _zoom(.8),
          tooltip: 'Zoom Out',
          child: Icon(Icons.remove, size: 18),
        ),
      ],
    );
  }

  // ===========================================================================
  // TOPIC DETAILS BOTTOM SHEET
  // ===========================================================================

  void _zoom(double factor) {
    final current = _transformationController.value;
    final scale = current.getMaxScaleOnAxis();
    final target = (scale * factor).clamp(.35, 2.2);
    _cameraAnimationController.stop();
    _transformationController.value = Matrix4.copy(current)
      ..multiply(Matrix4.diagonal3Values(target / scale, target / scale, 1));
  }

  Future<void> _openTopicSheet(LearningMapTopicItemModel topic) async {
    if (_isTopicSheetOpen || !mounted) return;
    final subjectId = widget.selectedSubjectId;
    _isTopicSheetOpen = true;
    _sheetTopic.value = topic;
    final selection = await showModalBottomSheet<_TopicSheetSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (sheetContext) => AppSheetSurface(
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: .78,
          minChildSize: .4,
          maxChildSize: .94,
          builder: (_, scrollController) =>
              ValueListenableBuilder<LearningMapTopicItemModel?>(
                valueListenable: _sheetTopic,
                builder: (_, current, __) => current == null
                    ? Center(child: Text('This topic is no longer available.'))
                    : TopicDetailsSheet(
                        topic: current,
                        scrollController: scrollController,
                        onPracticeTopic: () => Navigator.of(
                          sheetContext,
                        ).pop(const _TopicSheetSelection(practice: true)),
                        onPlayTopic: () => Navigator.of(
                          sheetContext,
                        ).pop(const _TopicSheetSelection(practice: false)),
                        onPracticeSubtopic: (subtopic) =>
                            Navigator.of(sheetContext).pop(
                              _TopicSheetSelection(
                                practice: true,
                                subtopicId: subtopic.id,
                              ),
                            ),
                        onPlaySubtopic: (subtopic) =>
                            Navigator.of(sheetContext).pop(
                              _TopicSheetSelection(
                                practice: false,
                                subtopicId: subtopic.id,
                              ),
                            ),
                      ),
              ),
        ),
      ),
    );
    _isTopicSheetOpen = false;
    if (!mounted ||
        selection == null ||
        widget.selectedSubjectId != subjectId) {
      return;
    }
    final current = _sheetTopic.value;
    if (current == null) return;
    final subtopic = current.subtopics.firstWhereOrNull(
      (st) => st.id == selection.subtopicId,
    );
    if (selection.subtopicId != null && subtopic == null) return;
    if (selection.practice) {
      final practiceController = Get.isRegistered<PracticeCatalogController>()
          ? Get.find<PracticeCatalogController>()
          : Get.put(PracticeCatalogController());
      practiceController.startPracticeSessionForTopic(
        subjectId: subjectId,
        topicId: current.topicId,
        subtopicIds: subtopic == null ? null : [subtopic.id],
      );
    } else if (subtopic != null) {
      if (subtopic.isLocked) return;
      Get.find<HomeController>().startSubtopicLesson(
        roadmapStepId: current.roadmapStepId,
        scriptSlug: subtopic.scriptSlug?.isNotEmpty == true
            ? subtopic.scriptSlug
            : subtopic.id,
        scriptTitle: subtopic.title,
        restart: subtopic.isCompleted,
      );
    } else if (current.scriptAvailable &&
        !current.isLocked &&
        !current.isComingSoon) {
      widget.onTopicTap(current);
    }
  }
}

class _TopicSheetSelection {
  final bool practice;
  final String? subtopicId;
  const _TopicSheetSelection({required this.practice, this.subtopicId});
}

// =============================================================================
// CUSTOM PAINTER: CURRICULUM PATH
// =============================================================================

class _ConstellationPathPainter extends CustomPainter {
  final List<Offset> nodePositions;
  final Set<int> completedNodeIndices;
  final Color track, progress;

  _ConstellationPathPainter({
    required this.nodePositions,
    required this.track,
    required this.progress,
    required this.completedNodeIndices,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;

    // 2. Build full winding serpentine path
    final fullPath = Path();
    fullPath.moveTo(nodePositions.first.dx, nodePositions.first.dy);

    for (int i = 0; i < nodePositions.length - 1; i++) {
      final p0 = nodePositions[i];
      final p1 = nodePositions[i + 1];
      final midY = (p0.dy + p1.dy) / 2;

      // Cubic bezier curve for beautiful smooth S-curves
      fullPath.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }

    // 3. Dark background path track
    final bgPaint = Paint()
      ..color = track
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fullPath, bgPaint);

    // Only connect completed neighbours. Playing a later topic does not
    // imply the earlier topics have been completed.
    final activePath = Path();
    for (int i = 0; i < nodePositions.length - 1; i++) {
      if (!completedNodeIndices.contains(i) ||
          !completedNodeIndices.contains(i + 1)) {
        continue;
      }
      final p0 = nodePositions[i];
      final p1 = nodePositions[i + 1];
      final midY = (p0.dy + p1.dy) / 2;
      activePath.moveTo(p0.dx, p0.dy);
      activePath.cubicTo(p0.dx, midY, p1.dx, midY, p1.dx, p1.dy);
    }
    if (completedNodeIndices.isNotEmpty) {
      // Core bright cyan line
      final activePaint = Paint()
        ..color = progress
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(activePath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPathPainter oldDelegate) {
    return oldDelegate.track != track ||
        oldDelegate.progress != progress ||
        oldDelegate.completedNodeIndices.length !=
            completedNodeIndices.length ||
        !oldDelegate.completedNodeIndices.containsAll(completedNodeIndices) ||
        oldDelegate.nodePositions.length != nodePositions.length ||
        !List.generate(
          nodePositions.length,
          (i) => oldDelegate.nodePositions[i] == nodePositions[i],
        ).every((same) => same);
  }
}
