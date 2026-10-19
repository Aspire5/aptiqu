import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aptiqu/core/routing/app_routes.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_tokens.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import 'package:aptiqu/shared/widgets/inputs/aptiqu_text_field.dart';
import 'package:aptiqu/shared/widgets/sheets/app_sheet.dart';
import '../controllers/signup_controller.dart';
import '../../../../shared/widgets/layout/text_fit.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final bool _ownsController;
  late final SignUpController _controller;
  final _form = GlobalKey<FormState>();
  final _anchors = List.generate(6, (_) => GlobalKey());
  final _focus = List.generate(6, (_) => FocusNode());
  final _serverError = GlobalKey();
  final _switchErrorAnchor = GlobalKey();
  bool _submitting = false, _switching = false, _switchDialogOpen = false;
  bool _validationAttempted = false;
  String? _switchError;

  @override
  void initState() {
    super.initState();
    _ownsController = !Get.isRegistered<SignUpController>();
    _controller = _ownsController
        ? Get.put(SignUpController())
        : Get.find<SignUpController>();
  }

  @override
  void dispose() {
    for (final node in _focus) {
      node.dispose();
    }
    if (_ownsController) Get.delete<SignUpController>();
    super.dispose();
  }

  Future<void> _reveal(GlobalKey key) async {
    final target = key.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      alignment: .15,
      duration: MediaQuery.disableAnimationsOf(target)
          ? Duration.zero
          : const Duration(milliseconds: 200),
    );
  }

  Future<void> _submit() async {
    if (_submitting || _switching) return;
    FocusScope.of(context).unfocus();
    setState(() => _validationAttempted = true);
    if (!_form.currentState!.validate()) {
      final invalid = [
        _controller.firstNameController.text.trim().isEmpty,
        _controller.lastNameController.text.trim().isEmpty,
        _controller.dob.value == null,
        _controller.selectedGender.value.isEmpty,
        _controller.selectedReligion.value.isEmpty,
        _controller.selectedCountry.value.isEmpty,
      ].indexOf(true);
      if (invalid >= 0) {
        await _reveal(_anchors[invalid]);
        if (mounted) _focus[invalid].requestFocus();
      }
      return;
    }
    _submitting = true;
    try {
      final success = await _controller.submit();
      if (!mounted) return;
      if (success) {
        context.go(AppRoutes.home);
      } else {
        await _reveal(_serverError);
      }
    } finally {
      _submitting = false;
    }
  }

  Future<void> _switchAccount() async {
    if (_controller.isLoading.value || _switching || _switchDialogOpen) return;
    _switchDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppearanceTheme(
        builder: (_) => AlertDialog(
          scrollable: true,
          title: const Text('Use a different account?'),
          content: const Text(
            'This signs you out. Details entered on this form will be cleared.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Switch account'),
            ),
          ],
        ),
      ),
    );
    _switchDialogOpen = false;
    if (confirmed != true || !mounted) return;
    setState(() {
      _switching = true;
      _switchError = null;
    });
    try {
      await _controller.authController.logout();
      if (mounted) context.go(AppRoutes.login);
    } catch (_) {
      if (mounted) {
        setState(
          () => _switchError = 'Could not switch accounts. Please try again.',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _reveal(_switchErrorAnchor);
        });
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppearanceTheme(
    builder: (context) => Obx(() {
      final busy = _controller.isLoading.value || _switching;
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _switchAccount();
        },
        child: Scaffold(
          appBar: AppBar(
            toolbarHeight: MediaQuery.textScalerOf(context).scale(22) > 30
                ? MediaQuery.textScalerOf(context).scale(22) * 2.5
                : kToolbarHeight,
            automaticallyImplyLeading: false,
            title: const Text('Complete profile'),
            actions: [
              IconButton(
                tooltip: 'Switch account',
                onPressed: busy ? null : _switchAccount,
                icon: const Icon(Icons.switch_account_outlined),
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Form(
                    key: _form,
                    autovalidateMode: _validationAttempted
                        ? AutovalidateMode.onUserInteraction
                        : AutovalidateMode.disabled,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_switchError != null) ...[
                            Semantics(
                              key: _switchErrorAnchor,
                              liveRegion: true,
                              child: Text(
                                _switchError!,
                                style: context.type.bodyMedium!.copyWith(
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_switching) ...[
                            Semantics(
                              liveRegion: true,
                              child: const Text('Signing out…'),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                'Step 2 of 2',
                                style: context.type.labelLarge!.copyWith(
                                  color: context.colors.primary,
                                ),
                              ),
                              Text(
                                'All fields required',
                                style: context.type.bodySmall!.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildNames(context, busy),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _anchors[2],
                            child: FormField<String>(
                              initialValue: _controller.dob.value
                                  ?.toIso8601String(),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Select your date of birth.'
                                  : null,
                              builder: (field) => _selector(
                                context,
                                label: 'Date of birth',
                                icon: Icons.calendar_today_outlined,
                                value: field.value == null
                                    ? 'Select your birth date'
                                    : DateFormat(
                                        'dd MMMM yyyy',
                                      ).format(DateTime.parse(field.value!)),
                                error: field.errorText,
                                focusNode: _focus[2],
                                busy: busy,
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  final now = DateTime.now();
                                  final first = DateTime(1960);
                                  final initial =
                                      _controller.dob.value ??
                                      DateTime(2003, 1, 1);
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: initial.isAfter(now)
                                        ? now
                                        : initial.isBefore(first)
                                        ? first
                                        : initial,
                                    firstDate: first,
                                    lastDate: now,
                                    builder: (_, child) => AppearanceTheme(
                                      builder: (themedContext) => Theme(
                                        data: Theme.of(themedContext).copyWith(
                                          datePickerTheme:
                                              Theme.of(
                                                themedContext,
                                              ).datePickerTheme.copyWith(
                                                headerHeadlineStyle:
                                                    themedContext
                                                        .type
                                                        .displaySmall!
                                                        .copyWith(
                                                          color: themedContext
                                                              .colors
                                                              .onSurface,
                                                        ),
                                              ),
                                        ),
                                        child: child!,
                                      ),
                                    ),
                                  );
                                  if (picked != null && mounted) {
                                    _controller.setDob(picked);
                                    field.didChange(picked.toIso8601String());
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _anchors[3],
                            child: FormField<String>(
                              initialValue: _controller.selectedGender.value,
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Select a gender option.'
                                  : null,
                              builder: (field) => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Gender',
                                    style: context.type.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (
                                        var i = 0;
                                        i < _controller.genders.length;
                                        i++
                                      )
                                        ChoiceChip(
                                          key: ValueKey(
                                            'gender-${_controller.genders[i]}',
                                          ),
                                          label: Text(_controller.genders[i]),
                                          selected:
                                              field.value ==
                                              _controller.genders[i],
                                          focusNode: i == 0 ? _focus[3] : null,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.padded,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          labelStyle: context.type.bodyLarge!
                                              .copyWith(
                                                color:
                                                    field.value ==
                                                        _controller.genders[i]
                                                    ? context
                                                          .colors
                                                          .onPrimaryContainer
                                                    : context.colors.onSurface,
                                              ),
                                          checkmarkColor:
                                              context.colors.onPrimaryContainer,
                                          onSelected: busy
                                              ? null
                                              : (_) {
                                                  _controller.setGender(
                                                    _controller.genders[i],
                                                  );
                                                  field.didChange(
                                                    _controller.genders[i],
                                                  );
                                                },
                                        ),
                                    ],
                                  ),
                                  if (field.hasError)
                                    _fieldError(context, field.errorText!),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildPreferences(context, busy),
                          const SizedBox(height: 24),
                          if (_controller.errorMessage.value.isNotEmpty) ...[
                            Semantics(
                              key: _serverError,
                              liveRegion: true,
                              child: Text(
                                _controller.errorMessage.value,
                                style: context.type.bodyMedium!.copyWith(
                                  color: context.colors.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          AptiquButton(
                            label: 'Complete profile',
                            isLoading: busy,
                            onPressed: _submit,
                            width: double.infinity,
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            onPressed: busy ? null : _switchAccount,
                            icon: const Icon(Icons.switch_account_outlined),
                            label: const Text('Use a different account'),
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
    }),
  );

  Widget _buildNames(BuildContext context, bool busy) => LayoutBuilder(
    builder: (context, constraints) {
      final first = KeyedSubtree(
        key: _anchors[0],
        child: AptiquTextField(
          controller: _controller.firstNameController,
          focusNode: _focus[0],
          enabled: !busy,
          label: 'First name',
          hintText: 'e.g. Asha',
          autofillHints: const [AutofillHints.givenName],
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focus[1].requestFocus(),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter your first name.'
              : null,
        ),
      );
      final last = KeyedSubtree(
        key: _anchors[1],
        child: AptiquTextField(
          controller: _controller.lastNameController,
          focusNode: _focus[1],
          enabled: !busy,
          label: 'Last name',
          hintText: 'e.g. Kumar',
          autofillHints: const [AutofillHints.familyName],
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) => _focus[2].requestFocus(),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Enter your last name.'
              : null,
        ),
      );
      final fieldWidth = (constraints.maxWidth - 16) / 2;
      final paired =
          fieldWidth >= 128 &&
          textFits(
            context,
            'First name',
            context.type.bodyMedium!,
            fieldWidth - 32,
          ) &&
          textFits(
            context,
            'Last name',
            context.type.bodyMedium!,
            fieldWidth - 32,
          ) &&
          textFits(
            context,
            'e.g. Kumar',
            context.type.bodyLarge!,
            fieldWidth - 32,
          );
      return paired
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: first),
                const SizedBox(width: 16),
                Expanded(child: last),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [first, const SizedBox(height: 16), last],
            );
    },
  );

  Widget _buildPreferences(BuildContext context, bool busy) => LayoutBuilder(
    builder: (context, constraints) {
      final belief = KeyedSubtree(
        key: _anchors[4],
        child: FormField<String>(
          initialValue: _controller.selectedReligion.value,
          validator: (value) =>
              value == null || value.isEmpty ? 'Select a belief option.' : null,
          builder: (field) => _selector(
            context,
            label: 'Religion / belief',
            icon: Icons.diversity_3_outlined,
            value: field.value?.isNotEmpty == true
                ? field.value!
                : 'Select a belief option',
            error: field.errorText,
            focusNode: _focus[4],
            busy: busy,
            onTap: () async {
              final selected = await _select(
                context,
                'Religion / belief',
                _controller.religions,
                field.value ?? '',
              );
              if (selected != null && mounted) {
                _controller.setReligion(selected);
                field.didChange(selected);
              }
            },
          ),
        ),
      );
      final country = KeyedSubtree(
        key: _anchors[5],
        child: FormField<String>(
          initialValue: _controller.selectedCountry.value,
          validator: (value) =>
              value == null || value.isEmpty ? 'Select your country.' : null,
          builder: (field) => _selector(
            context,
            label: 'Country',
            icon: Icons.public_outlined,
            value: field.value?.isNotEmpty == true
                ? field.value!
                : 'Select your country',
            error: field.errorText,
            focusNode: _focus[5],
            busy: busy,
            onTap: () async {
              final selected = await _select(
                context,
                'Country',
                _controller.countries,
                field.value ?? '',
              );
              if (selected != null && mounted) {
                _controller.setCountry(selected);
                field.didChange(selected);
              }
            },
          ),
        ),
      );
      final fieldWidth = (constraints.maxWidth - 16) / 2;
      final paired =
          fieldWidth >= 224 &&
          textFits(
            context,
            'Select a belief option',
            context.type.bodyLarge!,
            fieldWidth - 84,
          ) &&
          textFits(
            context,
            'United Arab Emirates',
            context.type.bodyLarge!,
            fieldWidth - 84,
          );
      return paired
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: belief),
                const SizedBox(width: 16),
                Expanded(child: country),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [belief, const SizedBox(height: 16), country],
            );
    },
  );

  Widget _fieldError(BuildContext context, String message) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: context.type.bodyMedium!.copyWith(color: context.colors.error),
      ),
    ),
  );

  Widget _selector(
    BuildContext context, {
    required String label,
    IconData? icon,
    required String value,
    required String? error,
    required FocusNode focusNode,
    required bool busy,
    required VoidCallback onTap,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(label, style: context.type.bodyMedium),
      const SizedBox(height: 8),
      OutlinedButton(
        focusNode: focusNode,
        onPressed: busy ? null : onTap,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
          side: error == null ? null : BorderSide(color: context.colors.error),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(value, style: context.type.bodyLarge)),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
      if (error != null) _fieldError(context, error),
    ],
  );

  Future<String?> _select(
    BuildContext context,
    String title,
    List<String> items,
    String selected,
  ) {
    FocusScope.of(context).unfocus();
    return showAppSheet<String>(
      context: context,
      title: title,
      builder: (context) => RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) {
          if (value != null) Navigator.of(context).pop(value);
        },
        child: Column(
          children: [
            for (final item in items)
              RadioListTile<String>(
                value: item,
                title: Text(item),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
