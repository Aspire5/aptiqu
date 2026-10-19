import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import 'ranked_models.dart';
import 'ranked_widgets.dart';

/// Cosmetic receipts only. A storage failure skips motion, never the result.
class RankedMotionReceipts {
  static Future<void> _tail = Future.value();
  static Future<bool> consume(String owner, RankedChange change) async {
    final prior = _tail;
    var consumed = false;
    final work = () async {
      await prior;
      try {
        const store = FlutterSecureStorage();
        final key = 'aptiqu.ranked.motion.$owner';
        final raw = await store.read(key: key);
        final ids = raw == null
            ? <String>[]
            : (jsonDecode(raw) as List).cast<String>();
        final id = '${change.seasonId}:${change.eventId}';
        if (ids.contains(id)) return;
        ids.add(id);
        await store.write(
          key: key,
          value: jsonEncode(
            ids.skip(ids.length > 256 ? ids.length - 256 : 0).toList(),
          ),
        );
        consumed = true;
      } catch (_) {
        /* Static result remains available. */
      }
    }();
    _tail = work;
    await work;
    return consumed;
  }
}

class RankedResultView extends StatefulWidget {
  final RankedChange change;
  final String owner;
  final DateTime? settledAt;
  final Future<bool> Function(String, RankedChange)? consume;
  const RankedResultView({
    super.key,
    required this.change,
    required this.owner,
    this.settledAt,
    this.consume,
  });
  @override
  State<RankedResultView> createState() => _RankedResultViewState();
}

class _RankedResultViewState extends State<RankedResultView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: 1,
  );
  bool _started = false;
  bool get _reduced =>
      MediaQuery.disableAnimationsOf(context) ||
      View.of(context).platformDispatcher.accessibilityFeatures.reduceMotion;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced) _motion.value = 1;
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
    }
  }

  bool get _visible =>
      mounted &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      (WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState ==
              AppLifecycleState.resumed) &&
      (!Get.isRegistered<AuthController>() ||
          Get.find<AuthController>().currentUser.value?.id == widget.owner);
  Future<void> _prepare() async {
    final c = widget.change;
    if (!['PROMOTION', 'PLACEMENT_COMPLETE'].contains(c.changeKind)) return;
    final now = DateTime.now().toUtc();
    final ist = now.add(const Duration(minutes: 330));
    final month = '${ist.year}-${ist.month.toString().padLeft(2, '0')}';
    final age = widget.settledAt == null
        ? null
        : now.difference(widget.settledAt!);
    if (age == null ||
        age.isNegative ||
        age > const Duration(minutes: 5) ||
        c.seasonId != month ||
        !_visible) {
      return;
    }
    final canAnimate = await (widget.consume ?? RankedMotionReceipts.consume)(
      widget.owner,
      c,
    );
    if (!mounted) return;
    if (!_visible || !canAnimate || _reduced) return;
    final pixels = (96 * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(
      1,
      1254,
    );
    await Future.wait([
      for (final league in {c.leagueBefore, c.leagueAfter})
        precacheImage(
          ResizeImage(AssetImage(league.asset), width: pixels, height: pixels),
          context,
        ),
    ]);
    if (_visible && !_reduced) _motion.forward(from: 0);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted && _reduced) _motion.value = 1;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _motion.value = 1;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.change;
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _motion,
            builder: (context, _) {
              final t = _motion.value;
              final old = t < .2;
              final reveal = ((t - .2) / .8).clamp(0.0, 1.0);
              final opacity = old ? 1 - t / .2 : reveal;
              final scale = old
                  ? 1 - t * .6
                  : .82 + .18 * Curves.easeOutBack.transform(reveal);
              return Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(
                  scale: scale,
                  child: RankedBadge(
                    league: old ? c.leagueBefore : c.leagueAfter,
                    size: 96,
                    decorative: true,
                  ),
                ),
              );
            },
          ),
          Text(
            c.label,
            style: context.type.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('${c.before} → ${c.after} Elo', style: context.type.bodyLarge),
          Text('${signedElo(c.delta)} Elo', style: context.type.titleMedium),
          Text(seasonLabel(c.seasonId), style: context.type.bodySmall),
        ],
      ),
    );
  }
}
