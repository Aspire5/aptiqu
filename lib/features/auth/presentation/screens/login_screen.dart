import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/background/cyber_ambient_background.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import '../controllers/auth_controller.dart';

/// Screen 1: Clean, Premium Authentication Screen (Google OAuth)
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
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Core App Identity: Logo & Typography
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: const Color(0xFF131722),
                    border: Border.all(
                      color: AptiquColors.buttonDarkBorder,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/small_logo.jpeg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Brand Name
                Text(
                  'AptiQu',
                  style: GoogleFonts.outfit(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),

                // Purpose Tagline
                Text(
                  'Master Aptitude & Logical Reasoning',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: AptiquColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 28),

                // Product Highlights Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141824),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AptiquColors.outlineVariant.withValues(alpha: 0.7),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildFeatureBullet('Roadmaps'),
                      _buildDividerDot(),
                      _buildFeatureBullet('Quick Drills'),
                      _buildDividerDot(),
                      _buildFeatureBullet('Ranked Duels'),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Google Authentication CTA Section
                Obx(() {
                  final isLoading = authController.isLoading.value;
                  final errorMessage = authController.authErrorMessage.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Contextual Error Banner
                      if (errorMessage.isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  errorMessage,
                                  style: AptiquTypography.bodySm.copyWith(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Primary Google Sign In Button
                      AptiquButton.google(
                        label: 'Continue with Google',
                        isLoading: isLoading,
                        height: 50,
                        borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(height: 20),

                      // Terms and Privacy Notice
                      Text(
                        'By continuing, you agree to our Terms of Service & Privacy Policy',
                        textAlign: TextAlign.center,
                        style: AptiquTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AptiquColors.onSurfaceVariant.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white70,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildDividerDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Container(
        width: 3.5,
        height: 3.5,
        decoration: const BoxDecoration(
          color: AptiquColors.outlineVariant,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
