import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routing/app_router.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/appearance_theme.dart';
import '../../core/theme/aptiqu_tokens.dart';
import '../../shared/widgets/buttons/aptiqu_button.dart';
import '../../shared/widgets/feedback/app_state_view.dart';
import '../../shared/widgets/questions/question_presentation.dart';
import 'widgets/social_widgets.dart';
import 'widgets/social_profile_chrome.dart';
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
  bool confirming = false;
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

  Future<void> confirmLeave(
    BuildContext context, {
    bool fromBack = false,
  }) async {
    if (busy || confirming) return;
    final expected = duel?['status'];
    final requester =
        duel?['requester']['id'] ==
        Get.find<AuthController>().currentUser.value?.id;
    final pending = expected == 'PENDING';
    if (!pending && expected != 'ACTIVE') return;
    confirming = true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            pending
                ? requester
                      ? 'Cancel invitation?'
                      : 'Reject invitation?'
                : 'Leave friendly duel?',
          ),
          content: Text(
            pending
                ? requester
                      ? 'Going back cancels your invitation to this friend.'
                      : 'Going back rejects this invitation.'
                : 'Leaving before both players finish ends this duel with no reward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
                foregroundColor: context.colors.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                pending
                    ? requester
                          ? 'Cancel invitation'
                          : 'Reject invitation'
                    : 'Leave duel',
              ),
            ),
          ],
        ),
      ),
    );
    confirming = false;
    if (!mounted || proceed != true) return;
    // A live update may have changed the consequence while the dialog was open.
    if (duel?['status'] != expected) return;
    await leave();
    if (fromBack && mounted && duel?['status'] != 'PENDING' && error == null) {
      Navigator.of(this.context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) {
      final d = duel;
      final seconds = ((remaining - elapsed.elapsedMilliseconds) / 1000)
          .ceil()
          .clamp(0, 60);
      final me = Get.find<AuthController>().currentUser.value?.id;
      final own = d == null
          ? null
          : (d['sessions'] as List).where((s) => s['userId'] == me).firstOrNull;
      final pending = d?['status'] == 'PENDING';
      final requester = d?['requester']['id'] == me;
      return PopScope(
        canPop: !pending && !busy,
        onPopInvokedWithResult: (popped, _) {
          if (!popped && pending && !busy) {
            confirmLeave(context, fromBack: true);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: SocialPageAppBar.height(context),
            title: const Text('Friendly duel'),
            leading: IconButton(
              tooltip: 'Back',
              onPressed: busy
                  ? null
                  : () {
                      if (pending) {
                        confirmLeave(context, fromBack: true);
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          body: SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (d == null)
                    AppStateView(
                      title: error == null
                          ? 'Loading friendly duel'
                          : 'Could not load this duel',
                      message: error,
                      loading: error == null,
                      actionLabel: error == null ? null : 'Retry',
                      onAction: error == null ? null : load,
                    ),
                  if (d != null) ...[
                    if (error != null)
                      SessionNotice(message: error!, onRetry: load),
                    SocialSurface(
                      child: SessionMetrics(
                        items: [
                          (
                            label: d['requester']['id'] == me
                                ? 'You'
                                : 'Challenger',
                            value: '${d['requester']['name']}',
                          ),
                          (
                            label: d['recipient']['id'] == me
                                ? 'You'
                                : 'Friend',
                            value: '${d['recipient']['name']}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      pending
                          ? requester
                                ? 'Waiting for your friend'
                                : 'You’re invited to a duel'
                          : _outcome(d, me),
                      style: context.type.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (pending)
                      Text(
                        '$seconds seconds ${requester ? 'to respond' : 'to accept or reject'}',
                        style: context.type.bodyLarge,
                      ),
                    if (d['status'] == 'EXPIRED')
                      Text(
                        'The invitation expired after 60 seconds.',
                        style: context.type.bodyLarge,
                      ),
                    if (d['status'] == 'ABANDONED')
                      Text(
                        'The duel ended before both players finished. No XP was awarded.',
                        style: context.type.bodyLarge,
                      ),
                    if (d['status'] == 'ACTIVE' &&
                        own?['status'] == 'COMPLETED')
                      Text(
                        'You finished. Waiting for your friend to complete the same ten questions.',
                        style: context.type.bodyLarge,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      '10 questions · ${d['timerEnabled'] == true ? '60 seconds per question' : 'No question timer'}',
                      style: context.type.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      d['smartPicks'] == true
                          ? '5 questions from each player’s weaker topics.'
                          : 'Selected live topics',
                      style: context.type.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    for (final note in d['selectionNotes'] ?? []) ...[
                      const SizedBox(height: 8),
                      Text('$note', style: context.type.bodyMedium),
                    ],
                    const SizedBox(height: 16),
                    if (pending || d['status'] == 'ACTIVE')
                      Text(
                        '10 XP each when both finish. No Ranked rewards.',
                        style: context.type.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 24),
                    for (final session in d['sessions'])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              session['userId'] == d['requester']['id']
                                  ? '${d['requester']['name']}'
                                  : '${d['recipient']['name']}',
                              style: context.type.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Text(
                                  _status(session['status']),
                                  style: context.type.bodyMedium,
                                ),
                                Text(
                                  '${session['correctCount']} correct',
                                  style: context.type.bodyMedium,
                                ),
                                Text(
                                  '${session['xpAwarded']} XP awarded',
                                  style: context.type.bodyMedium,
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                          ],
                        ),
                      ),
                    if (d['status'] == 'ACTIVE' && own?['status'] == 'ACTIVE')
                      AptiquButton(
                        label: busy ? 'Opening duel…' : 'Resume duel',
                        isLoading: busy,
                        onPressed: busy ? null : openSession,
                      ),
                    if (pending && !requester)
                      AptiquButton(
                        label: busy ? 'Responding…' : 'Accept duel',
                        isLoading: busy,
                        onPressed: busy ? null : accept,
                      ),
                    if (pending || d['status'] == 'ACTIVE')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: OutlinedButton(
                          onPressed: busy
                              ? null
                              : pending
                              ? leave
                              : () => confirmLeave(context),
                          child: Text(
                            pending
                                ? requester
                                      ? 'Cancel invitation'
                                      : 'Reject invitation'
                                : 'Leave duel (no reward)',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  String _outcome(Map<String, dynamic> d, String? me) => switch (d['status']) {
    'EXPIRED' => 'Invitation expired',
    'REJECTED' => 'Invitation declined',
    'CANCELLED' => 'Invitation cancelled',
    'ABANDONED' => 'Duel ended',
    'COMPLETED' =>
      d['isTie'] == true
          ? 'Draw'
          : d['winnerId'] == null
          ? 'Duel complete'
          : d['winnerId'] == me
          ? 'You won'
          : 'Your friend won',
    _ => 'Duel in progress',
  };
  String _status(Object? value) => switch (value) {
    'ACTIVE' => 'In progress',
    'COMPLETED' => 'Completed',
    'ABANDONED' => 'Abandoned',
    'PENDING' => 'Waiting',
    _ => '$value',
  };
}
