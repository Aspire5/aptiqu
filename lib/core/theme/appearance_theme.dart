import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'appearance_controller.dart';
import 'aptiqu_theme.dart';

/// Keeps standalone presentation surfaces and overlays on the saved appearance.
class AppearanceTheme extends StatelessWidget {
  final WidgetBuilder builder;
  const AppearanceTheme({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    final appearance = Get.isRegistered<AppearanceController>()
        ? Get.find<AppearanceController>()
        : Get.put(AppearanceController());
    final platform = MediaQuery.platformBrightnessOf(context);
    return Obx(() {
      final mode = appearance.mode.value;
      final brightness = mode == ThemeMode.system
          ? platform
          : mode == ThemeMode.light
          ? Brightness.light
          : Brightness.dark;
      final theme = brightness == Brightness.light
          ? AptiquTheme.lightTheme
          : AptiquTheme.darkTheme;
      return Theme(
        data: theme,
        child: Builder(
          builder: (context) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: AptiquTheme.systemBars(
              brightness,
              theme.scaffoldBackgroundColor,
            ),
            child: builder(context),
          ),
        ),
      );
    });
  }
}
