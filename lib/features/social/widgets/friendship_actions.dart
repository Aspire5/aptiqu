import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../social_controller.dart';
import 'social_widgets.dart';

/// One friendship control for search results, requests and learner profiles.
class FriendshipActions extends StatefulWidget {
  final Map<String, dynamic> person;
  final Future<void> Function() onChanged;
  final bool allowRemove;
  const FriendshipActions({
    super.key,
    required this.person,
    required this.onChanged,
    this.allowRemove = false,
  });

  @override
  State<FriendshipActions> createState() => _FriendshipActionsState();
}

class _FriendshipActionsState extends State<FriendshipActions> {
  bool busy = false;

  Future<void> update({bool accept = true}) async {
    if (busy) return;
    final social = Get.find<SocialController>();
    final person = widget.person;
    final relation = person['relation'];
    if (relation == 'FRIEND') {
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove friend?'),
          content: Text('Remove ${person['name']} from your friends?'),
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
      if (remove != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      if (relation == 'INCOMING') {
        await social.respondToFriend(person, accept: accept);
      } else if (relation == 'FRIEND') {
        await social.api.removeFriend(person['id']);
      } else {
        await social.api.post('friends/${person['id']}/invite');
      }
      if (mounted) await widget.onChanged();
      await social.syncInbox();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update this request. Refresh and try again.',
            ),
          ),
        );
        await widget.onChanged();
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relation = widget.person['relation'];
    if (relation == 'INCOMING') {
      return Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          SocialButton(
            key: const ValueKey('accept-request'),
            label: 'Accept',
            loading: busy,
            onPressed: busy ? null : update,
          ),
          SocialButton(
            key: const ValueKey('reject-request'),
            label: 'Reject',
            secondary: true,
            onPressed: busy ? null : () => update(accept: false),
          ),
        ],
      );
    }
    return SocialButton(
      key: const ValueKey('friendship-action'),
      label: relation == 'FRIEND'
          ? (widget.allowRemove ? 'Remove friend' : 'Friends')
          : relation == 'INVITED'
          ? 'Request sent'
          : 'Add Friend',
      secondary: relation == 'FRIEND' || relation == 'INVITED',
      loading: busy,
      onPressed:
          busy ||
              relation == 'INVITED' ||
              (relation == 'FRIEND' && !widget.allowRemove)
          ? null
          : update,
    );
  }
}
