import 'package:flutter/material.dart';
import '../../../core/theme/aptiqu_tokens.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';
import '../../../shared/widgets/layout/text_fit.dart';

class SocialSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlighted;
  final double radius;
  const SocialSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.highlighted = false,
    this.radius = 16,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(radius),
    child: Padding(padding: padding, child: child),
  );
}

class LearnerAvatar extends StatelessWidget {
  final Map<String, dynamic> person;
  final double radius;
  final bool highlighted, squared, showPresence;
  const LearnerAvatar({
    super.key,
    required this.person,
    this.radius = 24,
    this.highlighted = false,
    this.squared = false,
    this.showPresence = false,
  });
  @override
  Widget build(BuildContext context) {
    final name = (person['name'] as String? ?? 'Learner').trim();
    final url = person['avatarUrl'] as String?;
    final fallback = Center(
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: context.type.titleLarge?.copyWith(
          color: context.colors.onPrimaryContainer,
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(squared ? 16 : radius),
                child: ColoredBox(
                  color: context.colors.primaryContainer,
                  child: url == null || url.isEmpty
                      ? fallback
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => fallback,
                        ),
                ),
              ),
            ),
            if (showPresence && person['online'] is bool)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: person['online'] == true
                        ? context.status.success
                        : context.colors.onSurfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(color: context.colors.surface, width: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, loading, expanded;
  final IconData? icon;
  const SocialButton({
    super.key,
    required this.label,
    this.onPressed,
    this.secondary = false,
    this.loading = false,
    this.expanded = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final button = AptiquButton(
      label: label,
      onPressed: onPressed,
      isLoading: loading,
      variant: secondary
          ? AptiquButtonVariant.outline
          : AptiquButtonVariant.primary,
      icon: icon == null ? null : Icon(icon, size: 20),
    );
    return expanded ? button : IntrinsicWidth(child: button);
  }
}

/// Identity and relationship action are separate native activation targets.
class LearnerTile extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  final Widget? actions;
  final String? detail;
  final bool picker;
  const LearnerTile({
    super.key,
    required this.person,
    required this.onTap,
    this.actions,
    this.detail,
    this.picker = false,
  });
  @override
  Widget build(BuildContext context) => SocialSurface(
    padding: const EdgeInsets.all(12),
    child: LayoutBuilder(
      builder: (context, box) {
        final name = person['name']?.toString() ?? 'Learner';
        final actionLabel = person['relation'] == 'INVITED'
            ? 'Request sent'
            : picker
            ? 'Invite'
            : 'Add Friend';
        final inline =
            actions != null &&
            person['relation'] != 'INCOMING' &&
            textFits(context, actionLabel, context.type.labelLarge!, 80) &&
            box.maxWidth > 260 &&
            textFits(
              context,
              name,
              context.type.titleSmall!,
              box.maxWidth - 184,
              maxLines: 2,
            );
        final identity = Semantics(
          label: picker ? 'Invite friend' : 'View learner profile',
          child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              foregroundColor: context.colors.onSurface,
            ),
            child: LayoutBuilder(
              builder: (context, identityBox) {
                final beside = textFits(
                  context,
                  name,
                  context.type.titleSmall!,
                  identityBox.maxWidth - 60,
                  maxLines: 2,
                );
                final details = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: context.type.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${person['level'] ?? 1}${person['relation'] == 'FRIEND' ? ' · ${person['online'] == true
                                ? 'Online'
                                : person['online'] == false
                                ? 'Offline'
                                : 'Status unavailable'}' : ''}',
                      style: context.type.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: context.type.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                );
                return beside
                    ? Row(
                        children: [
                          LearnerAvatar(person: person),
                          const SizedBox(width: 12),
                          Expanded(child: details),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LearnerAvatar(person: person),
                          const SizedBox(height: 12),
                          details,
                        ],
                      );
              },
            ),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: identity),
                if (inline) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: 112, child: actions),
                ],
              ],
            ),
            if (actions != null && !inline) ...[
              const SizedBox(height: 12),
              actions!,
            ],
          ],
        );
      },
    ),
  );
}

class SocialEmptyState extends StatelessWidget {
  final IconData icon;
  final String title, message;
  const SocialEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: context.colors.primary),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.type.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: context.type.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
