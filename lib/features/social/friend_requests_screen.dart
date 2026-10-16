import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/indicators/app_loader.dart';
import 'friend_profile_screen.dart';
import 'social_controller.dart';
import 'widgets/friendship_actions.dart';
import 'widgets/social_widgets.dart';
import 'widgets/social_profile_chrome.dart';
import 'widgets/friend_request_card.dart';
import '../../core/theme/aptiqu_colors.dart';
import '../../core/theme/aptiqu_typography.dart';

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
    appBar: SocialPageAppBar(
      title: 'Friend requests',
      trailing: Obx(() {
        final count = social.friendInvites.length;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: AptiquColors.primaryContainer.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AptiquColors.primaryContainer.withValues(alpha: .25),
            ),
          ),
          child: Text(
            '$count pending',
            style: AptiquTypography.bodySm.copyWith(
              color: AptiquColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }),
    ),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FriendRequestCard(
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
                              fullWidth: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (invitations.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverToBoxAdapter(
                        child: SocialSurface(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AptiquColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Add friends to learn together and invite each other to friendly duels. Tap a learner to view their profile.',
                                  style: AptiquTypography.bodySm.copyWith(
                                    fontSize: 11,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
