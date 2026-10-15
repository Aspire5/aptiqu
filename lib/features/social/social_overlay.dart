import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routing/app_router.dart';
import 'social_controller.dart';

class SocialOverlay extends StatefulWidget {
  final Widget child;
  const SocialOverlay({super.key, required this.child});
  @override
  State<SocialOverlay> createState() => _SocialOverlayState();
}

class _SocialOverlayState extends State<SocialOverlay> {
  final seen = <String>{};
  bool showing = false;
  Worker? friendWorker, duelWorker;
  late SocialController social;
  @override
  void initState() {
    super.initState();
    social = Get.find<SocialController>();
    friendWorker = ever(social.friendInvites, (_) => prompt());
    duelWorker = ever(social.duelInvites, (_) => prompt());
    WidgetsBinding.instance.addPostFrameCallback((_) => prompt());
  }

  void prompt() {
    if (showing || !mounted) return;
    final duel = social.duelInvites
        .where((r) => !seen.contains(r['key'] ?? r['id']))
        .firstOrNull;
    final friend = social.friendInvites
        .where((r) => !seen.contains(r['key'] ?? r['id']))
        .firstOrNull;
    final item = duel ?? friend;
    if (item == null) return;
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return;
    showing = true;
    seen.add(item['key'] ?? item['id']);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: ctx,
        barrierDismissible: false,
        builder: (_) =>
            SocialInvitationDialog(invitation: item, duel: duel != null),
      );
      showing = false;
      if (accepted == true && duel != null && mounted) {
        await AppRouter.router.push('/friendly-duel/${item['id']}?play=1');
      }
      await social.syncInbox();
      prompt();
    });
  }

  @override
  void dispose() {
    friendWorker?.dispose();
    duelWorker?.dispose();
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
    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        title: Text(widget.duel ? 'Aptitude duel' : 'Friend invitation'),
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
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
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
    );
  }
}
