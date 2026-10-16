import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import 'social_widgets.dart';

class SocialPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final bool centered;
  const SocialPageAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.centered = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: 72,
    centerTitle: centered,
    titleSpacing: 4,
    leadingWidth: 72,
    leading: Padding(
      padding: const EdgeInsets.only(left: 16, right: 8),
      child: Center(
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
          style: IconButton.styleFrom(
            foregroundColor: AptiquColors.onSurface,
            backgroundColor: AptiquColors.surfaceContainerLow,
            side: const BorderSide(color: AptiquColors.outlineVariant),
            shape: const CircleBorder(),
            minimumSize: const Size(48, 48),
          ),
        ),
      ),
    ),
    title: Text(
      title,
      maxLines: 2,
      style: AptiquTypography.headlineSm.copyWith(fontSize: 17),
    ),
    actions: [
      if (trailing != null)
        Padding(padding: const EdgeInsets.only(right: 16), child: trailing!)
      else if (centered)
        const SizedBox(width: 72),
    ],
  );
}

class SocialLevelBadge extends StatelessWidget {
  final Object? level;
  const SocialLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AptiquColors.primaryContainer.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: AptiquColors.primaryContainer.withValues(alpha: .25),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 12, color: AptiquColors.tertiary),
        const SizedBox(width: 4),
        Text(
          'Level ${level ?? 1}',
          style: AptiquTypography.bodySm.copyWith(
            color: AptiquColors.primary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class SocialIconPanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const SocialIconPanel({
    super.key,
    required this.icon,
    this.color = AptiquColors.onSurfaceVariant,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: .12)),
    ),
    child: Icon(icon, size: size * .5, color: color),
  );
}

class SocialIdentityHeader extends StatelessWidget {
  final Map<String, dynamic> person;
  final bool profile;
  final String? detail;
  const SocialIdentityHeader({
    super.key,
    required this.person,
    this.profile = false,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      LearnerAvatar(
        person: person,
        radius: profile ? 32 : 26,
        highlighted: true,
        squared: profile,
        showPresence: profile,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              person['name'] ?? 'Learner',
              style: AptiquTypography.headlineSm.copyWith(
                fontSize: profile ? 19 : 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 5,
              children: [
                SocialLevelBadge(level: person['level']),
                if (profile && person['totalXp'] is num)
                  Text(
                    '${person['totalXp']} XP',
                    style: AptiquTypography.bodySm,
                  ),
              ],
            ),
            if (profile || detail != null) ...[
              const SizedBox(height: 6),
              Text(
                profile
                    ? person['online'] == true
                          ? 'Online now'
                          : person['online'] == false
                          ? 'Offline'
                          : 'Status unavailable'
                    : detail!,
                style: AptiquTypography.bodySm.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
