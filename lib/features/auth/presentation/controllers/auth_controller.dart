import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import '../../domain/models/user_model.dart';

/// Global Authentication & Profile State Controller (GetX)
class AuthController extends GetxController {
  final DioClient dioClient = Get.find<DioClient>();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '365489251624-l0i9mk40qvujvemb36qqhcodgvc1a462.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final RxString authErrorMessage = ''.obs;

  // Prefilled onboarding info from Google
  final RxMap<String, String> prefilledOnboarding = <String, String>{}.obs;

  bool get isLoggedIn => currentUser.value != null;
  bool get isRegistrationComplete =>
      currentUser.value?.isRegistrationComplete ?? false;

  @override
  void onInit() {
    super.onInit();
    dioClient.onSessionExpired = logout;
  }

  /// Checks if stored 7-day session exists and restores user profile on app start
  Future<String?> checkInitialAuth() async {
    isInitializing.value = true;
    try {
      final refreshToken = await dioClient.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return null;
      }

      // Fetch live user profile from backend
      final response = await dioClient.dio.get('/user/profile');
      if (response.statusCode == 200 && response.data['success'] == true) {
        final profileData = response.data['data'];
        currentUser.value = UserModel.fromJson(profileData);
        return currentUser.value?.isRegistrationComplete == true
            ? 'home'
            : 'signup';
      }
    } catch (_) {
      await dioClient.clearTokens();
    } finally {
      isInitializing.value = false;
    }
    return null;
  }

  /// Sign In with Google OAuth (Real Google Sign-In SDK)
  Future<bool> signInWithGoogle() async {
    isLoading.value = true;
    authErrorMessage.value = '';
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled dialog
        isLoading.value = false;
        return false;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken == null) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      return await _authenticateWithBackend(idToken);
    } catch (e) {
      authErrorMessage.value = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sandbox Google Login for instant testing without native Play Services
  Future<bool> signInWithSandbox({bool isNewUser = false}) async {
    isLoading.value = true;
    authErrorMessage.value = '';
    try {
      final mockToken = isNewUser
          ? 'mock_test_token_new_${DateTime.now().millisecondsSinceEpoch}'
          : 'mock_test_token_shagun_kumar';

      return await _authenticateWithBackend(mockToken);
    } catch (e) {
      authErrorMessage.value = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Internal method to exchange Google ID Token with Node.js backend
  Future<bool> _authenticateWithBackend(String idToken) async {
    final response = await dioClient.dio.post(
      '/auth/google',
      data: {'idToken': idToken},
    );

    if (response.statusCode == 200 && response.data['success'] == true) {
      final data = response.data['data'];
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final isRegComplete = data['isRegistrationComplete'] == true;

      // 1. Store 7-day tokens securely
      await dioClient.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      // 2. Extract profile and game stats
      final profile = data['profile'];
      final stats = data['stats'];
      final user = data['user'];

      currentUser.value = UserModel(
        id: user['id'],
        email: user['email'],
        firstName: profile?['firstName'] ?? '',
        lastName: profile?['lastName'] ?? '',
        dob: profile?['dob'] != null ? DateTime.tryParse(profile['dob']) : null,
        gender: profile?['gender'] ?? '',
        religion: profile?['religion'] ?? '',
        country: profile?['country'] ?? '',
        avatarUrl: profile?['avatarUrl'] ?? '',
        level: stats?['level'] ?? 1,
        // Streak hardcoded to 0 for now as requested
        streak: stats?['streak']?.toString() ?? '0d',
        // Coins hardcoded to 0 for now as requested
        coins: stats?['coins'] ?? 0,
        isRegistrationComplete: isRegComplete,
      );

      // 3. Cache pre-filled onboarding data if profile is not yet completed
      if (!isRegComplete) {
        prefilledOnboarding.value = {
          'firstName': profile?['firstName'] ?? '',
          'lastName': profile?['lastName'] ?? '',
          'avatarUrl': profile?['avatarUrl'] ?? '',
          'email': user['email'] ?? '',
        };
      }

      return true;
    } else {
      throw Exception(response.data['message'] ?? 'Authentication failed');
    }
  }

  /// Complete Sign Up / Registration Profile via Backend
  Future<bool> completeRegistration({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
    required String religion,
    required String country,
  }) async {
    isLoading.value = true;
    authErrorMessage.value = '';
    try {
      final response = await dioClient.dio.post(
        '/auth/onboarding',
        data: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'dob': dob.toIso8601String(),
          'gender': gender,
          'religion': religion,
          'country': country,
          'avatarUrl': currentUser.value?.avatarUrl ?? '',
        },
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        final profile = data['profile'];
        final stats = data['stats'];

        currentUser.value = currentUser.value?.copyWith(
          firstName: profile['firstName'],
          lastName: profile['lastName'],
          dob: DateTime.tryParse(profile['dob']),
          gender: profile['gender'],
          religion: profile['religion'],
          country: profile['country'],
          avatarUrl: profile['avatarUrl'],
          level: stats['level'] ?? 1,
          streak: stats['streak']?.toString() ?? '0d',
          coins: stats['coins'] ?? 0,
          isRegistrationComplete: true,
        );

        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Onboarding failed');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data['message'] != null) {
        authErrorMessage.value = e.response?.data['message'];
      } else {
        authErrorMessage.value = 'Failed to submit onboarding profile.';
      }
      return false;
    } catch (e) {
      authErrorMessage.value = e.toString().replaceAll('Exception: ', '');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Sign Out
  Future<void> logout() async {
    try {
      final refreshToken = await dioClient.getRefreshToken();
      if (refreshToken != null) {
        await dioClient.dio.post('/auth/logout', data: {'refreshToken': refreshToken});
      }
    } catch (_) {}
    await dioClient.clearTokens();
    currentUser.value = null;
    prefilledOnboarding.clear();
  }
}
