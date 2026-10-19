import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routing/app_router.dart';
import 'social_controller.dart';
import '../../core/theme/appearance_theme.dart';
import '../../core/presentation/global_overlay_gate.dart';
import '../../core/progression/controllers/xp_controller.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../home/presentation/widgets/level_up_overlay.dart';
import '../../core/theme/aptiqu_tokens.dart';

class SocialOverlay extends StatefulWidget {
  final Widget child;
  final GlobalOverlayGate? gate;
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? messengerKey;
  final Stopwatch? stopwatch;
  const SocialOverlay({
    super.key,
    required this.child,
    this.gate,
    this.navigatorKey,
    this.messengerKey,
    this.stopwatch,
  });
  @override
  State<SocialOverlay> createState() => _SocialOverlayState();
}

class _SocialOverlayState extends State<SocialOverlay>
    with WidgetsBindingObserver {
  final _seen = <String>{};
  final _settled = <String>{};
  final _deadlines = <String, int>{};
  late final Stopwatch _clock;
  final _bannerText = ValueNotifier<String>('Duel invitation');
  late final SocialController social;
  XpController? xp;
  final _workers = <Worker>[];
  Timer? _timer;
  bool _showing = false, _scheduled = false, _foreground = true;
  String? _owner, _bannerKey, _toolbarInviteKey;
  DialogRoute<bool>? _dialog;
  ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>?
  _banner;
  GlobalOverlayGate get gate => widget.gate ?? AppRouter.overlayGate;
  GlobalKey<NavigatorState> get navigatorKey =>
      widget.navigatorKey ?? AppRouter.navigatorKey;
  GlobalKey<ScaffoldMessengerState> get messengerKey =>
      widget.messengerKey ?? AppRouter.messengerKey;
  @override
  void initState() {
    super.initState();
    _clock = widget.stopwatch ?? Stopwatch();
    _clock.start();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(_schedule);
    social = Get.find<SocialController>();
    if (Get.isRegistered<XpController>()) {
      xp = Get.find<XpController>()..presentationManaged = true;
      _workers.add(ever(xp!.pendingCelebration, (_) => _schedule()));
    }
    if (Get.isRegistered<AuthController>()) {
      final auth = Get.find<AuthController>();
      _owner = auth.currentUser.value?.id;
      _workers.add(
        ever(auth.currentUser, (user) {
          if (user?.id != _owner) {
            _owner = user?.id;
            _seen.clear();
            _settled.clear();
            _deadlines.clear();
            _hideBanner();
            xp?.pendingCelebration.value = null;
            final dialog = _dialog;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (dialog?.isActive == true) {
                dialog!.navigator?.removeRoute(dialog);
              }
            });
          }
          _schedule();
        }),
      );
    }
    _workers.add(ever(social.duelInvites, (_) => _inboxChanged()));
    gate.addListener(_schedule);
    _inboxChanged();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant SocialOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousGate = oldWidget.gate ?? AppRouter.overlayGate;
    if (previousGate != gate) {
      previousGate.removeListener(_schedule);
      gate.addListener(_schedule);
    }
    _schedule();
  }

  String _key(Map<String, dynamic> item) => '${item['key'] ?? item['id']}';
  int _remaining(String key) =>
      ((_deadlines[key] ?? 0) - _clock.elapsedMilliseconds).clamp(0, 60000);
  void _inboxChanged() {
    final now = _clock.elapsedMilliseconds;
    for (final item in social.duelInvites) {
      final key = _key(item);
      final deadline =
          now + ((item['remainingMs'] as num?)?.toInt() ?? 0).clamp(0, 60000);
      final previous = _deadlines[key];
      _deadlines[key] = previous == null || deadline < previous
          ? deadline
          : previous;
    }
    _timer?.cancel();
    if (_foreground && social.duelInvites.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _schedule());
    }
    _schedule();
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _present();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _inboxChanged();
    } else {
      _timer?.cancel();
    }
    _schedule();
  }

  bool get _signedIn =>
      !Get.isRegistered<AuthController>() ||
      Get.find<AuthController>().currentUser.value?.isRegistrationComplete ==
          true;
  Map<String, dynamic>? _pendingInvite() {
    for (final item in social.duelInvites) {
      final key = _key(item);
      if (_settled.contains(key)) continue;
      if (_remaining(key) <= 0) {
        _settled.add(key);
        unawaited(social.syncInbox());
      } else {
        return item;
      }
    }
    return null;
  }

  void _present() {
    if (!_signedIn || !_foreground) {
      _hideBanner();
      return;
    }
    final item = _pendingInvite();
    if (_showing) return;
    final safe =
        gate.canPresentAutomatically &&
        MediaQuery.viewInsetsOf(context).bottom == 0 &&
        !_editingText;
    if (item != null) {
      if (safe && !_seen.contains(_key(item))) {
        _showInvite(_key(item));
      } else {
        _showBanner(item);
      }
      return;
    }
    _hideBanner();
    if (safe && xp?.pendingCelebration.value != null) _showCelebration();
  }

  bool get _editingText {
    final focusedContext = FocusManager.instance.primaryFocus?.context;
    return focusedContext?.widget is EditableText ||
        focusedContext?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _hideBanner({bool keepToolbar = false}) {
    _banner?.close();
    _banner = null;
    _bannerKey = null;
    if (!keepToolbar) {
      _toolbarInviteKey = null;
      gate.invitationReview.value = null;
    }
  }

  void _showBanner(Map<String, dynamic> item) {
    final key = _key(item);
    if (gate.usesToolbarInvitation) {
      _hideBanner(keepToolbar: true);
      if (_toolbarInviteKey != key) {
        _toolbarInviteKey = key;
        gate.invitationReview.value = () => _showInvite(key);
      }
      return;
    }
    _bannerText.value =
        'Duel invitation · ${(_remaining(key) / 1000).ceil()}s left';
    if (_bannerKey == key) return;
    _hideBanner();
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    _bannerKey = key;
    _banner = messenger.showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        content: ValueListenableBuilder(
          valueListenable: _bannerText,
          builder: (context, text, _) => Semantics(
            liveRegion: true,
            label: 'Duel invitation available',
            child: ExcludeSemantics(child: Text(text)),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Review duel invitation',
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () => _showInvite(key),
          ),
        ],
      ),
    );
  }

  Future<void> _showInvite(String key) async {
    if (!mounted ||
        _showing ||
        gate.hasModal ||
        !_foreground ||
        !_signedIn ||
        _settled.contains(key)) {
      return;
    }
    final item = social.duelInvites.where((i) => _key(i) == key).firstOrNull;
    final context = navigatorKey.currentContext;
    if (item == null || context == null || _remaining(key) <= 0) {
      _schedule();
      return;
    }
    _hideBanner();
    _showing = true;
    final owner = _owner;
    _seen.add(key);
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      settings: const RouteSettings(name: 'global-duel-invitation'),
      builder: (_) => SocialInvitationDialog(
        invitation: {...item, 'remainingMs': _remaining(key)},
        duel: true,
      ),
    );
    _dialog = route;
    try {
      final accepted = await Navigator.of(
        context,
        rootNavigator: true,
      ).push(route);
      if (accepted != null && owner == _owner) _settled.add(key);
      if (accepted == true && mounted && _signedIn && owner == _owner) {
        // The person chose this response flow; preserve the existing destination.
        await AppRouter.router.push('/friendly-duel/${item['id']}?play=1');
      }
      if (mounted) await social.syncInbox();
    } finally {
      _dialog = null;
      _showing = false;
      _schedule();
    }
  }

  Future<void> _showCelebration() async {
    final context = navigatorKey.currentContext;
    final award = xp?.pendingCelebration.value;
    if (context == null || award == null || _showing) return;
    _showing = true;
    xp!.pendingCelebration.value = null;
    xp!.isLevelUpDialogActive.value = true;
    final route = DialogRoute<bool>(
      context: context,
      settings: const RouteSettings(name: 'global-level-up'),
      builder: (context) => LevelUpOverlay(
        levelUp: award,
        onContinue: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    );
    _dialog = route;
    try {
      await Navigator.of(context, rootNavigator: true).push(route);
    } finally {
      xp?.isLevelUpDialogActive.value = false;
      _dialog = null;
      _showing = false;
      _schedule();
    }
  }

  @override
  void dispose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    gate.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_schedule);
    _timer?.cancel();
    _clock.stop();
    // The owning ScaffoldMessenger/Navigator dispose their own presentation.
    xp?.presentationManaged = false;
    final review = gate.invitationReview.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (identical(gate.invitationReview.value, review)) {
        gate.invitationReview.value = null;
      }
    });
    _bannerText.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SocialInvitationDialog extends StatefulWidget {
  final Map<String, dynamic> invitation;
  final bool duel;
  final Stopwatch? stopwatch;
  const SocialInvitationDialog({
    super.key,
    required this.invitation,
    this.duel = false,
    this.stopwatch,
  });
  @override
  State<SocialInvitationDialog> createState() => _SocialInvitationDialogState();
}

