import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/aptiqu_colors.dart';
import '../auth/presentation/controllers/auth_controller.dart';
import '../practice/controllers/practice_session_controller.dart';
import '../practice/repositories/practice_repository.dart';
import 'social_controller.dart';

class DuelRoomScreen extends StatefulWidget {
  final String id;
  final bool play;
  const DuelRoomScreen({super.key, required this.id, this.play = false});
  @override
  State<DuelRoomScreen> createState() => _DuelRoomScreenState();
}

class _DuelRoomScreenState extends State<DuelRoomScreen> {
  final social = Get.find<SocialController>();
  Map<String, dynamic>? duel;
  String? error;
  bool busy = false,
      fetching = false,
      queued = false,
      opened = false,
      expiryChecked = false;
  final elapsed = Stopwatch();
  int remaining = 0;
  Timer? timer;
  StreamSubscription? subscription;
  @override
  void initState() {
    super.initState();
    load();
    subscription = social.events.stream.listen((event) {
      if ((event['event'] == 'DUEL_CHANGED' && event['id'] == widget.id) ||
          event['event'] == 'INBOX_CHANGED' ||
          event['event'] == 'RECONNECTED') {
        load();
      }
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (duel?['status'] == 'PENDING' &&
          remaining - elapsed.elapsedMilliseconds <= 0 &&
          !expiryChecked) {
        expiryChecked = true;
        load();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    subscription?.cancel();
    elapsed.stop();
    super.dispose();
  }

  Future<void> load() async {
    if (fetching) {
      queued = true;
      return;
    }
    fetching = true;
    try {
      final data = await social.api.get('duels/${widget.id}');
      if (!mounted) return;
      if (data['status'] != 'PENDING') timer?.cancel();
      setState(() {
        duel = data;
        error = null;
        remaining = (data['remainingMs'] as num).toInt();
        elapsed
          ..reset()
          ..start();
      });
      if (data['status'] == 'COMPLETED') {
        await Get.find<AuthController>().fetchUserProfile();
      }
      if (widget.play && !opened && data['status'] == 'ACTIVE') {
        opened = true;
        await openSession();
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not refresh this duel. Please retry.');
      }
    } finally {
      fetching = false;
      if (queued) {
        queued = false;
        load();
      }
    }
  }

  Future<void> openSession() async {
    final id = duel?['sessionId'];
    if (id == null || busy) return;
    setState(() => busy = true);
    try {
      final session = await PracticeRepository().getSession(id);
      if (!mounted) return;
      if (Get.isRegistered<PracticeSessionController>()) {
        Get.delete<PracticeSessionController>();
      }
      await AppRouter.router.push(AppRoutes.practiceSession, extra: session);
      await load();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not open the practice duel. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> leave() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      if (duel?['status'] == 'PENDING' &&
          duel?['requester']['id'] ==
              Get.find<AuthController>().currentUser.value?.id) {
        await social.api.post('duels/${widget.id}/respond', {
          'action': 'cancel',
        });
      } else if (duel?['status'] == 'PENDING') {
        await social.api.post('duels/${widget.id}/respond', {
          'action': 'reject',
        });
      } else {
        await social.api.post('duels/${widget.id}/leave');
      }
      await load();
      await social.syncInbox();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not leave this duel. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await load();
      }
    }
  }

  Future<void> accept() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await social.api.post('duels/${widget.id}/respond', {'action': 'accept'});
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not accept this invitation. Please retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        await load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = duel;
    final seconds = ((remaining - elapsed.elapsedMilliseconds) / 1000)
        .ceil()
        .clamp(0, 60);
    final own = d == null
        ? null
        : (d['sessions'] as List)
              .where(
                (s) =>
                    s['userId'] ==
                    Get.find<AuthController>().currentUser.value?.id,
              )
              .firstOrNull;
    final pending = d?['status'] == 'PENDING';
    return PopScope(
      canPop: !pending && !busy,
      onPopInvokedWithResult: (popped, _) async {
        if (!popped && pending && !busy) {
          await leave();
          if (context.mounted && duel?['status'] != 'PENDING') {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AptiquColors.surfaceDim,
        appBar: AppBar(title: const Text('Friendly duel')),
        body: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (d == null) const Center(child: AppLoader()),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: AptiquColors.error)),
                TextButton(onPressed: load, child: const Text('Retry')),
              ],
              if (d != null) ...[
                Text(
                  '${d['requester']['name']} vs ${d['recipient']['name']}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                Text(
                  pending
                      ? 'Waiting for your friend · ${seconds}s'
                      : d['status'] == 'EXPIRED'
                      ? 'Your friend did not respond within 60 seconds.'
                      : d['status'] == 'REJECTED'
                      ? 'Your friend declined the duel.'
                      : d['status'] == 'CANCELLED'
                      ? 'This invitation was cancelled.'
                      : d['status'] == 'ABANDONED'
                      ? 'This duel was left before both players finished. No XP awarded.'
                      : d['status'] == 'COMPLETED'
                      ? '${d['isTie'] == true
                            ? 'Draw'
                            : d['winnerId'] == Get.find<AuthController>().currentUser.value?.id
                            ? 'You won'
                            : 'Your friend won'} · 10 XP for each player'
                      : 'Practice duel in progress',
                ),
                const SizedBox(height: 12),
                Text(
                  '${d['smartPicks'] == true ? '5 picks for each player’s weak topics' : 'Selected live topics'} · ${d['timerEnabled'] == true ? '60 seconds per question' : 'No question timer'}',
                ),
                for (final note in d['selectionNotes']) ...[
                  const SizedBox(height: 8),
                  Text(note),
                ],
                for (final session in d['sessions'])
                  ListTile(
                    title: Text(
                      session['userId'] == d['requester']['id']
                          ? d['requester']['name']
                          : d['recipient']['name'],
                    ),
                    subtitle: Text(
                      '${session['status']} · ${session['correctCount']} correct',
                    ),
                    trailing: Text('${session['xpAwarded']} XP'),
                  ),
                if (d['status'] == 'ACTIVE' && own?['status'] == 'ACTIVE')
                  FilledButton(
                    onPressed: busy ? null : openSession,
                    child: const Text('Resume duel'),
                  ),
                if (d['status'] == 'ACTIVE' && own?['status'] == 'COMPLETED')
                  const Text(
                    'You finished. Waiting for your friend to complete the same ten questions.',
                  ),
                if (pending &&
                    d['requester']['id'] !=
                        Get.find<AuthController>().currentUser.value?.id)
                  FilledButton(
                    onPressed: busy ? null : accept,
                    child: const Text('Accept duel'),
                  ),
                if (pending || d['status'] == 'ACTIVE')
                  TextButton(
                    onPressed: busy ? null : leave,
                    child: Text(
                      pending
                          ? d['requester']['id'] ==
                                    Get.find<AuthController>()
                                        .currentUser
                                        .value
                                        ?.id
                                ? 'Cancel invitation'
                                : 'Reject invitation'
                          : 'Leave duel (no reward)',
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
