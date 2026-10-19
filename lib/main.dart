import 'features/social/social_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/bindings/initial_binding.dart';
import 'core/routing/app_router.dart';
import 'core/theme/aptiqu_theme.dart';
import 'core/theme/appearance_controller.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // Initialize Global GetX Dependencies
  InitialBinding().dependencies();

  await Get.find<AppearanceController>().load();

  // Check 7-day persistent session on launch
  final authController = Get.find<AuthController>();
  await authController.checkInitialAuth();

  final appearance = Get.find<AppearanceController>();
  final mode = appearance.mode.value;
  final brightness = mode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness
      : mode == ThemeMode.light
      ? Brightness.light
      : Brightness.dark;
  final theme = brightness == Brightness.light
      ? AptiquTheme.lightTheme
      : AptiquTheme.darkTheme;
  SystemChrome.setSystemUIOverlayStyle(
    AptiquTheme.systemBars(brightness, theme.scaffoldBackgroundColor),
  );
  runApp(const AptiquApp());
}

class AptiquApp extends StatelessWidget {
  const AptiquApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appearance = Get.find<AppearanceController>();
    return Obx(
      () => MaterialApp.router(
        title: 'Aptiqu',
        debugShowCheckedModeBanner: false,
        themeMode: appearance.mode.value,
        themeAnimationDuration: Duration.zero,
        theme: AptiquTheme.lightTheme,
        darkTheme: AptiquTheme.darkTheme,
        routerConfig: AppRouter.router,
        scaffoldMessengerKey: AppRouter.messengerKey,
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AptiquTheme.systemBars(
            Theme.of(context).brightness,
            Theme.of(context).scaffoldBackgroundColor,
          ),
          child: SocialOverlay(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