class _SocialInvitationDialogState extends State<SocialInvitationDialog> {
  final social = Get.find<SocialController>();
  late final Stopwatch elapsed;
  Timer? timer;
  bool busy = false;
  String? error;
  int budget = 0;
  @override
  void initState() {
    super.initState();
    elapsed = widget.stopwatch ?? Stopwatch();
    if (widget.duel) {
      budget = (widget.invitation['remainingMs'] as num).toInt();
      elapsed.start();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (elapsed.elapsedMilliseconds >= budget && !busy) {
          Navigator.pop(context, false);
          social.syncInbox();
        } else {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    elapsed.stop();
    super.dispose();
  }

  Future<void> answer(bool accept) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (widget.duel) {
        await social.api.post('duels/${widget.invitation['id']}/respond', {
          'action': accept ? 'accept' : 'reject',
        });
      } else {
        await social.api.post(
          'friend-invitations/${widget.invitation['id']}/respond',
          {'accept': accept, 'version': widget.invitation['version']},
        );
      }
      if (mounted) Navigator.pop(context, accept);
    } on DioException catch (e) {
      if (!mounted) return;
      if ([404, 409].contains(e.response?.statusCode)) {
        Navigator.pop(context, false);
      } else {
        setState(
          () => error = e.response?.data is Map
              ? e.response?.data['message'] ?? 'Please try again.'
              : 'Please try again.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not respond. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
      await social.syncInbox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.invitation[widget.duel ? 'requester' : 'sender'];
    final seconds = ((budget - elapsed.elapsedMilliseconds) / 1000)
        .ceil()
        .clamp(0, 60);
    return AppearanceTheme(
      builder: (context) => PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          contentTextStyle: context.type.bodyLarge,
          title: Text(widget.duel ? 'Duel invitation' : 'Friend invitation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p['name']} ${widget.duel ? 'invited you to a 1v1 practice duel.' : 'wants to add you as a friend.'}',
              ),
              if (widget.duel) ...[
                const SizedBox(height: 12),
                Text('$seconds seconds to respond'),
                Text(
                  '${widget.invitation['smartPicks'] == true ? 'AI Picks · ' : 'Random selection · '}${widget.invitation['timerEnabled'] == true ? '60-second question timer' : 'No question timer'}',
                ),
                const Text('10 XP each when both finish. No other rewards.'),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: context.type.bodyMedium?.copyWith(
                    color: context.colors.error,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => answer(false),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: busy ? null : () => answer(true),
              child: Text(busy ? 'Responding…' : 'Accept'),
            ),
          ],
        ),
      ),
    );
  }
}
