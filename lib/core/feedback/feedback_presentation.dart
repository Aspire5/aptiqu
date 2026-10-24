import 'package:flutter/material.dart';

final feedbackRouteObserver = RouteObserver<ModalRoute<dynamic>>();

/// Delivery happens after a rendered frame, never as a side effect of build.
/// Route coverage silences feedback without changing the server-owned gameplay.
class FeedbackPresentation extends StatefulWidget {
  const FeedbackPresentation({
    super.key,
    required this.child,
    required this.presentationKey,
    required this.onVisibility,
    required this.onPresented,
  });
  final Widget child;
  final String? presentationKey;
  final ValueChanged<bool> onVisibility;
  final VoidCallback onPresented;
  @override
  State<FeedbackPresentation> createState() => _FeedbackPresentationState();
}

class _FeedbackPresentationState extends State<FeedbackPresentation>
    with RouteAware {
  ModalRoute<dynamic>? _route;
  bool _scheduled = false;
  void _present() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      final visible = _route?.isCurrent ?? true;
      widget.onVisibility(visible);
      if (visible && widget.presentationKey != null) widget.onPresented();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      feedbackRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) feedbackRouteObserver.subscribe(this, route);
    }
    _present();
  }

  @override
  void didUpdateWidget(FeedbackPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentationKey != widget.presentationKey) _present();
  }

  @override
  void didPush() => _present();
  @override
  void didPopNext() => _present();
  @override
  void didPushNext() => widget.onVisibility(false);
  @override
  void didPop() => widget.onVisibility(false);
  @override
  void dispose() {
    feedbackRouteObserver.unsubscribe(this);
    widget.onVisibility(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
