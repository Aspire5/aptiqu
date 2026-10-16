import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/aptiqu_colors.dart';
import '../../shared/widgets/indicators/app_loader.dart';
import 'friend_profile_screen.dart';
import 'friend_requests_screen.dart';
import 'social_api.dart';
import 'social_controller.dart';
import 'widgets/friendship_actions.dart';
import 'widgets/social_widgets.dart';

export 'friend_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  final bool picker;
  const FriendsScreen({super.key, this.picker = false});
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AptiquColors.surfaceDim,
    appBar: AppBar(
      title: Text(widget.picker ? 'Invite a friend' : 'Friends'),
      actions: [
        if (!widget.picker)
          Obx(() {
            final count = social.friendInvites.length;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                key: const ValueKey('friend-requests-inbox'),
                tooltip: count == 0
                    ? 'Friend requests'
                    : '$count pending friend requests',
                icon: Badge(
                  isLabelVisible: count > 0,
                  backgroundColor: AptiquColors.error,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.mail_outline_rounded),
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FriendRequestsScreen(),
                    ),
                  );
                  if (mounted) load();
                },
              ),
            );
          }),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            key: const ValueKey('friend-search'),
            onChanged: search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: widget.picker
                  ? 'Search friends by name'
                  : 'Search by name or email',
            ),
          ),
        ),
        if (!widget.picker)
          Obx(
            () => social.activeDuelId.isEmpty
                ? const SizedBox.shrink()
                : ListTile(
                    leading: const Icon(Icons.sports_kabaddi),
                    title: const Text('Your friendly duel'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(
                      '/friendly-duel/${social.activeDuelId.value}?play=1',
                    ),
                  ),
          ),
        if (loading) const Center(child: AppLoader()),
        if (error.isNotEmpty)
          ListTile(
            title: Text(error),
            trailing: TextButton(onPressed: load, child: const Text('Retry')),
          ),
        Expanded(
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
                if (items.isEmpty && !loading && error.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: SocialEmptyState(
                      icon: discover
                          ? Icons.person_search_outlined
                          : Icons.people_outline_rounded,
                      title: discover
                          ? 'No learners found'
                          : 'Learn better together',
                      message: discover
                          ? 'Try another name or email.'
                          : widget.picker
                          ? 'Add friends to invite them to a duel.'
                          : 'Find your people. Search for a name or email above.',
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, index) {
                      final p = items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LearnerTile(
                          key: ValueKey(p['id']),
                          person: p,
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
              ],
            ),
          ),
        ),
        if (!discover && (cursors.length > 1 || nextCursor != null))
          Padding(
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
                          if (listScroll.hasClients) listScroll.jumpTo(0);
                          load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Semantics(
                  label: 'Page ${cursors.length}',
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AptiquColors.surfaceContainerHigh,
                    child: Text(
                      '${cursors.length}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AptiquColors.primary,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('next-friends-page'),
                  tooltip: 'Next page',
                  onPressed: nextCursor != null && !loading
                      ? () {
                          cursors.add(nextCursor);
                          if (listScroll.hasClients) listScroll.jumpTo(0);
                          load();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
