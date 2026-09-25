import 'package:flutter/material.dart';
import '../../../../core/theme/aptiqu_colors.dart';
import '../../../../core/theme/aptiqu_typography.dart';

class ImageStubDialog {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AptiquColors.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.camera_alt, color: AptiquColors.primary, size: 28),
            const SizedBox(width: 10),
            Text(
              'Scan Work',
              style: AptiquTypography.headlineSm.copyWith(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'Image-based evaluation is not integrated yet. Homework scanning and handwritten math evaluation will be enabled in a future release.',
          style: AptiquTypography.bodyMd.copyWith(color: AptiquColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: AptiquColors.primary)),
          ),
        ],
      ),
    );
  }
}
