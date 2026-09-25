import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/aptiqu_colors.dart';
import 'package:aptiqu/core/theme/aptiqu_typography.dart';
import 'package:aptiqu/shared/widgets/background/cyber_ambient_background.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import 'package:aptiqu/shared/widgets/inputs/aptiqu_text_field.dart';
import '../controllers/signup_controller.dart';

/// Screen 2: Sign-Up & Profile Completion Screen
class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SignUpController());

    return Scaffold(
      backgroundColor: AptiquColors.surfaceDim,
      body: CyberAmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AptiquColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AptiquColors.outlineVariant),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        color: AptiquColors.onSurface,
                        onPressed: () => context.go(AppRoutes.login),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Profile',
                          style: AptiquTypography.headlineSm.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'CADET INITIALIZATION • LEVEL 1',
                          style: AptiquTypography.labelCaps.copyWith(
                            color: AptiquColors.secondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AptiquColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AptiquColors.outlineVariant),
                      ),
                      child: Text(
                        'STEP 2 / 2',
                        style: AptiquTypography.labelCapsBold.copyWith(
                          fontSize: 9.5,
                          color: AptiquColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: AptiquColors.outlineVariant, height: 1),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gamified Welcome Callout
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AptiquColors.primaryContainer.withValues(alpha: 0.15),
                              AptiquColors.surfaceContainer,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AptiquColors.primaryContainer.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AptiquColors.primaryContainer.withValues(alpha: 0.2),
                                border: Border.all(
                                  color: AptiquColors.primaryContainer,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                color: AptiquColors.tertiary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unlock +250 Coins Starter Bonus',
                                    style: AptiquTypography.bodyMd.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AptiquColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tell Aero AI a bit about yourself to personalize your reasoning drills.',
                                    style: AptiquTypography.bodySm.copyWith(
                                      color: AptiquColors.onSurfaceVariant,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Error message banner if any
                      Obx(() {
                        if (controller.errorMessage.value.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  controller.errorMessage.value,
                                  style: AptiquTypography.bodySm.copyWith(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // First Name & Second Name (Row)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AptiquTextField(
                              controller: controller.firstNameController,
                              label: 'FIRST NAME *',
                              hintText: 'e.g. Alex',
                              prefixIcon: const Icon(Icons.person_outline_rounded,
                                  size: 18, color: AptiquColors.secondary),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AptiquTextField(
                              controller: controller.lastNameController,
                              label: 'SECOND NAME *',
                              hintText: 'e.g. Kumar',
                              prefixIcon: const Icon(Icons.person_outline_rounded,
                                  size: 18, color: AptiquColors.secondary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Date of Birth
                      Obx(() {
                        final selectedDate = controller.dob.value;
                        final formattedDate = selectedDate != null
                            ? DateFormat('dd MMMM yyyy').format(selectedDate)
                            : '';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE OF BIRTH *',
                              style: AptiquTypography.labelCaps.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime(2003, 1, 1),
                                  firstDate: DateTime(1960),
                                  lastDate: now,
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: const ColorScheme.dark(
                                          primary: AptiquColors.primaryContainer,
                                          onPrimary: Colors.white,
                                          surface: AptiquColors.surfaceContainer,
                                          onSurface: AptiquColors.onSurface,
                                        ),
                                        dialogTheme: const DialogThemeData(
                                          backgroundColor: AptiquColors.surfaceContainer,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  controller.setDob(picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AptiquColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AptiquColors.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      size: 18,
                                      color: AptiquColors.secondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        formattedDate.isEmpty
                                            ? 'Select your birth date'
                                            : formattedDate,
                                        style: AptiquTypography.bodyMd.copyWith(
                                          color: formattedDate.isEmpty
                                              ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.5)
                                              : AptiquColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AptiquColors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 18),

                      // Gender (Pills Selector)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GENDER *',
                            style: AptiquTypography.labelCaps.copyWith(fontSize: 11),
                          ),
                          const SizedBox(height: 8),
                          Obx(() {
                            final currentGender = controller.selectedGender.value;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller.genders.map((gender) {
                                final isSelected = currentGender == gender;
                                return InkWell(
                                  onTap: () => controller.setGender(gender),
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AptiquColors.primaryContainer.withValues(alpha: 0.2)
                                          : AptiquColors.surfaceContainer,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AptiquColors.primaryContainer
                                            : AptiquColors.outlineVariant,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                      boxShadow: isSelected ? AptiquColors.primaryGlow : null,
                                    ),
                                    child: Text(
                                      gender,
                                      style: AptiquTypography.bodySm.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AptiquColors.onSurfaceVariant,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Religion
                      Obx(() {
                        final currentReligion = controller.selectedReligion.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'RELIGION / BELIEF *',
                              style: AptiquTypography.labelCaps.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showSelectionDialog(
                                context: context,
                                title: 'Select Religion / Belief',
                                items: controller.religions,
                                selected: currentReligion,
                                onSelected: (val) => controller.setReligion(val),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AptiquColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AptiquColors.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.account_balance_rounded,
                                      size: 18,
                                      color: AptiquColors.tertiary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        currentReligion.isEmpty
                                            ? 'Select religion or prefer not to say'
                                            : currentReligion,
                                        style: AptiquTypography.bodyMd.copyWith(
                                          color: currentReligion.isEmpty
                                              ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.5)
                                              : AptiquColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AptiquColors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 18),

                      // Country
                      Obx(() {
                        final currentCountry = controller.selectedCountry.value;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COUNTRY *',
                              style: AptiquTypography.labelCaps.copyWith(fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _showSelectionDialog(
                                context: context,
                                title: 'Select Country',
                                items: controller.countries,
                                selected: currentCountry,
                                onSelected: (val) => controller.setCountry(val),
                              ),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AptiquColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AptiquColors.outlineVariant),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.public_rounded,
                                      size: 18,
                                      color: AptiquColors.secondary,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        currentCountry.isEmpty
                                            ? 'Select country'
                                            : currentCountry,
                                        style: AptiquTypography.bodyMd.copyWith(
                                          color: currentCountry.isEmpty
                                              ? AptiquColors.onSurfaceVariant.withValues(alpha: 0.5)
                                              : AptiquColors.onSurface,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: AptiquColors.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 32),

                      // Submit Button
                      Obx(() {
                        return AptiquButton(
                          label: 'Initialize Aptiqu Journey',
                          isLoading: controller.isLoading.value,
                          width: double.infinity,
                          height: 52,
                          icon: const Icon(Icons.rocket_launch_rounded,
                              size: 18, color: Colors.white),
                          onPressed: () async {
                            final success = await controller.submit();
                            if (success && context.mounted) {
                              context.go(AppRoutes.home);
                            }
                          },
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSelectionDialog({
    required BuildContext context,
    required String title,
    required List<String> items,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: AptiquColors.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(
              top: BorderSide(color: AptiquColors.outlineVariant, width: 1.2),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AptiquColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                title,
                style: AptiquTypography.headlineSm.copyWith(
                  color: AptiquColors.onSurface,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: AptiquColors.outlineVariant, height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isCurrent = item == selected;

                    return ListTile(
                      dense: true,
                      title: Text(
                        item,
                        style: AptiquTypography.bodyMd.copyWith(
                          color: isCurrent
                              ? AptiquColors.primary
                              : AptiquColors.onSurface,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded,
                              color: AptiquColors.secondary, size: 20)
                          : null,
                      onTap: () {
                        onSelected(item);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
