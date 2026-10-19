import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/sheets/app_sheet.dart';

class VoiceStubSheet {
  static Future<void> show(BuildContext context) async {
    await showAppSheet<void>(
      context: context,
      title: 'Voice · Coming soon',
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Voice answers are not available yet. Use the answer choices or type your response.',
            style: context.type.bodyLarge,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
