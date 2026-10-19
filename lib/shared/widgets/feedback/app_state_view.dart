import 'package:flutter/material.dart';
import '../indicators/app_loader.dart';

/// Presentation only: the caller chooses loading, empty or error and recovery.
class AppStateView extends StatelessWidget {
  final String title;
  final String? message, actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  const AppStateView({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) const AppLoader(),
        if (loading) const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
