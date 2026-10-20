import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/routing/app_router.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/auth/presentation/screens/login_screen.dart';
import 'package:aptiqu/features/onboarding/presentation/controllers/signup_controller.dart';
import 'package:aptiqu/features/onboarding/presentation/screens/signup_screen.dart';
import 'package:aptiqu/features/profile/presentation/screens/profile_screen.dart';
import 'package:aptiqu/features/profile/presentation/widgets/appearance_setting.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_account_selection_test.dart' show AccountPickerGoogle;
import 'support/presentation_fonts.dart';

const learner = UserModel(
  id: 'learner',
  email: 'asha@example.test',
  firstName: 'Asha',
  lastName: 'Kumar',
);
const cachedStats = UserStatsModel(
  topics: TopicStatsModel(completed: 3, total: 45),
  questions: QuestionStatsModel(
    easy: QuestionDifficultyStatsModel(solved: 5, total: 19),
  ),
);

class AccountAuth extends AuthController {
  AccountAuth({super.googleSignIn});
  @override
  // ignore: must_call_super
  void onInit() {}
  int registrations = 0;
  Map<String, dynamic>? submitted;
  Completer<bool>? registration;
  bool succeed = false;
  bool failLogout = false;
  @override
  Future<void> logout() async {
    if (failLogout) throw PlatformException(code: 'storage_unavailable');
    await super.logout();
  }

  @override
  Future<bool> completeRegistration({
    required String firstName,
    required String lastName,
    required DateTime dob,
    required String gender,
    required String religion,
    required String country,
  }) async {
    registrations++;
    submitted = {
      'firstName': firstName,
      'lastName': lastName,
      'dob': dob,
      'gender': gender,
      'religion': religion,
      'country': country,
    };
    final success = registration == null ? succeed : await registration!.future;
    if (success) {
      currentUser.value = currentUser.value!.copyWith(
        isRegistrationComplete: true,
      );
    } else {
      authErrorMessage.value = 'Could not save your profile. Please try again.';
    }
    return success;
  }
}

