import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/theme/appearance_controller.dart';
import '../../../../shared/widgets/layout/text_fit.dart';

class AppearanceSetting extends StatelessWidget {
  const AppearanceSetting({super.key});
  @override
  Widget build(BuildContext context) {
    final appearance = Get.find<AppearanceController>();
    final theme = Theme.of(context);
    final type = theme.textTheme;
    const choices = [
      (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
      (ThemeMode.light, 'Light', Icons.light_mode_outlined),
      (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    ];
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Semantics(
                header: true,
                child: Text('Appearance', style: type.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  appearance.mode.value == ThemeMode.system
                      ? 'System (Default)'
                      : appearance.mode.value == ThemeMode.light
                      ? 'Light'
                      : 'Dark',
                  style: type.labelMedium!.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final segmentWidth = constraints.maxWidth / 3;
              final showIcons = choices.every(
                (choice) => textFits(
                  context,
                  choice.$2,
                  type.bodyLarge!,
                  segmentWidth - 52,
                ),
              );
              final oneRow = choices.every(
                (choice) => textFits(
                  context,
                  choice.$2,
                  type.bodyLarge!,
                  segmentWidth - 24,
                ),
              );
              Widget label(ThemeMode value, String name) => Text(
                name,
                key: ValueKey('appearance-${value.name}'),
                semanticsLabel: value == ThemeMode.system
                    ? 'System (Default)'
                    : name,
              );
              if (oneRow) {
                return SegmentedButton<ThemeMode>(
                  expandedInsets: EdgeInsets.zero,
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    textStyle: WidgetStatePropertyAll(type.bodyLarge),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainer,
                    ),
                    minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    ),
                  ),
                  segments: [
                    for (final choice in choices)
                      ButtonSegment(
                        value: choice.$1,
                        label: label(choice.$1, choice.$2),
                        icon: showIcons ? Icon(choice.$3, size: 20) : null,
                        tooltip: choice.$1 == ThemeMode.system
                            ? 'System (Default)'
                            : choice.$2,
                      ),
                  ],
                  selected: {appearance.mode.value},
                  onSelectionChanged: (values) =>
                      appearance.setMode(values.single),
                );
              }
              // Large text can wrap whole native choices without truncating labels.
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in choices)
                    ChoiceChip(
                      label: label(choice.$1, choice.$2),
                      selected: appearance.mode.value == choice.$1,
                      labelStyle: type.bodyLarge!.copyWith(
                        color: appearance.mode.value == choice.$1
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      onSelected: (_) => appearance.setMode(choice.$1),
                    ),
                ],
              );
            },
          ),
          if (appearance.saveError.value != null) ...[
            const SizedBox(height: 8),
            Semantics(
              liveRegion: true,
              child: Text(
                appearance.saveError.value!,
                style: type.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => appearance.setMode(appearance.mode.value),
                child: const Text('Retry saving'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
