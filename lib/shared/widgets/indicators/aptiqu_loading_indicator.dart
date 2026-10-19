import 'package:flutter/material.dart';

/// A themed busy state; reduced motion uses a static arc instead of rotation.
class AptiquLoadingIndicator extends StatelessWidget {
  final double size;
  final String? message;
  const AptiquLoadingIndicator({super.key, this.size = 48, this.message});
  @override
  Widget build(BuildContext context) => Semantics(
    label: message ?? 'Loading',
    excludeSemantics: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: size < 24 ? 2 : 3,
            color: Theme.of(context).colorScheme.primary,
            value: MediaQuery.disableAnimationsOf(context) ? .7 : null,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 12),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    ),
  );
}
