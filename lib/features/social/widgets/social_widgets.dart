import 'package:flutter/material.dart';

import '../../../core/theme/aptiqu_colors.dart';
import '../../../core/theme/aptiqu_typography.dart';
import '../../../shared/widgets/buttons/aptiqu_button.dart';

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
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: AptiquColors.surfaceContainerLow,
      gradient: highlighted
          ? const LinearGradient(
              colors: [
                AptiquColors.surfaceContainer,
                AptiquColors.surfaceContainerLow,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AptiquColors.outlineVariant),
      boxShadow: highlighted
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: .18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
    ),
    child: child,
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
    if (highlighted) {
      final fallback = Center(
        child: Text(
          name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: AptiquTypography.headlineMd.copyWith(
            fontSize: radius * .85,
            color: Colors.white,
          ),
        ),
      );
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AptiquColors.socialAvatarStart,
                  AptiquColors.socialAvatarEnd,
                ],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
              borderRadius: BorderRadius.circular(squared ? 16 : radius),
              border: Border.all(
                color: AptiquColors.onSurface.withValues(alpha: .15),
              ),
              boxShadow: [
                BoxShadow(
                  color: AptiquColors.socialAvatarStart.withValues(alpha: .16),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: url == null || url.isEmpty
                ? fallback
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => fallback,
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
                      ? AptiquColors.success
                      : AptiquColors.onSurfaceDisabled,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AptiquColors.surfaceContainerLow,
                    width: 3,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AptiquColors.primaryContainer.withValues(alpha: .18),
      foregroundColor: AptiquColors.primary,
      foregroundImage: url == null || url.isEmpty ? null : NetworkImage(url),
      // Keep the initial visible if a remote image fails to load.
      onForegroundImageError: url == null || url.isEmpty ? null : (_, _) {},
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: AptiquTypography.headlineSm.copyWith(fontSize: radius * .8),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, loading;
  final bool expanded;
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
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null && !loading,
    label: label,
    onTap: loading ? null : onPressed,
    child: ExcludeSemantics(
      child: Opacity(
        opacity: onPressed == null && !loading ? .65 : 1,
        child: _width(
          AptiquButton(
            label: label,
            onPressed: onPressed,
            isLoading: loading,
            variant: secondary
                ? AptiquButtonVariant.outline
                : AptiquButtonVariant.primary,
            borderRadius: BorderRadius.circular(12),
            fontSize: 13,
            icon: icon == null
                ? null
                : Icon(
                    icon,
                    size: 16,
                    color: secondary
                        ? AptiquColors.onSurfaceVariant
                        : Colors.white,
                  ),
          ),
        ),
      ),
    ),
  );

  Widget _width(Widget child) =>
      expanded ? child : IntrinsicWidth(child: child);
}

class LearnerTile extends StatelessWidget {
  final Map<String, dynamic> person;
  final VoidCallback onTap;
  final Widget? actions;
  final String? detail;
  const LearnerTile({
    super.key,
    required this.person,
    required this.onTap,
    this.actions,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    excludeFromSemantics: true,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: SocialSurface(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked =
              person['relation'] == 'INCOMING' ||
              constraints.maxWidth < 270 ||
              MediaQuery.textScalerOf(context).scale(13) > 18;
          final identity = Semantics(
            button: true,
            label:
                'View ${person['name']} profile, level ${person['level'] ?? 1}',
            onTap: onTap,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Row(
                  children: [
                    LearnerAvatar(person: person),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person['name'] ?? 'Learner',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AptiquTypography.titleMedium.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Level ${person['level'] ?? 1}${person['relation'] == 'FRIEND' ? ' · ${person['online'] == true
                                      ? 'Online'
                                      : person['online'] == false
                                      ? 'Offline'
                                      : 'Status unavailable'}' : ''}',
                            style: AptiquTypography.bodySm.copyWith(
                              color: AptiquColors.onSurfaceVariant,
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail!,
                              style: AptiquTypography.bodySm.copyWith(
                                fontSize: 11,
                                color: AptiquColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: identity),
                  if (actions != null && !stacked) ...[
                    const SizedBox(width: 12),
                    SizedBox(width: 112, child: actions),
                  ],
                ],
              ),
              if (actions != null && stacked) ...[
                const SizedBox(height: 12),
                actions!,
              ],
            ],
          );
        },
      ),
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
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AptiquColors.primary),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AptiquTypography.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AptiquTypography.bodySm.copyWith(
              color: AptiquColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
