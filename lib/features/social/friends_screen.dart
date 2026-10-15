import 'social_overlay.dart';
import '../home/presentation/widgets/home_dashboard_view.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/aptiqu_colors.dart';
import '../home/models/home_dashboard_model.dart';
import 'social_api.dart';
import 'social_controller.dart';

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
  bool discover = false, loading = false;
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
    events?.cancel();
    social.watchFriends([]);
    super.dispose();
  }

  Future<void> load() async {
    final request = ++sequence;
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final result = await api.get(discover ? 'search' : 'friends', {
        'q': query,
        if (cursors.last != null) 'cursor': cursors.last,
      });
      if (!mounted || request != sequence) return;
      setState(() {
        items = (result['items'] as List)
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
        nextCursor = result['nextCursor'];
      });
      if (!discover) {
        social.watchFriends(items.map((r) => r['id'] as String).toList());
      } else {
        social.watchFriends([]);
      }
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
    debounce = Timer(const Duration(milliseconds: 350), () {
      query = value.trim();
      cursors
        ..clear()
        ..add(null);
      load();
    });
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
    appBar: AppBar(title: Text(widget.picker ? 'Invite a friend' : 'Friends')),
    body: Column(
      children: [
        if (!widget.picker)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('My friends')),
                ButtonSegment(value: true, label: Text('Find learners')),
              ],
              selected: {discover},
              onSelectionChanged: (values) {
                setState(() {
                  discover = values.first;
                  query = '';
                  items = [];
                  cursors
                    ..clear()
                    ..add(null);
                });
                load();
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            key: ValueKey(discover),
            onChanged: search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: discover
                  ? 'Search by name (2+ characters)'
                  : 'Search friends by name',
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
        if (!widget.picker)
          Obx(
            () => social.friendInvites.isEmpty
                ? const SizedBox.shrink()
                : ListTile(
                    title: Text(
                      '${social.friendInvites.length} friend invitations',
                    ),
                    trailing: const Icon(Icons.mail_outline),
                    onTap: () async {
                      final invitation = social.friendInvites.first;
                      await showDialog(
                        context: context,
                        builder: (_) =>
                            SocialInvitationDialog(invitation: invitation),
                      );
                      await social.syncInbox();
                    },
                  ),
          ),
        if (loading) const LinearProgressIndicator(),
        if (error.isNotEmpty)
          ListTile(
            title: Text(error),
            trailing: TextButton(onPressed: load, child: const Text('Retry')),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.isEmpty && !loading ? 1 : items.length,
              itemBuilder: (_, index) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      discover && query.length < 2
                          ? 'Enter a name to find learners.'
                          : 'No matching friends or learners yet.',
                    ),
                  );
                }
                final p = items[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: p['avatarUrl'] == null
                        ? null
                        : NetworkImage(p['avatarUrl']),
                    child: p['avatarUrl'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(p['name']),
                  subtitle: Text(
                    'Level ${p['level']} · ${p['online'] == true
                        ? 'Online'
                        : p['online'] == false
                        ? 'Offline'
                        : 'Status unavailable'}',
                  ),
                  trailing: widget.picker
                      ? const Icon(Icons.person_add_alt_1)
                      : Text(
                          p['relation'] == 'INVITED'
                              ? 'Invited'
                              : p['relation'] == 'FRIEND'
                              ? 'Friend'
                              : 'View profile',
                        ),
                  onTap: () => profile(p),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: cursors.length > 1 && !loading
                    ? () {
                        cursors.removeLast();
                        load();
                      }
                    : null,
                child: const Text('Previous'),
              ),
              TextButton(
                onPressed: nextCursor != null && !loading
                    ? () {
                        cursors.add(nextCursor);
                        load();
                      }
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class FriendProfileScreen extends StatefulWidget {
  final String id;
  const FriendProfileScreen({super.key, required this.id});
  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  final api = SocialApi();
  Map<String, dynamic>? person;
  String error = '';
  StreamSubscription? profileEvents;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
    profileEvents = Get.find<SocialController>().events.stream.listen((event) {
      if (event['event'] == 'INBOX_CHANGED' ||
          event['event'] == 'RECONNECTED') {
        load();
      }
      if (event['event'] == 'PRESENCE' && person != null && mounted) {
        final row = (event['items'] as List)
            .where((r) => r['id'] == widget.id)
            .firstOrNull;
        if (row != null) {
          setState(() => person = {...person!, 'online': row['online']});
        }
      }
    });
  }

  @override
  void dispose() {
    profileEvents?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await api.get('profiles/${widget.id}');
      if (mounted) {
        setState(() {
          person = p;
          error = '';
        });
        Get.find<SocialController>().watchFriends(
          p['relation'] == 'FRIEND' ? [widget.id] : [],
        );
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Could not load this profile.');
    }
  }

  Future<void> action() async {
    if (busy || person == null) return;
    setState(() => busy = true);
    try {
      if (person!['relation'] == 'FRIEND') {
        final remove = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Remove friend?'),
            content: const Text('You can invite this learner again later.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );
        if (remove != true) return;
        await api.removeFriend(widget.id);
      } else if (person!['relation'] == 'INCOMING') {
        await api.post(
          'friend-invitations/${person!['friendshipId']}/respond',
          {'accept': true, 'version': person!['friendshipVersion']},
        );
      } else {
        await api.post('friends/${widget.id}/invite');
      }
      await load();
      await Get.find<SocialController>().syncInbox();
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not update this friendship. Please refresh and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      appBar: AppBar(title: const Text('Learner profile')),
      body: p == null
          ? Center(
              child: error.isEmpty
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: load, child: Text(error)),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  p['name'],
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  'Level ${p['level']} · ${p['totalXp']} XP\nCurrent streak ${p['currentStreak']} days · Best ${p['highestStreak']} days\n${p['coins']} coins · ${p['online'] == true
                      ? 'Online'
                      : p['online'] == false
                      ? 'Offline'
                      : 'Status unavailable'}',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy || p['relation'] == 'INVITED' ? null : action,
                  child: Text(
                    busy
                        ? 'Updating…'
                        : p['relation'] == 'FRIEND'
                        ? 'Remove friend'
                        : p['relation'] == 'INVITED'
                        ? 'Invited'
                        : p['relation'] == 'INCOMING'
                        ? 'Accept invitation'
                        : 'Add friend',
                  ),
                ),
                if (error.isNotEmpty)
                  Text(
                    error,
                    style: const TextStyle(color: AptiquColors.error),
                  ),
                const SizedBox(height: 24),
                const Text('Performance'),
                Text(
                  '${p['performance']['correct']} correct / ${p['performance']['attempted']} submitted',
                ),
                Text(
                  p['performance']['accuracy'] == null
                      ? 'No accuracy results yet'
                      : 'Accuracy ${(p['performance']['accuracy'] * 100).round()}%',
                ),
                Text(
                  p['performance']['averageSolveTimeMs'] == null
                      ? 'No timed results yet'
                      : 'Average correct time ${(p['performance']['averageSolveTimeMs'] / 1000).toStringAsFixed(1)} seconds',
                ),
                const SizedBox(height: 20),
                const Text('Learning activity'),
                const SizedBox(height: 12),
                ActivityCalendar(
                  days: [
                    for (final row in p['activity'])
                      HomeActivityDay.fromJson(Map<String, dynamic>.from(row)),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('By difficulty'),
                for (final row in p['difficulty'])
                  ListTile(
                    title: Text(row['difficulty']),
                    subtitle: Text(
                      '${row['correct']} correct / ${row['attempted']} submitted',
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Achievements'),
                for (final b in p['badges'])
                  ListTile(
                    title: Text(b['title']),
                    subtitle: Text(b['description']),
                    trailing: Text(
                      b['unlocked'] == true
                          ? 'Earned'
                          : '${b['progress']} / ${b['target']}',
                    ),
                  ),
                const SizedBox(height: 20),
                const Text('Latest ranked match'),
                Text(
                  p['ranked'] == null
                      ? 'No completed ranked matches'
                      : '${p['ranked']['result']} · ${p['ranked']['correct']} correct',
                ),
              ],
            ),
    );
  }
}
