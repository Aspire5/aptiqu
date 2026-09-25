import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'core/bindings/initial_binding.dart';
import 'core/routing/app_router.dart';
import 'core/theme/aptiqu_colors.dart';
import 'core/theme/aptiqu_theme.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style to dark cyber theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AptiquColors.surfaceDim,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize Global GetX Dependencies
  InitialBinding().dependencies();

  // Check 7-day persistent session on launch
  final authController = Get.find<AuthController>();
  await authController.checkInitialAuth();

  runApp(const AptiquApp());
}

class AptiquApp extends StatelessWidget {
  const AptiquApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aptiqu',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AptiquTheme.darkTheme,
      routerConfig: AppRouter.router,
    );
  }
}
