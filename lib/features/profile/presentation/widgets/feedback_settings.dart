import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/feedback/feedback_cue.dart';
import '../../../../core/feedback/feedback_preferences.dart';
import '../../../../core/theme/aptiqu_tokens.dart';
import '../../../../shared/widgets/layout/text_fit.dart';

class FeedbackSettings extends StatelessWidget {
  const FeedbackSettings({super.key});
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<FeedbackPreferences>()) {
      return const SizedBox.shrink();
    }
    final preferences = Get.find<FeedbackPreferences>();
    const choices = [
      (TimerAudio.off, 'Off'),
      (TimerAudio.lastTen, 'Last 10 seconds'),
      (TimerAudio.full, 'Full'),
    ];
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Sound & Haptics', style: context.type.titleMedium),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sound effects'),
            value: preferences.sounds.value,
            onChanged: preferences.setSounds,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Haptic feedback'),
            value: preferences.haptics.value,
            onChanged: preferences.setHaptics,
          ),
          const SizedBox(height: 8),
          Text('Timer audio', style: context.type.bodyLarge),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              final fits = choices.every(
                (c) => textFits(
                  context,
                  c.$2,
                  context.type.labelLarge!,
                  box.maxWidth / 3 - 24,
                ),
              );
              if (fits) {
                return SegmentedButton<TimerAudio>(
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                  ),
                  segments: [
                    for (final c in choices)
                      ButtonSegment(value: c.$1, label: Text(c.$2)),
                  ],
                  selected: {preferences.timerAudio.value},
                  onSelectionChanged: (values) =>
                      preferences.setTimerAudio(values.single),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in choices)
                    ChoiceChip(
                      label: Text(c.$2),
                      selected: preferences.timerAudio.value == c.$1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      onSelected: (_) => preferences.setTimerAudio(c.$1),
                    ),
                ],
              );
            },
          ),
          if (preferences.saveError.value != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                preferences.saveError.value!,
                style: context.type.bodyMedium?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () =>
                    preferences.setSounds(preferences.sounds.value),
                child: const Text('Retry saving'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
