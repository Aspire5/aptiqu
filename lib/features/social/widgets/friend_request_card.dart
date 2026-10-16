import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'social_profile_chrome.dart';
import 'social_widgets.dart';

class FriendRequestCard extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  final Widget actions;
  const FriendRequestCard({
    super.key,
    required this.person,
    required this.onTap,
    required this.actions,
  });

  String get requested {
    final date = DateTime.tryParse(
      person['friendshipVersion'] as String? ?? '',
    );
    if (date == null) return 'Wants to be your friend';
    final ist = date.toUtc().add(const Duration(hours: 5, minutes: 30));
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    final difference = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(ist.year, ist.month, ist.day)).inDays;
    if (difference == 0) return 'Requested today';
    if (difference == 1) return 'Requested yesterday';
    return 'Requested ${DateFormat('d MMM yyyy').format(ist)}';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    excludeFromSemantics: true,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: SocialSurface(
      highlighted: true,
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label:
                'View ${person['name']} profile, level ${person['level'] ?? 1}',
            onTap: onTap,
            child: ExcludeSemantics(
              child: SocialIdentityHeader(person: person, detail: requested),
            ),
          ),
          const SizedBox(height: 18),
          actions,
        ],
      ),
    ),
  );
}
