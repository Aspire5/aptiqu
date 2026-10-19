import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../social_controller.dart';
import 'social_widgets.dart';
import '../../../core/theme/appearance_theme.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/layout/text_fit.dart';

/// One friendship control for search results, requests and learner profiles.
class FriendshipActions extends StatefulWidget {
  final Map<String, dynamic> person;
  final Future<void> Function() onChanged;
  final bool allowRemove;
  final bool fullWidth;
  const FriendshipActions({
    super.key,
    required this.person,
    required this.onChanged,
    this.allowRemove = false,
    this.fullWidth = false,
  });

  @override
  State<FriendshipActions> createState() => _FriendshipActionsState();
}

class _FriendshipActionsState extends State<FriendshipActions> {
  bool busy = false, confirming = false;

  Future<void> update({bool accept = true}) async {
    if (busy || confirming) return;
    final social = Get.find<SocialController>();
    final person = widget.person;
    final relation = person['relation'];
    if (relation == 'FRIEND') {
      confirming = true;
      final remove = await showDialog<bool>(
        context: context,
        builder: (_) => AppearanceTheme(
          builder: (context) => AlertDialog(
            scrollable: true,
            title: const Text('Remove friend?'),
            content: Text('Remove ${person['name']} from your friends?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ),
      );
      confirming = false;
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
      final accept = SocialButton(
        key: const ValueKey('accept-request'),
        label: 'Accept',
        icon: Icons.check_rounded,
        expanded: widget.fullWidth,
        loading: busy,
        onPressed: busy ? null : update,
      );
      final reject = SocialButton(
        key: const ValueKey('reject-request'),
        label: 'Reject',
        icon: Icons.close_rounded,
        expanded: widget.fullWidth,
        secondary: true,
        onPressed: busy ? null : () => update(accept: false),
      );
      if (widget.fullWidth) {
        return LayoutBuilder(
          builder: (context, box) {
            final width = (box.maxWidth - 12) / 2 - 60;
            final inline =
                textFits(context, 'Accept', context.type.labelLarge!, width) &&
                textFits(context, 'Reject', context.type.labelLarge!, width);
            return inline
                ? Row(
                    children: [
                      Expanded(child: accept),
                      const SizedBox(width: 12),
                      Expanded(child: reject),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [accept, const SizedBox(height: 12), reject],
                  );
          },
        );
      }
      return Wrap(spacing: 8, runSpacing: 4, children: [accept, reject]);
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
