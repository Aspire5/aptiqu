import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import '../../models/roadmap_model.dart';
import '../controllers/home_controller.dart';

/// Cyberpunk Constellation Winding Roadmap View
///
/// Features:
/// - 2D Zoomable & Pannable Canvas with [InteractiveViewer] (unconstrained for full scroll freedom)
/// - Cinematic zoom-in camera animation focusing on the active user node upon tab open
/// - Fixed minimal, non-transparent "Subjects" header with dynamic progress (e.g. 0/72)
/// - Fullscreen mode with smooth animated slide/fade transitions
/// - Bottom node preview sheet hidden by default, shown ONLY on node tap, dismissed on outside tap
/// - Winding S-curve constellation path with glowing neon progress line
/// - Gamified milestone nodes (Active Objective, Completed with 3 Stars, Ready/Unlocked, Boss Gate, Coming Soon)
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
  State<ConstellationRoadmapView> createState() => _ConstellationRoadmapViewState();
}

class _ConstellationRoadmapViewState extends State<ConstellationRoadmapView>
    with TickerProviderStateMixin {
  // Canvas vertical metrics
  static const double nodeSpacing = 160.0;
  static const double topPadding = 100.0;
  static const double bottomPadding = 450.0;

  // Zoom and Pan controller
  late TransformationController _transformationController;
  late AnimationController _cameraAnimationController;
  Animation<Matrix4>? _cameraAnimation;

  // Pulsing glow animation for active node
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Docked inspected topic - HIDDEN BY DEFAULT!
  LearningMapTopicItemModel? _inspectedTopic;
  bool _isDockVisible = false;

  // Viewport cached size
  Size _viewportSize = Size.zero;
  bool _hasInitialZoomAnimated = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();

    _cameraAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Default inspected topic without opening the dock
    _inspectedTopic = _getActiveOrFirstTopic();
    _isDockVisible = false;
  }

  @override
  void didUpdateWidget(covariant ConstellationRoadmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.learningMap.subjectId != widget.learningMap.subjectId ||
        oldWidget.cameraTrigger != widget.cameraTrigger) {
      _inspectedTopic = _getActiveOrFirstTopic();
      _isDockVisible = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animateCameraToActiveNode();
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _cameraAnimationController.dispose();
    _pulseController.dispose();
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

    final activeStepId = widget.learningMap.activeStepId;
    if (activeStepId != null) {
      final match = topics.where((t) => t.roadmapStepId == activeStepId);
      if (match.isNotEmpty) return match.first;
    }

    final available = topics.where((t) => t.isAvailable || t.isInProgress);
    if (available.isNotEmpty) return available.first;

    return topics.first;
  }

  int _getActiveTopicIndex() {
    final active = _getActiveOrFirstTopic();
    final index = widget.learningMap.topics.indexOf(active);
    return index >= 0 ? index : 0;
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
  Matrix4 _buildMatrix2D({required double tx, required double ty, required double scale}) {
    final m = Matrix4.identity();
    m.setEntry(0, 0, scale);
    m.setEntry(1, 1, scale);
    m.setEntry(0, 3, tx);
    m.setEntry(1, 3, ty);
    return m;
  }

  /// Triggers smooth cinematic zoom-in camera animation from zoomed-out to the target node
  void _animateCameraToActiveNode({bool instant = false}) {
    if (_viewportSize == Size.zero || widget.learningMap.topics.isEmpty) return;

    final canvasWidth = max(_viewportSize.width, 420.0);
    final targetIndex = _getActiveTopicIndex();
    final targetOffset = _getNodePosition(targetIndex, widget.learningMap.topics.length, canvasWidth);

    const double targetScale = 1.05;
    const double startScale = 0.52;

    // Viewport center target
    final double targetViewportX = _viewportSize.width / 2;
    final double targetViewportY = _viewportSize.height * 0.45;

    // End matrix focused on active node
    final Matrix4 endMatrix = _buildMatrix2D(
      tx: targetViewportX - (targetOffset.dx * targetScale),
      ty: targetViewportY - (targetOffset.dy * targetScale),
      scale: targetScale,
    );

    if (instant) {
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

    _cameraAnimation = Matrix4Tween(
      begin: startMatrix,
      end: endMatrix,
    ).animate(
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
    final targetOffset = _getNodePosition(index, widget.learningMap.topics.length, canvasWidth);
    final double currentScale = _transformationController.value.getMaxScaleOnAxis().clamp(0.8, 1.4);

    final double targetViewportX = _viewportSize.width / 2;
    final double targetViewportY = _viewportSize.height * 0.42;

    final Matrix4 targetMatrix = _buildMatrix2D(
      tx: targetViewportX - (targetOffset.dx * currentScale),
      ty: targetViewportY - (targetOffset.dy * currentScale),
      scale: currentScale,
    );

    _cameraAnimation = Matrix4Tween(
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

        final canvasWidth = max(constraints.maxWidth, 420.0);
        final canvasHeight = topPadding + (totalTopics * nodeSpacing) + bottomPadding;

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

            // 2. EXPANDED ZOOMABLE & PANNABLE MAP CANVAS
            Expanded(
              child: Stack(
                children: [
                  // Full interactive viewer (unconstrained gives full freedom to scroll entire height)
                  AnimatedBuilder(
                    animation: _cameraAnimationController,
                    builder: (context, child) {
                      if (_cameraAnimation != null && _cameraAnimationController.isAnimating) {
                        _transformationController.value = _cameraAnimation!.value;
                      }
                      return child!;
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      constrained: false, // COMPLETE SCROLL FREEDOM ALL THE WAY DOWN
                      minScale: 0.35,
                      maxScale: 2.2,
                      boundaryMargin: const EdgeInsets.symmetric(
                        horizontal: 200,
                        vertical: 800,
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          // Tapping anywhere on map canvas dismisses the bottom dock!
                          if (_isDockVisible) {
                            setState(() {
                              _isDockVisible = false;
                            });
                          }
                        },
                        child: SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Ambient Cyber Constellation Background & Connecting Winding Path
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ConstellationPathPainter(
                                    nodePositions: nodePositions,
                                    activeNodeIndex: activeIndex,
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
                                  isInspected: _inspectedTopic?.roadmapStepId == topics[i].roadmapStepId,
                                  isBossGate: (i + 1) % 10 == 0 || i == totalTopics - 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 3. FLOATING HUD CONTROLS (Fullscreen, Re-center, Zoom In, Zoom Out)
                  Positioned(
                    right: 14,
                    bottom: _isDockVisible ? 240 : 20,
                    child: _buildHudControls(),
                  ),

                  // 4. FLOATING DOCKED INTERACTIVE CARD (ONLY visible when _isDockVisible is true)
                  if (_isDockVisible && _inspectedTopic != null)
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: _buildNodeDetailsDock(_inspectedTopic!),
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

  Widget _buildAnimatedFixedSubjectsBar() {
    const double barHeight = 48.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      height: widget.isFullScreen ? 0.0 : barHeight,
      child: AnimatedSlide(
        offset: widget.isFullScreen ? const Offset(0, -1) : Offset.zero,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        child: AnimatedOpacity(
          opacity: widget.isFullScreen ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 240),
          child: OverflowBox(
            minHeight: barHeight,
            maxHeight: barHeight,
            alignment: Alignment.topCenter,
            child: _buildFixedSubjectsBar(),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedSubjectsBar() {
    final completed = widget.learningMap.completedTopics;
    final total = widget.learningMap.totalTopics;
    // Total stars: 3 per topic
    final progressStarsText = '$completed/${total * 3}';

    return Container(
      height: 48.0,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: AptiquColors.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: AptiquColors.outlineVariant,
            width: 1.0,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // "SUBJECTS" Label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.hub_rounded, size: 14, color: AptiquColors.primary),
                const SizedBox(width: 5),
                Text(
                  'SUBJECTS',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: AptiquColors.primary,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 16,
                  color: AptiquColors.outlineVariant,
                ),
                const SizedBox(width: 10),
              ],
            ),

            // Horizontal Subject Chips
            ...widget.subjects.map((subj) {
              final isSelected = subj.id == widget.selectedSubjectId;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => widget.onSelectSubject(subj.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AptiquColors.primaryContainer.withValues(alpha: 0.25)
                          : AptiquColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AptiquColors.primary : AptiquColors.outlineVariant,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                      boxShadow: isSelected ? AptiquColors.primaryGlow : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AptiquColors.secondary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AptiquColors.secondary, blurRadius: 4),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          subj.name,
                          style: AptiquTypography.bodySm.copyWith(
                            fontSize: 12,
                            color: isSelected ? Colors.white : AptiquColors.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AptiquColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: AptiquColors.tertiary),
                                const SizedBox(width: 2),
                                Text(
                                  progressStarsText,
                                  style: AptiquTypography.metricSm.copyWith(
                                    color: AptiquColors.tertiary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // NODE WIDGETS
  // ===========================================================================

  Widget _buildNodeItem({
    required LearningMapTopicItemModel topic,
    required int index,
    required Offset position,
    required bool isActiveFocus,
    required bool isInspected,
    required bool isBossGate,
  }) {
    return Positioned(
      left: position.dx - 130,
      top: position.dy - 55,
      width: 260,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _inspectedTopic = topic;
            _isDockVisible = true;
          });
          _panCameraToNode(index);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Active Focus Tag Banner
            if (isActiveFocus)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AptiquColors.primaryContainer, AptiquColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AptiquColors.primaryGlow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'CURRENT TOPIC',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AptiquTypography.labelCapsBold.copyWith(
                          color: Colors.white,
                          fontSize: 8.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Node Circle
            if (isBossGate)
              _buildBossNodeCircle(topic, isActiveFocus, isInspected)
            else if (isActiveFocus)
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
              style: AptiquTypography.headlineSm.copyWith(
                fontSize: 13.5,
                fontWeight: isActiveFocus ? FontWeight.w800 : FontWeight.w600,
                color: isActiveFocus
                    ? AptiquColors.primary
                    : isInspected
                        ? Colors.white
                        : AptiquColors.onSurface,
              ),
            ),

            const SizedBox(height: 2),

            // Status Badge Pill
            _buildNodeStatusBadge(topic, isActiveFocus, isBossGate),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFocusNodeCircle(LearningMapTopicItemModel topic) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AptiquColors.primary, AptiquColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AptiquColors.primaryContainer.withValues(alpha: 0.6),
              blurRadius: 22,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: AptiquColors.secondary.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AptiquColors.surfaceContainerLowest,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: AptiquColors.primary,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedNodeCircle(LearningMapTopicItemModel topic, bool isInspected) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AptiquColors.surfaceContainerHigh,
            border: Border.all(
              color: AptiquColors.secondary.withValues(alpha: isInspected ? 1.0 : 0.6),
              width: isInspected ? 2.5 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AptiquColors.secondary.withValues(alpha: 0.3),
                blurRadius: 12,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.check_rounded,
              color: AptiquColors.secondary,
              size: 26,
            ),
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AptiquColors.secondary,
              shape: BoxShape.circle,
              border: Border.all(color: AptiquColors.surfaceContainerHigh, width: 1.5),
            ),
            child: const Icon(
              Icons.done_all_rounded,
              size: 11,
              color: AptiquColors.onSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadyNodeCircle(LearningMapTopicItemModel topic, bool isInspected) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AptiquColors.surfaceContainerHigh,
            border: Border.all(
              color: isInspected ? AptiquColors.primary : AptiquColors.outlineVariant,
              width: isInspected ? 2.0 : 1.4,
            ),
            boxShadow: isInspected ? AptiquColors.primaryGlow : null,
          ),
          child: const Center(
            child: Icon(
              Icons.trending_up_rounded,
              color: AptiquColors.secondary,
              size: 24,
            ),
          ),
        ),
        Positioned(
          bottom: -3,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AptiquColors.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'READY',
              style: AptiquTypography.labelCapsBold.copyWith(
                fontSize: 7.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLockedNodeCircle(LearningMapTopicItemModel topic, bool isInspected) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AptiquColors.surfaceContainerLow,
        border: Border.all(
          color: isInspected ? AptiquColors.outline : AptiquColors.outlineVariant,
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(
          topic.isComingSoon ? Icons.schedule_rounded : Icons.lock_outline_rounded,
          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.6),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildBossNodeCircle(LearningMapTopicItemModel topic, bool isActive, bool isInspected) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AptiquColors.surfaceContainerHigh,
            border: Border.all(
              color: AptiquColors.tertiaryContainer,
              width: 2.0,
            ),
            boxShadow: [
              BoxShadow(
                color: AptiquColors.tertiaryContainer.withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.security_rounded,
              color: AptiquColors.tertiary,
              size: 30,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AptiquColors.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 10, color: Colors.white),
                const SizedBox(width: 2),
                Text(
                  'BOSS',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtopicsProgressPill(LearningMapTopicItemModel topic) {
    final total = topic.totalSubtopics > 0 ? topic.totalSubtopics : 8;
    final done = topic.completedSubtopics;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: topic.isCompleted
              ? AptiquColors.secondary.withValues(alpha: 0.6)
              : AptiquColors.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Text(
        '$done/$total',
        style: AptiquTypography.labelCapsBold.copyWith(
          fontSize: 9.5,
          color: topic.isCompleted
              ? AptiquColors.secondary
              : (done > 0 ? Colors.white : AptiquColors.onSurfaceVariant),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNodeStatusBadge(
    LearningMapTopicItemModel topic,
    bool isActiveFocus,
    bool isBossGate,
  ) {
    if (isBossGate) {
      return Text(
        'SECTOR BOSS GATE',
        style: AptiquTypography.labelCapsBold.copyWith(
          color: AptiquColors.tertiary,
          fontSize: 9,
        ),
      );
    }

    if (isActiveFocus) {
      return Text(
        topic.isInProgress || topic.completedSubtopics > 0
            ? 'CONTINUE TOPIC'
            : 'START TOPIC',
        style: AptiquTypography.labelCapsBold.copyWith(
          color: AptiquColors.secondary,
          fontSize: 9.5,
          letterSpacing: 0.8,
        ),
      );
    }

    if (topic.isCompleted) {
      return Text(
        'COMPLETE',
        style: AptiquTypography.labelCapsBold.copyWith(
          color: AptiquColors.secondary,
          fontSize: 9,
        ),
      );
    }

    if (topic.isInProgress) {
      return Text(
        'IN PROGRESS',
        style: AptiquTypography.labelCaps.copyWith(
          color: AptiquColors.primary,
          fontSize: 9,
        ),
      );
    }

    if (topic.isAvailable) {
      return Text(
        'UNLOCKED',
        style: AptiquTypography.labelCaps.copyWith(
          color: AptiquColors.onSurfaceVariant,
          fontSize: 9,
        ),
      );
    }

    return Text(
      'COMING SOON',
      style: AptiquTypography.labelCaps.copyWith(
        color: AptiquColors.onSurfaceDisabled,
        fontSize: 8.5,
      ),
    );
  }

  // ===========================================================================
  // FLOATING HUD CONTROLS (Fullscreen, Re-center, Zoom In, Zoom Out)
  // ===========================================================================

  Widget _buildHudControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Fullscreen Toggle Button
        FloatingActionButton.small(
          heroTag: 'fullscreen_toggle_map',
          backgroundColor: widget.isFullScreen
              ? AptiquColors.primaryContainer
              : AptiquColors.surfaceContainerHigh,
          foregroundColor: widget.isFullScreen ? Colors.white : AptiquColors.secondary,
          elevation: 6,
          shape: CircleBorder(
            side: BorderSide(
              color: widget.isFullScreen ? AptiquColors.primary : AptiquColors.outlineVariant,
            ),
          ),
          onPressed: widget.onToggleFullScreen,
          tooltip: widget.isFullScreen ? 'Exit Fullscreen' : 'Fullscreen Map',
          child: Icon(
            widget.isFullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),

        // 2. Re-center Target Button
        FloatingActionButton.small(
          heroTag: 'recenter_node',
          backgroundColor: AptiquColors.surfaceContainerHigh,
          foregroundColor: AptiquColors.primary,
          elevation: 6,
          shape: const CircleBorder(
            side: BorderSide(color: AptiquColors.outlineVariant),
          ),
          onPressed: () {
            final active = _getActiveOrFirstTopic();
            setState(() {
              _inspectedTopic = active;
              _isDockVisible = true;
            });
            _animateCameraToActiveNode();
          },
          tooltip: 'Focus Active Level',
          child: const Icon(Icons.my_location_rounded, size: 19),
        ),
        const SizedBox(height: 8),

        // 3. Zoom In
        FloatingActionButton.small(
          heroTag: 'zoom_in_map',
          backgroundColor: AptiquColors.surfaceContainerHigh,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(
            side: BorderSide(color: AptiquColors.outlineVariant),
          ),
          onPressed: () {
            final current = _transformationController.value;
            final zoomed = Matrix4.copy(current)
              ..multiply(Matrix4.diagonal3Values(1.25, 1.25, 1.0));
            _transformationController.value = zoomed;
          },
          tooltip: 'Zoom In',
          child: const Icon(Icons.add, size: 18),
        ),
        const SizedBox(height: 8),

        // 4. Zoom Out
        FloatingActionButton.small(
          heroTag: 'zoom_out_map',
          backgroundColor: AptiquColors.surfaceContainerHigh,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: const CircleBorder(
            side: BorderSide(color: AptiquColors.outlineVariant),
          ),
          onPressed: () {
            final current = _transformationController.value;
            final zoomed = Matrix4.copy(current)
              ..multiply(Matrix4.diagonal3Values(0.80, 0.80, 1.0));
            _transformationController.value = zoomed;
          },
          tooltip: 'Zoom Out',
          child: const Icon(Icons.remove, size: 18),
        ),
      ],
    );
  }

  // ===========================================================================
  // FLOATING DOCKED INTERACTIVE CARD / NODE PREVIEW SHEET
  // ===========================================================================

  Widget _buildNodeDetailsDock(LearningMapTopicItemModel topic) {
    final isCompleted = topic.isCompleted;
    final totalSubtopics = topic.totalSubtopics > 0 ? topic.totalSubtopics : 8;
    final completedCount = topic.completedSubtopics;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.68,
      ),
      decoration: BoxDecoration(
        color: AptiquColors.surfaceContainer.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AptiquColors.outlineVariant.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top pill indicator
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AptiquColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header: Icon + Topic Tag & Subtopic progress + Close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AptiquColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.percent_rounded,
                  color: AptiquColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TOPIC ${topic.sequence.toString().padLeft(2, '0')}',
                          style: AptiquTypography.labelCapsBold.copyWith(
                            color: AptiquColors.secondary,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AptiquColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AptiquColors.secondary.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '$completedCount/$totalSubtopics',
                            style: AptiquTypography.labelCapsBold.copyWith(
                              color: AptiquColors.secondary,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topic.topicName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AptiquTypography.headlineSm.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _isDockVisible = false;
                  });
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AptiquColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AptiquColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Insight capsule with full readable text (no ellipsis)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: AptiquColors.secondaryContainer.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 13,
                    color: AptiquColors.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Insight: ',
                      style: AptiquTypography.bodySm.copyWith(
                        color: AptiquColors.secondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      children: [
                        TextSpan(
                          text: topic.description ??
                              'Build the basic numerical fluency required to solve aptitude problems confidently and quickly without pencil and paper.',
                          style: AptiquTypography.bodySm.copyWith(
                            color: AptiquColors.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Scrollable Subtopics List
          Flexible(
            child: topic.subtopics.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        'Content for this topic is being finalized.',
                        style: AptiquTypography.bodySm.copyWith(
                          color: AptiquColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: topic.subtopics.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final subtopic = topic.subtopics[index];
                      return _buildSubtopicRowItem(context, topic, subtopic);
                    },
                  ),
          ),

          // The Practice and Replay Topic buttons appear ONLY once the ENTIRE topic is completed
          if (isCompleted) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AptiquColors.outlineVariant),
                        backgroundColor: AptiquColors.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Quick Practice Drills for "${topic.topicName}" loading...'),
                            backgroundColor: AptiquColors.surfaceContainer,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.fitness_center_rounded, size: 16, color: AptiquColors.secondary),
                      label: Text(
                        'Practice',
                        style: AptiquTypography.headlineSm.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AptiquColors.secondary,
                        foregroundColor: AptiquColors.onSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 2,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => widget.onTopicTap(topic),
                      icon: const Icon(Icons.replay_rounded, size: 17),
                      label: Text(
                        'Replay Topic',
                        style: AptiquTypography.headlineSm.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtopicRowItem(
    BuildContext context,
    LearningMapTopicItemModel topic,
    SubtopicItemModel subtopic,
  ) {
    final controller = Get.find<HomeController>();
    final isDone = subtopic.isCompleted;
    final isLocked = subtopic.isLocked;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDone
            ? AptiquColors.secondaryContainer.withValues(alpha: 0.08)
            : (isLocked
                ? AptiquColors.surfaceContainerLowest.withValues(alpha: 0.35)
                : AptiquColors.surfaceContainerHigh.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? AptiquColors.secondary.withValues(alpha: 0.35)
              : (isLocked
                  ? AptiquColors.outlineVariant.withValues(alpha: 0.2)
                  : AptiquColors.primary.withValues(alpha: 0.5)),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Status Icon: Green check for completed, play for unlocked, lock for locked
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? AptiquColors.secondary.withValues(alpha: 0.2)
                  : (isLocked
                      ? AptiquColors.surfaceContainerHighest.withValues(alpha: 0.4)
                      : AptiquColors.primary.withValues(alpha: 0.25)),
            ),
            child: Icon(
              isDone
                  ? Icons.check_circle_rounded
                  : (isLocked
                      ? Icons.lock_outline_rounded
                      : Icons.play_arrow_rounded),
              size: 14,
              color: isDone
                  ? AptiquColors.secondary
                  : (isLocked
                      ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.4)
                      : AptiquColors.primary),
            ),
          ),
          const SizedBox(width: 10),

          // Subtopic details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  subtopic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AptiquTypography.bodyMd.copyWith(
                    fontSize: 12,
                    fontWeight: isDone ? FontWeight.w600 : (isLocked ? FontWeight.normal : FontWeight.w700),
                    color: isLocked
                        ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.5)
                        : Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isDone
                      ? 'Completed'
                      : (isLocked
                          ? 'Complete previous subtopic first'
                          : 'Up next'),
                  style: AptiquTypography.bodySm.copyWith(
                    fontSize: 9.5,
                    color: isDone
                        ? AptiquColors.secondary
                        : (isLocked
                            ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.4)
                            : AptiquColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Action button
          if (isDone) ...[
            SizedBox(
              height: 28,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AptiquColors.secondary.withValues(alpha: 0.5), width: 0.8),
                  backgroundColor: AptiquColors.secondaryContainer.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed: () {
                  setState(() => _isDockVisible = false);
                  controller.startSubtopicLesson(
                    roadmapStepId: topic.roadmapStepId,
                    scriptSlug: subtopic.scriptSlug ?? topic.scriptSlug ?? '',
                    scriptTitle: subtopic.title,
                  );
                },
                icon: const Icon(Icons.replay_rounded, size: 12, color: AptiquColors.secondary),
                label: Text(
                  'Replay',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    color: AptiquColors.secondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ] else if (!isLocked) ...[
            SizedBox(
              height: 28,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AptiquColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 1,
                ),
                onPressed: () {
                  setState(() => _isDockVisible = false);
                  if (subtopic.scriptSlug != null) {
                    controller.startSubtopicLesson(
                      roadmapStepId: topic.roadmapStepId,
                      scriptSlug: subtopic.scriptSlug!,
                      scriptTitle: subtopic.title,
                    );
                  } else {
                    widget.onTopicTap(topic);
                  }
                },
                child: Text(
                  'Start',
                  style: AptiquTypography.labelCapsBold.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// CUSTOM PAINTER: WINDING S-CURVE CONSTELLATION PATH
// =============================================================================

class _ConstellationPathPainter extends CustomPainter {
  final List<Offset> nodePositions;
  final int activeNodeIndex;

  _ConstellationPathPainter({
    required this.nodePositions,
    required this.activeNodeIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (nodePositions.length < 2) return;

    // 1. Ambient Constellation Stars in Background
    final random = Random(42);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (int s = 0; s < 50; s++) {
      final sx = random.nextDouble() * size.width;
      final sy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
    }

    // 2. Build full winding serpentine path
    final fullPath = Path();
    fullPath.moveTo(nodePositions.first.dx, nodePositions.first.dy);

    for (int i = 0; i < nodePositions.length - 1; i++) {
      final p0 = nodePositions[i];
      final p1 = nodePositions[i + 1];
      final midY = (p0.dy + p1.dy) / 2;

      // Cubic bezier curve for beautiful smooth S-curves
      fullPath.cubicTo(
        p0.dx,
        midY,
        p1.dx,
        midY,
        p1.dx,
        p1.dy,
      );
    }

    // 3. Dark background path track
    final bgPaint = Paint()
      ..color = const Color(0xFF232838)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fullPath, bgPaint);

    // 4. Glowing Neon Cyan active progression path (up to active node)
    final clampedActiveIdx = activeNodeIndex.clamp(0, nodePositions.length - 1);
    if (clampedActiveIdx > 0) {
      final activePath = Path();
      activePath.moveTo(nodePositions.first.dx, nodePositions.first.dy);

      for (int i = 0; i < clampedActiveIdx; i++) {
        final p0 = nodePositions[i];
        final p1 = nodePositions[i + 1];
        final midY = (p0.dy + p1.dy) / 2;

        activePath.cubicTo(
          p0.dx,
          midY,
          p1.dx,
          midY,
          p1.dx,
          p1.dy,
        );
      }

      // Neon outer glow
      final glowPaint = Paint()
        ..color = AptiquColors.secondary.withValues(alpha: 0.4)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4.0);

      canvas.drawPath(activePath, glowPaint);

      // Core bright cyan line
      final activePaint = Paint()
        ..color = AptiquColors.secondary
        ..strokeWidth = 3.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(activePath, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConstellationPathPainter oldDelegate) {
    return oldDelegate.activeNodeIndex != activeNodeIndex ||
        oldDelegate.nodePositions.length != nodePositions.length;
  }
}
