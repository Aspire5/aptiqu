import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';

class AccountPickerGoogle extends GoogleSignIn {
  final calls = <String>[];
  bool failSignOut = false;
  Completer<GoogleSignInAccount?>? selection;
  @override
  Future<GoogleSignInAccount?> signOut() async {
    calls.add('signOut');
    if (failSignOut) throw PlatformException(code: 'unavailable');
    return null;
  }

  @override
  Future<GoogleSignInAccount?> signIn() async {
    calls.add('signIn');
    return selection == null ? null : await selection!.future;
  }
}

class OfflineLogout implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    expect(options.path, '/auth/logout');
    return ResponseBody.fromString(
      '{}',
      503,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late DioClient client;
  late AccountPickerGoogle google;
  late AuthController auth;
  setUp(() {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    client = Get.put(DioClient(baseUrl: 'http://fixture.invalid'));
    client.dio.httpClientAdapter = OfflineLogout();
    google = AccountPickerGoogle();
    auth = Get.put(AuthController(googleSignIn: google));
  });
  tearDown(() => Get.reset());

  test(
    'every explicit login resets cached Google identity before account selection',
    () async {
      expect(await auth.signInWithGoogle(), false); // User cancels the picker.
      expect(await auth.signInWithGoogle(), false);
      expect(google.calls, ['signOut', 'signIn', 'signOut', 'signIn']);
      expect(auth.currentUser.value, isNull);
      expect(auth.authErrorMessage.value, isEmpty);
    },
  );

  test(
    'logout clears local session even when server and Google are unavailable',
    () async {
      await client.saveTokens(accessToken: 'access', refreshToken: 'refresh');
      auth.currentUser.value = const UserModel(
        id: 'old',
        email: 'old@gmail.com',
        firstName: 'Old',
      );
      auth.prefilledOnboarding['email'] = 'old@gmail.com';
      google.failSignOut = true;
      await auth.logout();
      expect(google.calls, ['signOut']);
      expect(await client.getAccessToken(), isNull);
      expect(await client.getRefreshToken(), isNull);
      expect(auth.currentUser.value, isNull);
      expect(auth.prefilledOnboarding, isEmpty);
      // Never silently fall back to the cached account when its reset fails.
      expect(await auth.signInWithGoogle(), false);
      expect(google.calls, ['signOut', 'signOut']);
      google.failSignOut = false;
      await auth.signInWithGoogle();
      expect(google.calls.sublist(2), ['signOut', 'signIn']);
    },
  );

  test('repeated taps do not launch overlapping account pickers', () async {
    google.selection = Completer<GoogleSignInAccount?>();
    final pending = auth.signInWithGoogle();
    await Future<void>.delayed(Duration.zero);
    expect(await auth.signInWithGoogle(), false);
    expect(google.calls, ['signOut', 'signIn']);
    google.selection!.complete(null);
    expect(await pending, false);
    expect(auth.isLoading.value, false);
  });
}
