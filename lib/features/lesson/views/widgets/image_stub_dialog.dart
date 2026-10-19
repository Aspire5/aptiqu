import 'package:flutter/material.dart';
import '../../../../core/theme/appearance_theme.dart';
import '../../../../core/theme/aptiqu_tokens.dart';

class ImageStubDialog {
  static Future<void> show(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AppearanceTheme(
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Scan work · Coming soon'),
          content: Text(
            'Scanning handwritten work is not available yet. Use the answer choices or type your response.',
            style: context.type.bodyLarge,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
