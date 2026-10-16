import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'aptiqu_loading_indicator.dart';

/// Shared async loader. Fast operations never start an animation. Keep a stable
/// slot so showing the loader does not move the surrounding content.
class AppLoader extends StatefulWidget {
  final bool loading;
  final double size;
  const AppLoader({super.key, this.loading = true, this.size = 32});

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> {
  Timer? _timer;
  DateTime? _shownAt;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void didUpdateWidget(AppLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _update();
  }

  void _update() {
    _timer?.cancel();
    if (widget.loading) {
      if (_visible) return;
      _timer = Timer(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _visible = true;
          _shownAt = DateTime.now();
        });
      });
    } else if (_visible) {
      final remaining =
          350 - DateTime.now().difference(_shownAt!).inMilliseconds;
      _timer = Timer(Duration(milliseconds: remaining.clamp(0, 350)), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: LayoutBuilder(
      builder: (context, constraints) => _visible
          ? Semantics(
              label: 'Loading',
              child: AptiquLoadingIndicator(
                size: math.min(
                  widget.size,
                  math.min(constraints.maxWidth, constraints.maxHeight),
                ),
              ),
            )
          : const SizedBox.shrink(),
    ),
  );
}