class ProfileAdapter implements HttpClientAdapter {
  bool fail = true;
  int calls = 0;
  Completer<void>? gate;
  Map<String, dynamic> data = {
    'id': 'learner',
    'email': 'asha@example.test',
    'firstName': 'Asha',
    'lastName': 'Kumar',
    'isRegistrationComplete': true,
    'stats': {
      'topics': {'completed': 4, 'total': 45},
      'questions': {
        'easy': {'solved': 6, 'total': 19},
      },
    },
  };
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    calls++;
    expect(options.path, '/user/profile');
    if (gate != null) await gate!.future;
    return ResponseBody.fromString(
      jsonEncode(fail ? {'success': false} : {'success': true, 'data': data}),
      fail ? 503 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

class SuccessfulAuth extends AccountAuth {
  final bool complete;
  SuccessfulAuth(this.complete);
  @override
  Future<bool> signInWithGoogle() async {
    currentUser.value = learner.copyWith(isRegistrationComplete: complete);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountAuth auth;
  late AccountPickerGoogle google;
  late AppearanceController appearance;
  late DioClient client;
  var providerFontLoaded = false;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    client = Get.put(DioClient(baseUrl: 'http://fixture.invalid'));
    google = AccountPickerGoogle();
    auth =
        Get.put<AuthController>(AccountAuth(googleSignIn: google))
            as AccountAuth;
    auth.currentUser.value = learner;
    appearance = Get.put(AppearanceController());
    PackageInfo.setMockInitialValues(
      appName: 'AptiQu',
      packageName: 'test.aptiqu',
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(() => Get.reset());

  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    double scale = 1,
    double keyboardInset = 0,
    GoRouter? router,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget frame(BuildContext context, Widget child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        size: size,
        textScaler: TextScaler.linear(scale),
        viewInsets: EdgeInsets.only(bottom: keyboardInset),
      ),
      child: RepaintBoundary(key: const ValueKey('capture-c'), child: child),
    );
    await tester.pumpWidget(
      router == null
          ? MaterialApp(
              theme: AptiquTheme.darkTheme,
              builder: (context, child) => frame(context, child!),
              home: screen,
            )
          : MaterialApp.router(
              theme: AptiquTheme.darkTheme,
              routerConfig: router,
              builder: (context, child) => frame(context, child!),
            ),
    );
    await loadProductionFontFixtures(tester);
    await tester.runAsync(() async {
      final context = tester.element(find.byKey(const ValueKey('capture-c')));
      for (final asset in [
        'assets/images/login/aptiqu_onboarding_learn.webp',
        'assets/images/login/aptiqu_onboarding_practice.webp',
        'assets/images/login/aptiqu_onboarding_compete.webp',
      ]) {
        await precacheImage(AssetImage(asset), context);
      }
      await precacheImage(
        const AssetImage('assets/images/google_g.png'),
        context,
      );
      if (!providerFontLoaded) {
        await (FontLoader('GoogleSans')..addFont(
              Future.value(
                ByteData.sublistView(
                  File(
                    'assets/fonts/google_sans/GoogleSans-Medium.ttf',
                  ).readAsBytesSync(),
                ),
              ),
            ))
            .load();
        providerFontLoaded = true;
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    const revision = bool.fromEnvironment('CAPTURE_PHASE_C_REVISION');
    if (!const bool.fromEnvironment('CAPTURE_PHASE_C') && !revision) return;
    await tester.pump();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-c')),
      );
      final result = await boundary.toImage(pixelRatio: 2);
      final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        'docs/${revision ? 'ui_ux_phase_c_revision' : 'ui_ux_phase_c'}/$name.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      result.dispose();
    });
  }

  Finder submit() => find.widgetWithText(AptiquButton, 'Complete profile');
  Finder vertical() => find
      .byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      )
      .first;
  Future<void> scrollTap(WidgetTester tester, Finder finder) async {
    await tester.pumpAndSettle();
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  SignUpController prefilled() {
    final controller = Get.put(SignUpController());
    controller.firstNameController.text = '  Asha  ';
    controller.lastNameController.text = '  Kumar  ';
    controller.setDob(DateTime(2003, 1, 2));
    controller.setGender('Female');
    controller.setReligion('Prefer not to say');
    return controller;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      testWidgets('revised composition ${mode.name} $size', (tester) async {
        appearance.mode.value = mode;
        await show(tester, const SignUpScreen(), size: size);
        final first = tester.getRect(find.byType(TextFormField).first);
        final last = tester.getRect(find.byType(TextFormField).at(1));
        expect(first.top, closeTo(last.top, .1));
        expect(first.right, lessThan(last.left));
        expect(find.byType(ChoiceChip), findsNWidgets(3));
        expect(find.byType(RadioListTile<String>), findsNothing);
        for (final chip in find.byType(ChoiceChip).evaluate()) {
          expect(
            tester.getSize(find.byWidget(chip.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        await scrollTap(tester, find.byKey(const ValueKey('gender-Female')));
        expect(Get.find<SignUpController>().selectedGender.value, 'Female');
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const ValueKey('gender-Female')))
              .selected,
          true,
        );
        await capture(
          tester,
          'signup-composition-${size.width.toInt()}-${mode.name}',
        );
        auth.currentUser.value = learner.copyWith(
          stats: cachedStats,
          level: 3,
          totalXp: 75,
          xpIntoCurrentLevel: 15,
          xpRequiredForNextLevel: 60,
          progress: .25,
        );
        await show(tester, const ProfileScreen(autoFetch: false), size: size);
        final avatar = tester.getRect(find.byType(CircleAvatar));
        final name = tester.getRect(find.text('Asha Kumar'));
        expect(name.left, greaterThan(avatar.right));
        expect(name.top, lessThan(avatar.bottom));
        final selector = tester.getRect(find.byType(AppearanceSetting));
        expect(selector.height, lessThan(200));
        expect(
          selector.top,
          lessThan(tester.getTopLeft(find.text('Level Progression')).dy),
        );
        expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
        expect(
          tester.getSize(find.byType(SegmentedButton<ThemeMode>)).height,
          greaterThanOrEqualTo(48),
        );
        await capture(
          tester,
          'profile-composition-${size.width.toInt()}-${mode.name}',
        );
        await tester.ensureVisible(find.text('Sign out'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'profile-footer-${size.width.toInt()}-${mode.name}',
        );
        expect(
          tester.getRect(find.text('Sign out')).top,
          lessThan(tester.getRect(find.text('0.0.1 (Build 1)')).bottom + 24),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('revised wide progress grouping ${mode.name}', (tester) async {
      appearance.mode.value = mode;
      auth.currentUser.value = learner.copyWith(stats: cachedStats);
      await show(
        tester,
        const ProfileScreen(autoFetch: false),
        size: const Size(768, 1024),
        scale: 1.3,
      );
      expect(
        tester.getTopLeft(find.text('Unique Topics Completed')).dy,
        closeTo(tester.getTopLeft(find.text('Level Progression')).dy, 1.5),
      );
      expect(
        tester.getTopLeft(find.text('Unique Topics Completed')).dx,
        greaterThan(tester.getTopLeft(find.text('Level Progression')).dx),
      );
      await capture(tester, 'profile-wide-${mode.name}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('revised enlarged controls preserve choices ${mode.name}', (
      tester,
    ) async {
      appearance.mode.value = mode;
      await show(tester, const SignUpScreen(), size: const Size(360, 800));
      await scrollTap(tester, find.byKey(const ValueKey('gender-Female')));
      final controller = Get.find<SignUpController>();
      await show(
        tester,
        const SignUpScreen(),
        size: const Size(320, 568),
        scale: 2,
      );
      expect(identical(controller, Get.find<SignUpController>()), true);
      expect(
        tester.getRect(find.byType(TextFormField).at(1)).top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(TextFormField).first).bottom,
        ),
      );
      expect(controller.selectedGender.value, 'Female');
      expect(controller.firstNameController.text, 'Asha');
      await show(
        tester,
        const ProfileScreen(autoFetch: false),
        size: const Size(320, 568),
        scale: 2,
      );
      expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
      for (final value in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
        final choice = find.ancestor(
          of: find.byKey(ValueKey('appearance-${value.name}')),
          matching: find.byType(ChoiceChip),
        );
        await scrollTap(tester, choice);
        expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
        expect(appearance.mode.value, value);
        if (value == mode) {
          await tester.ensureVisible(find.byType(AppearanceSetting));
          await tester.pumpAndSettle();
          await capture(tester, 'profile-appearance-large-${mode.name}');
        }
      }
      final restarted = AppearanceController();
      await restarted.load();
      expect(restarted.mode.value, ThemeMode.system);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Signup keyboard inset and retained error ${mode.name}', (
      tester,
    ) async {
      appearance.mode.value = mode;
      prefilled();
      await show(
        tester,
        const SignUpScreen(),
        size: const Size(320, 568),
        scale: 2,
        keyboardInset: 220,
      );
      await scrollTap(tester, submit());
      expect(
        find
            .text('Could not save your profile. Please try again.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(auth.registrations, 1);
      expect(tester.takeException(), isNull);
    });
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      testWidgets('Profile long identity and large totals ${mode.name} $size', (
        tester,
      ) async {
        appearance.mode.value = mode;
        auth.currentUser.value = learner.copyWith(
          firstName: 'Alexandria Chandrasekhar',
          lastName: 'Krishnamurthy',
          email: 'alexandria.chandrasekhar@example.test',
          totalXp: 123456,
          stats: const UserStatsModel(
            topics: TopicStatsModel(completed: 12345, total: 45678),
            questions: QuestionStatsModel(
              easy: QuestionDifficultyStatsModel(solved: 12345, total: 67890),
            ),
          ),
        );
        await show(
          tester,
          const ProfileScreen(autoFetch: false),
          size: size,
          scale: 2,
        );
        if (size.width == 320) {
          await capture(tester, 'profile-large-${mode.name}');
        }
        expect(
          find.text('Alexandria Chandrasekhar Krishnamurthy'),
          findsOneWidget,
        );
        await scrollTap(tester, find.text('Sign out'));
        expect(find.text('Sign out?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
    for (final config in [
      (const Size(390, 844), 1.0),
      (const Size(320, 568), 2.0),
      (const Size(844, 390), 2.0),
      (const Size(568, 320), 2.0),
      (const Size(768, 1024), 1.3),
    ]) {
      testWidgets(
        'Login ${mode.name} ${config.$1} ${config.$2} error, cancel and busy',
        (tester) async {
          appearance.mode.value = mode;
          await show(
            tester,
            const LoginScreen(),
            size: config.$1,
            scale: config.$2,
          );
          if (config.$1.width == 390) {
            await capture(tester, 'login-${mode.name}');
          }
          await scrollTap(tester, find.text('Continue with Google'));
          expect(google.calls, ['signOut', 'signIn']);
          expect(auth.authErrorMessage.value, isEmpty);
          auth.authErrorMessage.value =
              'We could not sign you in. Check your connection and try again with your Google account.';
          await tester.pumpAndSettle();
          expect(find.text(auth.authErrorMessage.value), findsOneWidget);
          if (config.$1.width == 390) {
            await capture(tester, 'login-error-${mode.name}');
          }
          google.selection = Completer();
          await tester.ensureVisible(find.text('Continue with Google'));
          await tester.tap(find.text('Continue with Google'));
          await tester.pump();
          expect(auth.isLoading.value, true);
          final native = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Continue with Google'),
          );
          expect(native.onPressed, isNull);
          expect(find.text('Continue with Google'), findsOneWidget);
          google.selection!.complete(null);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Privacy Policy'));
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Privacy Policy'),
                )
                .onPressed,
            isNull,
          );
          expect(find.text('These links are not available yet.'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'Signup ${mode.name} ${config.$1} ${config.$2} validation, pickers and switch cancellation',
        (tester) async {
          appearance.mode.value = mode;
          await show(
            tester,
            const SignUpScreen(),
            size: config.$1,
            scale: config.$2,
          );
          final controller = Get.find<SignUpController>();
          controller.firstNameController.clear();
          controller.lastNameController.clear();
          if (config.$1.width == 390) {
            await capture(tester, 'signup-${mode.name}');
          }
          await scrollTap(tester, submit());
          expect(auth.registrations, 0);
          expect(find.text('Enter your first name.'), findsOneWidget);
          expect(find.text('Enter your last name.'), findsOneWidget);
          expect(find.text('Select your date of birth.'), findsOneWidget);
          expect(find.text('Select a gender option.'), findsOneWidget);
          expect(find.text('Select a belief option.'), findsWidgets);
          expect(
            tester
                .widget<TextField>(find.byType(TextField).first)
                .focusNode!
                .hasFocus,
            true,
          );
          if (config.$1.width == 320) {
            await capture(tester, 'signup-errors-large-${mode.name}');
          }
          await tester.enterText(find.byType(TextFormField).first, 'Asha');
          await tester.enterText(find.byType(TextFormField).at(1), 'Kumar');
          FocusManager.instance.primaryFocus?.unfocus();
          await scrollTap(
            tester,
            find.widgetWithText(OutlinedButton, 'Select your birth date'),
          );
          expect(find.byType(DatePickerDialog), findsOneWidget);
          expect(
            Theme.of(tester.element(find.byType(DatePickerDialog))).brightness,
            mode == ThemeMode.light ? Brightness.light : Brightness.dark,
          );
          if (config.$1.width == 390) {
            await capture(tester, 'date-picker-${mode.name}');
          }
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(controller.dob.value, isNull);
          await scrollTap(
            tester,
            find.widgetWithText(OutlinedButton, 'Select your birth date'),
          );
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          expect(controller.dob.value, DateTime(2003, 1, 1));
          await scrollTap(tester, find.byKey(const ValueKey('gender-Other')));
          expect(controller.selectedGender.value, 'Other');
          await scrollTap(
            tester,
            find.widgetWithText(OutlinedButton, 'Select a belief option'),
          );
          if (config.$1.width == 390) {
            await capture(tester, 'belief-picker-${mode.name}');
          }
          await tester.ensureVisible(find.byType(RadioListTile<String>).last);
          await tester.tap(find.byType(RadioListTile<String>).last);
          await tester.pumpAndSettle();
          expect(controller.selectedReligion.value, 'Prefer not to say');
          await scrollTap(tester, find.widgetWithText(OutlinedButton, 'India'));
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(controller.selectedCountry.value, 'India');
          await scrollTap(tester, find.widgetWithText(OutlinedButton, 'India'));
          await tester.ensureVisible(find.text('United Arab Emirates'));
          await tester.tap(find.text('United Arab Emirates'));
          await tester.pumpAndSettle();
          expect(controller.selectedCountry.value, 'United Arab Emirates');
          await tester.tap(find.byTooltip('Switch account'));
          await tester.pumpAndSettle();
          expect(find.text('Use a different account?'), findsOneWidget);
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(controller.firstNameController.text, 'Asha');
          expect(controller.selectedCountry.value, 'United Arab Emirates');
          expect(auth.currentUser.value, isNotNull);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'Profile ${mode.name} cache failure retry version and scroll retention',
      (tester) async {
        appearance.mode.value = mode;
        auth.currentUser.value = learner.copyWith(stats: cachedStats);
        final adapter = ProfileAdapter();
        client.dio.httpClientAdapter = adapter;
        await show(tester, const ProfileScreen());
        expect(find.textContaining('Showing saved details.'), findsOneWidget);
        expect(find.text('3 / 45'), findsOneWidget);
        if (mode == ThemeMode.light || mode == ThemeMode.dark) {
          await capture(tester, 'profile-cached-error-${mode.name}');
        }
        adapter.fail = false;
        await tester.tap(find.text('Retry refresh'));
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pumpAndSettle();
        expect(adapter.calls, 2);
        expect(find.text('4 / 45'), findsOneWidget);
        expect(find.textContaining('Showing saved details.'), findsNothing);
        await tester.ensureVisible(find.byType(AppearanceSetting));
        await tester.pumpAndSettle();
        expect(find.text('0.0.1 (Build 1)'), findsOneWidget);
        expect(find.text('v1.0.0 (Build 1)'), findsNothing);
        expect(find.text('Sign out'), findsOneWidget);
        final offset = tester
            .state<ScrollableState>(vertical())
            .position
            .pixels;
        await appearance.setMode(
          mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
        );
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(vertical()).position.pixels,
          closeTo(offset, .1),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final complete in [true, false]) {
    testWidgets(
      'Login routes to the existing ${complete ? 'home' : 'signup'} destination',
      (tester) async {
        Get.delete<AuthController>();
        auth = Get.put<AuthController>(SuccessfulAuth(complete)) as AccountAuth;
        final router = GoRouter(
          initialLocation: '/login',
          routes: [
            GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
            GoRoute(
              path: '/',
              builder: (_, __) =>
                  const Scaffold(body: Text('Home destination')),
            ),
            GoRoute(
              path: '/signup',
              builder: (_, __) =>
                  const Scaffold(body: Text('Signup destination')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await show(tester, const SizedBox(), router: router);
        await scrollTap(tester, find.text('Continue with Google'));
        expect(
          find.text(complete ? 'Home destination' : 'Signup destination'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Profile reads installed version metadata rather than a fixed version',
    (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'AptiQu',
        packageName: 'test.aptiqu',
        version: '2.7.3',
        buildNumber: '41',
        buildSignature: '',
      );
      await show(tester, const ProfileScreen(autoFetch: false));
      await tester.ensureVisible(find.byType(AppearanceSetting));
      expect(find.text('2.7.3 (Build 41)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Login and signup follow System live and retain entered form values',
    (tester) async {
      appearance.mode.value = ThemeMode.system;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await show(tester, const LoginScreen());
      expect(
        Theme.of(tester.element(find.byType(AptiquButton))).brightness,
        Brightness.light,
      );
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(AptiquButton))).brightness,
        Brightness.dark,
      );
      final controller = prefilled();
      await show(tester, const SignUpScreen());
      await appearance.setMode(ThemeMode.light);
      await tester.pumpAndSettle();
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(Form))).brightness,
        Brightness.light,
      );
      expect(controller.firstNameController.text, '  Asha  ');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'all required fields validate locally, including country, without submitting',
    (tester) async {
      final controller = prefilled();
      controller.selectedCountry.value = '';
      await show(tester, const SignUpScreen());
      await scrollTap(tester, submit());
      expect(find.text('Select your country.'), findsWidgets);
      expect(auth.registrations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'submission keeps values, prevents duplicates, exposes failure, retries then routes',
    (tester) async {
      final controller = prefilled();
      auth.registration = Completer<bool>();
      final router = GoRouter(
        initialLocation: '/signup',
        routes: [
          GoRoute(path: '/signup', builder: (_, __) => const SignUpScreen()),
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('Learning home')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await show(tester, const SizedBox(), router: router);
      await tester.ensureVisible(submit());
      await tester.tap(submit());
      await tester.pump();
      expect(auth.registrations, 1);
      expect(controller.isLoading.value, true);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Complete profile'),
            )
            .onPressed,
        isNull,
      );
      expect(auth.submitted, {
        'firstName': 'Asha',
        'lastName': 'Kumar',
        'dob': DateTime(2003, 1, 2),
        'gender': 'Female',
        'religion': 'Prefer not to say',
        'country': 'India',
      });
      auth.registration!.complete(false);
      await tester.pumpAndSettle();
      expect(
        find
            .text('Could not save your profile. Please try again.')
            .hitTestable(),
        findsOneWidget,
      );
      expect(controller.firstNameController.text, '  Asha  ');
      auth.registration = null;
      auth.succeed = true;
      await scrollTap(tester, submit());
      expect(auth.registrations, 2);
      expect(find.text('Learning home'), findsOneWidget);
      expect(auth.isRegistrationComplete, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'production guard and system back support explicit account switch without returning to signup',
    (tester) async {
      final router = AppRouter.router;
      router.go('/login');
      await show(tester, const SizedBox(), router: router);
      expect(find.byType(SignUpScreen), findsOneWidget);
      final controller = Get.find<SignUpController>();
      controller.firstNameController.text = 'Draft';
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Use a different account?'), findsOneWidget);
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(controller.firstNameController.text, 'Draft');
      await tester.tap(find.byTooltip('Switch account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Switch account'));
      await tester.pumpAndSettle();
      expect(auth.currentUser.value, isNull);
      expect(google.calls, ['signOut']);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(Get.isRegistered<SignUpController>(), false);
      router.go('/signup');
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile missing statistics are unavailable, actual zeros remain zeros',
    (tester) async {
      await show(tester, const ProfileScreen(autoFetch: false));
      expect(find.text('Statistics unavailable'), findsOneWidget);
      expect(find.text('0 / 0'), findsNothing);
      auth.currentUser.value = learner.copyWith(stats: const UserStatsModel());
      await tester.pumpAndSettle();
      expect(find.text('Statistics unavailable'), findsNothing);
      expect(find.text('0 / 0'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profile logout failure stays recoverable without claiming success',
    (tester) async {
      auth.failLogout = true;
      await show(tester, const ProfileScreen(autoFetch: false));
      await scrollTap(tester, find.text('Sign out'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not sign out. Please try again.'),
        findsOneWidget,
      );
      expect(auth.currentUser.value, isNotNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.ancestor(
                of: find.text('Sign out'),
                matching: find.byWidgetPredicate(
                  (widget) => widget is OutlinedButton,
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Signup account switch failure preserves draft and recovery action',
    (tester) async {
      auth.failLogout = true;
      final controller = prefilled();
      await show(tester, const SignUpScreen());
      await scrollTap(tester, find.text('Use a different account'));
      await tester.tap(find.text('Switch account'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not switch accounts. Please try again.').hitTestable(),
        findsOneWidget,
      );
      expect(controller.firstNameController.text, '  Asha  ');
      expect(auth.currentUser.value, isNotNull);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Switch account',
              ),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profile signout clears session, reaches login and preserves appearance',
    (tester) async {
      await appearance.setMode(ThemeMode.light);
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(autoFetch: false),
          ),
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        ],
      );
      addTearDown(router.dispose);
      await show(tester, const SizedBox(), router: router);
      await scrollTap(tester, find.text('Sign out'));
      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();
      expect(auth.currentUser.value, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(appearance.mode.value, ThemeMode.light);
      expect(
        Theme.of(tester.element(find.byType(AptiquButton))).brightness,
        Brightness.light,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
