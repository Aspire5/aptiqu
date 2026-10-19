import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/appearance_theme.dart';
import '../../core/theme/aptiqu_tokens.dart';
import '../../shared/widgets/feedback/app_state_view.dart';
import '../../shared/widgets/questions/question_presentation.dart';
import 'widgets/social_profile_chrome.dart';
import 'friend_profile_screen.dart';
import 'friend_requests_screen.dart';
import 'social_api.dart';
import 'social_controller.dart';
import 'widgets/friendship_actions.dart';
import 'widgets/social_widgets.dart';

export 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final bool picker, embedded;
  const FriendsScreen({super.key, this.picker = false, this.embedded = false});
  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final api = SocialApi();
  final social = Get.find<SocialController>();
  List<Map<String, dynamic>> items = [];
  final cursors = <String?>[null];
  String? nextCursor;
  String query = '', error = '';
  bool get discover => query.isNotEmpty && !widget.picker;
  bool loading = false;
  CancelToken? cancellation;
  final listScroll = ScrollController();
  int sequence = 0;
  Timer? debounce;
  StreamSubscription? events;
  @override
  void initState() {
    super.initState();
    load();
    events = social.events.stream.listen((data) {
      if (data['event'] == 'INBOX_CHANGED' || data['event'] == 'RECONNECTED') {
        load();
      }
      if (data['event'] == 'PRESENCE' && mounted) {
        final presence = {
          for (final row in data['items']) row['id']: row['online'],
        };
        setState(() {
          items = items
              .map(
                (r) => {
                  ...r,
                  if (presence.containsKey(r['id']))
                    'online': presence[r['id']],
                },
              )
              .toList();
        });
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    cancellation?.cancel();
    events?.cancel();
    listScroll.dispose();
    social.watchFriends([]);
    super.dispose();
  }

  Future<void> load() async {
    debounce?.cancel();
    cancellation?.cancel();
    cancellation = CancelToken();
    final request = ++sequence;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final result = await api.get(discover ? 'search' : 'friends', {
        'q': query,
        if (!discover && cursors.last != null) 'cursor': cursors.last,
      }, cancellation);
      if (!mounted || request != sequence) return;
      setState(() {
        items = (result['items'] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        nextCursor = result['nextCursor'];
      });
      social.watchFriends(
        items
            .where((r) => r['relation'] == 'FRIEND')
            .map((r) => r['id'] as String)
            .toList(),
      );
    } catch (_) {
      if (mounted && request == sequence) {
        setState(() => error = 'Could not load learners. Please try again.');
      }
    } finally {
      if (mounted && request == sequence) setState(() => loading = false);
    }
  }

  void search(String value) {
    debounce?.cancel();
    cancellation?.cancel();
    ++sequence; // Invalidate immediately, including the debounce interval.
    setState(() {
      query = value.trim();
      items = [];
      error = '';
      nextCursor = null;
      loading = query.isNotEmpty;
      cursors
        ..clear()
        ..add(null);
    });
    social.watchFriends([]);
    if (listScroll.hasClients) listScroll.jumpTo(0);
    if (query.isEmpty) {
      load();
      return;
    }
    debounce = Timer(const Duration(milliseconds: 350), load);
  }

  String friendLabel(Map<String, dynamic> p) {
    final date = DateTime.tryParse(p['friendsSince'] ?? '');
    return date == null
        ? 'Friend'
        : 'Friends since ${DateFormat('d MMM yyyy').format(date.toUtc().add(const Duration(hours: 5, minutes: 30)))}';
  }

  Future<void> profile(Map<String, dynamic> person) async {
    if (widget.picker) {
      Navigator.pop(context, person);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FriendProfileScreen(id: person['id'])),
    );
    if (mounted) await load();
  }

  Widget _inbox(BuildContext context) => Obx(() {
    final count = social.friendInvites.length;
    return IconButton(
      key: const ValueKey('friend-requests-inbox'),
      tooltip: count == 0
          ? 'Friend requests'
          : '$count pending friend requests',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.mail_outline_rounded),
      ),
      onPressed: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
        if (mounted) load();
      },
    );
  });

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Scaffold(
      appBar: widget.embedded
          ? null
          : SocialPageAppBar(
              title: widget.picker ? 'Invite a friend' : 'Friends',
              toolbarHeight: SocialPageAppBar.height(
                context,
                title: widget.picker ? 'Invite a friend' : 'Friends',
                trailing: !widget.picker,
              ),
              trailing: widget.picker ? null : _inbox(context),
            ),
      body: SafeArea(
        top: widget.embedded,
        bottom: !widget.embedded,
        child: RefreshIndicator(
          onRefresh: () async {
            await load();
            await social.syncInbox();
          },
          child: CustomScrollView(
            controller: listScroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.embedded)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Friends',
                                style: context.type.titleLarge,
                              ),
                            ),
                            _inbox(context),
                          ],
                        ),
                      TextField(
                        key: const ValueKey('friend-search'),
                        onChanged: search,
                        textInputAction: TextInputAction.search,
                        style: context.type.bodyLarge,
                        decoration: InputDecoration(
                          labelText: widget.picker
                              ? 'Search friends'
                              : 'Search learners',
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: widget.picker
                              ? 'Search friends by name'
                              : 'Search by name or email',
                        ),
                      ),
                      if (!widget.picker)
                        Obx(
                          () => social.activeDuelId.isEmpty
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.sports_kabaddi),
                                    title: const Text('Your friendly duel'),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push(
                                      '/friendly-duel/${social.activeDuelId.value}?play=1',
                                    ),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 4,
                  child: loading
                      ? Semantics(
                          liveRegion: true,
                          label: 'Loading learners',
                          child: ExcludeSemantics(
                            child: LinearProgressIndicator(
                              value: MediaQuery.disableAnimationsOf(context)
                                  ? .7
                                  : null,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              if (error.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: items.isEmpty
                        ? AppStateView(
                            title: 'Could not load learners',
                            actionLabel: 'Retry',
                            onAction: load,
                          )
                        : SessionNotice(message: error, onRetry: load),
                  ),
                ),
              if (items.isEmpty && !loading && error.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: SocialEmptyState(
                      icon: discover
                          ? Icons.person_search_outlined
                          : Icons.people_outline_rounded,
                      title: discover
                          ? 'No learners found'
                          : widget.picker && query.isNotEmpty
                          ? 'No friends found'
                          : 'Learn better together',
                      message: discover
                          ? 'Try another name or email.'
                          : widget.picker
                          ? query.isNotEmpty
                                ? 'Try another friend’s name.'
                                : 'Add friends to invite them to a duel.'
                          : 'Find your people. Search for a name or email above.',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverList.builder(
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final p = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LearnerTile(
                        key: ValueKey(p['id']),
                        person: p,
                        picker: widget.picker,
                        detail: p['relation'] == 'FRIEND'
                            ? friendLabel(p)
                            : null,
                        onTap: () => profile(p),
                        actions: widget.picker
                            ? SocialButton(
                                label: 'Invite',
                                onPressed: () => profile(p),
                              )
                            : p['relation'] == 'FRIEND'
                            ? null
                            : FriendshipActions(person: p, onChanged: load),
                      ),
                    );
                  },
                ),
              ),
              if (!discover && (cursors.length > 1 || nextCursor != null))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          key: const ValueKey('previous-friends-page'),
                          tooltip: 'Previous page',
                          onPressed: cursors.length > 1 && !loading
                              ? () {
                                  cursors.removeLast();
                                  if (listScroll.hasClients) {
                                    listScroll.jumpTo(0);
                                  }
                                  load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Semantics(
                          label: 'Page ${cursors.length}',
                          child: ExcludeSemantics(
                            child: Text(
                              '${cursors.length}',
                              style: context.type.bodyMedium,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('next-friends-page'),
                          tooltip: 'Next page',
                          onPressed: nextCursor != null && !loading
                              ? () {
                                  cursors.add(nextCursor);
                                  if (listScroll.hasClients) {
                                    listScroll.jumpTo(0);
                                  }
                                  load();
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
