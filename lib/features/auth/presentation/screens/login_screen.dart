import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import '../controllers/auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) {
      final auth = Get.find<AuthController>();
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/small_logo.jpeg',
                                width: 88,
                                height: 88,
                                excludeFromSemantics: true,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.school_outlined,
                                  size: 64,
                                  color: context.colors.primary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Semantics(
                            header: true,
                            child: Text(
                              'AptiQu',
                              textAlign: TextAlign.center,
                              style: context.type.displaySmall!.copyWith(
                                fontSize: 36,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Build your aptitude and reasoning skills, one step at a time.',
                            textAlign: TextAlign.center,
                            style: context.type.bodyLarge,
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 16,
                            runSpacing: 8,
                            children: [
                              for (final label in [
                                'Roadmaps',
                                'Quick drills',
                                'Ranked duels',
                              ])
                                Text(
                                  label,
                                  style: context.type.bodyMedium!.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 40),
                          Obx(
                            () => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (auth.authErrorMessage.value.isNotEmpty) ...[
                                  Semantics(
                                    liveRegion: true,
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: context.colors.errorContainer,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color:
                                                context.colors.onErrorContainer,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              auth.authErrorMessage.value,
                                              style: context.type.bodyMedium!
                                                  .copyWith(
                                                    color: context
                                                        .colors
                                                        .onErrorContainer,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                                AptiquButton.google(
                                  label: 'Continue with Google',
                                  isLoading: auth.isLoading.value,
                                  width: double.infinity,
                                  onPressed: () async {
                                    final success = await auth
                                        .signInWithGoogle();
                                    if (success && context.mounted) {
                                      context.go(
                                        auth.isRegistrationComplete
                                            ? AppRoutes.home
                                            : AppRoutes.signup,
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'By continuing, you agree to our Terms of Service and Privacy Policy.',
                            textAlign: TextAlign.center,
                            style: context.type.bodyMedium!.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Product URLs are not supplied yet. Keep these honestly
                          // unavailable rather than inventing legal destinations.
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: [
                              for (final label in [
                                'Terms of Service',
                                'Privacy Policy',
                              ])
                                TextButton(
                                  onPressed: null,
                                  style: TextButton.styleFrom(
                                    disabledForegroundColor:
                                        context.colors.onSurfaceVariant,
                                  ),
                                  child: Text(label),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
