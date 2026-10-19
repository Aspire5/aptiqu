import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/layout/text_fit.dart';
import 'social_widgets.dart';

class SocialPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? trailing;
  final bool centered;
  final double toolbarHeight;
  const SocialPageAppBar({
    super.key,
    required this.title,
    this.trailing,
    this.centered = false,
    this.toolbarHeight = 56,
  });
  static double height(
    BuildContext context, {
    String title = 'Friendly duel',
    bool trailing = false,
  }) {
    final width = MediaQuery.sizeOf(context).width - 88 - (trailing ? 64 : 0);
    final lines = textFits(context, title, context.type.titleLarge!, width)
        ? 1
        : textFits(context, title, context.type.titleLarge!, width, maxLines: 2)
        ? 2
        : 3;
    return (MediaQuery.textScalerOf(context).scale(22) * 1.25 * lines + 16)
        .clamp(56.0, double.infinity);
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
  @override
  Widget build(BuildContext context) => AppBar(
    toolbarHeight: toolbarHeight,
    title: Text(title),
    centerTitle: centered,
    actions: [
      if (trailing != null)
        Padding(padding: const EdgeInsets.only(right: 16), child: trailing!),
    ],
  );
}

class SocialLevelBadge extends StatelessWidget {
  final Object? level;
  const SocialLevelBadge({super.key, required this.level});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.colors.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      'Level ${level ?? 1}',
      style: context.type.labelMedium?.copyWith(
        color: context.colors.onPrimaryContainer,
      ),
    ),
  );
}

class SocialIconPanel extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  const SocialIconPanel({
    super.key,
    required this.icon,
    this.color,
    this.size = 32,
  });
  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size * .65,
    color: color ?? context.colors.onSurfaceVariant,
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final name = person['name']?.toString() ?? 'Learner';
      final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: profile ? context.type.titleLarge : context.type.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SocialLevelBadge(level: person['level']),
              if (profile && person['totalXp'] is num)
                Text('${person['totalXp']} XP', style: context.type.bodySmall),
            ],
          ),
          if (profile || detail != null) ...[
            const SizedBox(height: 8),
            Text(
              profile
                  ? person['online'] == true
                        ? 'Online now'
                        : person['online'] == false
                        ? 'Offline'
                        : 'Status unavailable'
                  : detail!,
              style: context.type.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
      final avatar = LearnerAvatar(
        person: person,
        radius: profile ? 32 : 24,
        squared: profile,
        showPresence: profile,
      );
      final inline =
          box.maxWidth >= 180 &&
          textFits(
            context,
            name,
            (profile ? context.type.titleLarge : context.type.titleSmall)!,
            box.maxWidth - (profile ? 78 : 62),
            maxLines: 2,
          );
      return inline
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(child: identity),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [avatar, const SizedBox(height: 16), identity],
            );
    },
  );
}
