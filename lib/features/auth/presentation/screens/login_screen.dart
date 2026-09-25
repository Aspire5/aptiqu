import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/background/cyber_ambient_background.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import '../controllers/auth_controller.dart';

/// Screen 1: Login Screen (Google OAuth)
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      body: CyberAmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Brand Tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AptiquColors.surfaceContainerHigh.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AptiquColors.primaryContainer.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AptiquColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'NEXT-GEN AI REASONING TUTOR',
                            style: AptiquTypography.labelCapsBold.copyWith(
                              fontSize: 9,
                              color: AptiquColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Center Hero Section: Mascot Hologram + App Title
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mascot Holographic Ring
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ambient Pulsing Glow Rings
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AptiquColors.primaryContainer.withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: AptiquColors.primaryContainer.withValues(alpha: 0.3),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 108,
                          height: 108,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [
                                AptiquColors.surfaceContainerHigh,
                                AptiquColors.surface,
                              ],
                            ),
                            border: Border.all(
                              color: AptiquColors.primaryContainer,
                              width: 2.0,
                            ),
                            boxShadow: AptiquColors.primaryGlow,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.psychology_rounded,
                              size: 56,
                              color: AptiquColors.secondary,
                            ),
                          ),
                        ),
                        // Small orbiting cyber badge
                        Positioned(
                          bottom: 4,
                          right: 14,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AptiquColors.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AptiquColors.secondary,
                                width: 1.5,
                              ),
                              boxShadow: AptiquColors.secondaryGlow,
                            ),
                            child: const Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: AptiquColors.tertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // App Title
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.white, AptiquColors.primary],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ).createShader(bounds),
                      child: Text(
                        'Aptiqu',
                        style: AptiquTypography.displayHero.copyWith(
                          fontSize: 42,
                          letterSpacing: -1.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'Master Aptitude & Logical Reasoning\nPowered by Adaptive AI',
                      textAlign: TextAlign.center,
                      style: AptiquTypography.bodyMd.copyWith(
                        color: AptiquColors.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),

                // Bottom Login Actions
                Obx(() {
                  final isLoading = authController.isLoading.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Error banner if any
                      if (authController.authErrorMessage.value.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authController.authErrorMessage.value,
                                  style: AptiquTypography.bodySm.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Google Sign In (Primary OAuth)
                      AptiquButton.google(
                        label: 'Continue with Google',
                        isLoading: isLoading,
                        width: double.infinity,
                        onPressed: () async {
                          final success = await authController.signInWithGoogle();
                          if (success && context.mounted) {
                            if (authController.isRegistrationComplete) {
                              context.go(AppRoutes.home);
                            } else {
                              context.go(AppRoutes.signup);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Sandbox Button for Desktop/Simulator testing with live backend
                      Row(
                        children: [
                          Expanded(
                            child: AptiquButton.outline(
                              label: 'Sandbox (New)',
                              height: 40,
                              fontSize: 11.5,
                              onPressed: () async {
                                final success = await authController.signInWithSandbox(isNewUser: true);
                                if (success && context.mounted) {
                                  context.go(AppRoutes.signup);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AptiquButton.outline(
                              label: 'Sandbox (Shagun)',
                              height: 40,
                              fontSize: 11.5,
                              onPressed: () async {
                                final success = await authController.signInWithSandbox(isNewUser: false);
                                if (success && context.mounted) {
                                  if (authController.isRegistrationComplete) {
                                    context.go(AppRoutes.home);
                                  } else {
                                    context.go(AppRoutes.signup);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Terms & Policy
                      Text(
                        'By continuing, you agree to our Terms of Service & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: AptiquTypography.bodySm.copyWith(
                          fontSize: 10.5,
                          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
