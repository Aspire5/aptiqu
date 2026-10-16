import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/indicators/app_loader.dart';
import 'friend_profile_screen.dart';
import 'social_controller.dart';
import 'widgets/friendship_actions.dart';
import 'widgets/social_widgets.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});
  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  final social = Get.find<SocialController>();
  bool loading = true;
  String? error;
  StreamSubscription? events;
  int sequence = 0;

  @override
  void initState() {
    super.initState();
    load();
    events = social.events.stream.listen((event) {
      if (event['event'] == 'INBOX_CHANGED' ||
          event['event'] == 'RECONNECTED') {
        load();
      }
    });
  }

  Future<void> load() async {
    final request = ++sequence;
    try {
      final inbox = await social.api.get('inbox');
      if (!mounted || request != sequence) return;
      social.friendInvites.assignAll(
        (inbox['friends'] as List).map((row) => Map<String, dynamic>.from(row)),
      );
      setState(() {
        loading = false;
        error = null;
      });
    } catch (_) {
      if (mounted && request == sequence) {
        setState(() {
          loading = false;
          error = 'Could not load friend requests.';
        });
      }
    }
  }

  @override
  void dispose() {
    events?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friend requests')),
    body: Column(
      children: [
        if (loading) const AppLoader(),
        if (error != null)
          TextButton.icon(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            label: Text('$error Retry'),
          ),
        Expanded(
          child: Obx(() {
            final invitations = social.friendInvites.toList();
            return RefreshIndicator(
              onRefresh: load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (invitations.isEmpty && !loading && error == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: SocialEmptyState(
                        icon: Icons.mark_email_read_outlined,
                        title: 'You’re all caught up',
                        message: 'New friend requests will appear here.',
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.builder(
                      itemCount: invitations.length,
                      itemBuilder: (context, index) {
                        final invitation = invitations[index];
                        final person = <String, dynamic>{
                          ...Map<String, dynamic>.from(invitation['sender']),
                          'relation': 'INCOMING',
                          'friendshipId': invitation['id'],
                          'friendshipVersion': invitation['version'],
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LearnerTile(
                            key: ValueKey(invitation['id']),
                            person: person,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FriendProfileScreen(id: person['id']),
                                ),
                              );
                              if (mounted) load();
                            },
                            actions: FriendshipActions(
                              person: person,
                              onChanged: load,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    ),
  );
}
