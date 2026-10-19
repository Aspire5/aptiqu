import 'package:flutter/material.dart';

/// Tracks presentation safety only; it never pauses a timer or changes a session.
class GlobalOverlayGate extends NavigatorObserver with ChangeNotifier {
  final _popups = <Route<dynamic>>{};
  final _pages = <Route<dynamic>>[];
  final _tasks = <Object>{};
  bool _scheduled = false;
  final invitationReview = ValueNotifier<VoidCallback?>(null);
  bool get usesToolbarInvitation =>
      _pages.where((r) => r.navigator != null).lastOrNull?.settings.name ==
      'dailyChallengeQuiz';
  static const _learningRoutes = {
    'lesson',
    'lessonStep',
    'practiceSession',
    'pvpArena',
    'dailyChallengeQuiz',
    'dailyStreak',
    '/friendly-duel/:id',
  };
  bool get hasModal => _popups.any((r) => r.navigator != null);
  bool get isTaskActive =>
      _tasks.isNotEmpty ||
      _pages.any(
        (r) =>
            r.navigator != null &&
            r.isCurrent &&
            _learningRoutes.contains(r.settings.name),
      );
  bool get canPresentAutomatically => !hasModal && !isTaskActive;
  void _changed() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void setTask(Object owner, bool active) {
    final changed = active ? _tasks.add(owner) : _tasks.remove(owner);
    if (changed) _changed();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _pages.removeWhere((r) => r.navigator == null);
    if (route is PopupRoute) {
      _popups.add(route);
    } else {
      _pages.add(route);
    }
    _changed();
  }

  void _remove(Route<dynamic> route) {
    _popups.remove(route);
    _pages.remove(route);
    _changed();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Keep focus with a closing modal until its reverse transition finishes.
    if (route is TransitionRoute) {
      route.completed.whenComplete(() => _remove(route));
    } else {
      _remove(route);
    }
    _changed();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _remove(oldRoute);
    if (newRoute != null) didPush(newRoute, null);
  }
}

/// Daily's answer-feedback region keeps its full reading height.
class GlobalInvitationAction extends StatelessWidget {
  final GlobalOverlayGate gate;
  const GlobalInvitationAction({super.key, required this.gate});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: gate.invitationReview,
    builder: (context, review, _) => review == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: IconButton(
              tooltip: 'Review duel invitation',
              onPressed: review,
              icon: const Badge(child: Icon(Icons.mail_outline_rounded)),
            ),
          ),
  );
}

/// Busy regions on the shared Home route have no separate navigation entry.
class GlobalOverlayTask extends StatefulWidget {
  final GlobalOverlayGate gate;
  final bool active;
  final Widget child;
  const GlobalOverlayTask({
    super.key,
    required this.gate,
    required this.active,
    required this.child,
  });
  @override
  State<GlobalOverlayTask> createState() => _GlobalOverlayTaskState();
}

class _GlobalOverlayTaskState extends State<GlobalOverlayTask> {
  final _owner = Object();
  @override
  void initState() {
    super.initState();
    widget.gate.setTask(_owner, widget.active);
  }

  @override
  void didUpdateWidget(covariant GlobalOverlayTask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gate != widget.gate) oldWidget.gate.setTask(_owner, false);
    widget.gate.setTask(_owner, widget.active);
  }

  @override
  void dispose() {
    widget.gate.setTask(_owner, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
