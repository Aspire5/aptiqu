import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';

/// Controller for Sign Up / Profile Completion Screen
class SignUpController extends GetxController {
  final AuthController authController = Get.find<AuthController>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  final Rxn<DateTime> dob = Rxn<DateTime>();
  final RxString selectedGender = ''.obs;
  final RxString selectedReligion = ''.obs;
  final RxString selectedCountry = 'India'.obs;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  final List<String> genders = ['Male', 'Female', 'Non-Binary', 'Prefer not to say'];
  final List<String> religions = [
    'Hinduism',
    'Islam',
    'Christianity',
    'Sikhism',
    'Buddhism',
    'Jainism',
    'Other / Agnostic',
    'Prefer not to say',
  ];
  final List<String> countries = [
    'India',
    'United States',
    'United Kingdom',
    'Canada',
    'Australia',
    'Singapore',
    'United Arab Emirates',
    'Germany',
    'France',
    'Japan',
  ];

  @override
  void onInit() {
    super.onInit();
    _populatePrefilledData();
  }

  void _populatePrefilledData() {
    final prefilled = authController.prefilledOnboarding;
    final user = authController.currentUser.value;

    final initialFirst = prefilled['firstName'] ?? user?.firstName ?? '';
    final initialLast = prefilled['lastName'] ?? user?.lastName ?? '';

    if (initialFirst.isNotEmpty && initialFirst != 'Cadet') {
      firstNameController.text = initialFirst;
    }
    if (initialLast.isNotEmpty) {
      lastNameController.text = initialLast;
    }

    if (user?.dob != null) dob.value = user!.dob;
    if (user != null && user.gender.isNotEmpty) selectedGender.value = user.gender;
    if (user != null && user.religion.isNotEmpty) selectedReligion.value = user.religion;
    if (user != null && user.country.isNotEmpty) selectedCountry.value = user.country;
  }

  @override
  void onClose() {
    firstNameController.dispose();
    lastNameController.dispose();
    super.onClose();
  }

  void setDob(DateTime date) {
    dob.value = date;
    errorMessage.value = '';
  }

  void setGender(String gender) {
    selectedGender.value = gender;
    errorMessage.value = '';
  }

  void setReligion(String religion) {
    selectedReligion.value = religion;
    errorMessage.value = '';
  }

  void setCountry(String country) {
    selectedCountry.value = country;
    errorMessage.value = '';
  }

  /// Validates all mandatory fields (frontend validation) before sending to backend
  Future<bool> submit() async {
    errorMessage.value = '';

    // 1. Mandatory First Name validation
    if (firstNameController.text.trim().isEmpty) {
      errorMessage.value = 'First name is mandatory. Please enter your name.';
      return false;
    }

    // 2. Mandatory Second / Last Name validation
    if (lastNameController.text.trim().isEmpty) {
      errorMessage.value = 'Second / Last name is mandatory. Please enter your surname.';
      return false;
    }

    // 3. Mandatory Date of Birth validation
    if (dob.value == null) {
      errorMessage.value = 'Date of birth is mandatory. Please select your birth date.';
      return false;
    }

    // 4. Mandatory Gender validation
    if (selectedGender.value.isEmpty) {
      errorMessage.value = 'Gender is mandatory. Please select one of the options.';
      return false;
    }

    // 5. Mandatory Religion validation
    if (selectedReligion.value.isEmpty) {
      errorMessage.value = 'Religion / belief preference is mandatory.';
      return false;
    }

    // 6. Mandatory Country validation
    if (selectedCountry.value.isEmpty) {
      errorMessage.value = 'Country is mandatory.';
      return false;
    }

    isLoading.value = true;
    try {
      final success = await authController.completeRegistration(
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        dob: dob.value!,
        gender: selectedGender.value,
        religion: selectedReligion.value,
        country: selectedCountry.value,
      );

      if (!success) {
        errorMessage.value = authController.authErrorMessage.value.isNotEmpty
            ? authController.authErrorMessage.value
            : 'Failed to complete profile. Please verify your details.';
      }

      return success;
    } finally {
      isLoading.value = false;
    }
  }
}
