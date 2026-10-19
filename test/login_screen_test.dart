import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/auth/presentation/screens/login_screen.dart';
import 'package:aptiqu/shared/widgets/buttons/aptiqu_button.dart';

class _FakeAuthController extends AuthController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(AppearanceController());
    Get.put(DioClient(baseUrl: 'http://fixture.invalid'));
    Get.put<AuthController>(_FakeAuthController());
  });

  tearDown(() {
    Get.delete<AuthController>();
    Get.delete<DioClient>();
    Get.delete<AppearanceController>();
  });

  Widget buildFrame(Widget child, {ThemeData? theme, Size size = const Size(390, 844)}) {
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: theme ?? AptiquTheme.lightTheme,
        home: child,
      ),
    );
  }

  testWidgets('LoginScreen shows initial Learn slide, main logo, AptiQu brand card, and legal row', (tester) async {
    await tester.pumpWidget(buildFrame(const LoginScreen(autoPlay: false)));
    await tester.pump();

    // App brand title in bottom card
    expect(find.text('AptiQu'), findsOneWidget);

    // Initial slide: Learn
    expect(
      find.text('Master every concept with step-by-step visual lessons'),
      findsOneWidget,
    );

    // Confirm old logo is NOT used
    expect(find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName.contains('small_logo');
      }
      return false;
    }), findsNothing);

    // Confirm main logo is displayed in bottom card
    expect(find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName ==
            'assets/images/main_logo.webp';
      }
      return false;
    }), findsOneWidget);

    // Confirm new onboarding asset is loaded
    expect(find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName ==
            'assets/images/login/aptiqu_onboarding_learn.webp';
      }
      return false;
    }), findsOneWidget);

    // Confirm NO dot indicators
    expect(find.byKey(const ValueKey('carousel-dots')), findsNothing);
    expect(find.byType(TabPageSelector), findsNothing);

    // Bottom login card elements
    expect(
      find.text('Build your aptitude and reasoning skills,\none step at a time.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      find.text('By continuing, you agree to our Terms of\nService and Privacy Policy.'),
      findsOneWidget,
    );
    expect(find.text('Terms of Service'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('•'), findsOneWidget);
  });

  testWidgets('LoginScreen carousel manual swipe navigates Learn -> Practice -> Compete', (tester) async {
    await tester.pumpWidget(buildFrame(const LoginScreen(autoPlay: false)));
    await tester.pump();

    // Slide 1: Learn
    expect(
      find.text('Master every concept with step-by-step visual lessons'),
      findsOneWidget,
    );

    // Swipe left to go to Slide 2: Practice
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('Build speed and accuracy with bite-sized daily drills'),
      findsOneWidget,
    );
    expect(find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName ==
            'assets/images/login/aptiqu_onboarding_practice.webp';
      }
      return false;
    }), findsOneWidget);

    // Swipe left to go to Slide 3: Compete
    await tester.drag(find.byType(PageView), const Offset(-350, 0));
    await tester.pumpAndSettle();

    expect(
      find.text('Challenge peers head-to-head in live 1v1 duels'),
      findsOneWidget,
    );
    expect(find.byWidgetPredicate((widget) {
      if (widget is Image && widget.image is AssetImage) {
        return (widget.image as AssetImage).assetName ==
            'assets/images/login/aptiqu_onboarding_compete.webp';
      }
      return false;
    }), findsOneWidget);
  });

  testWidgets('LoginScreen auto-play advances carousel automatically when enabled', (tester) async {
    await tester.pumpWidget(buildFrame(const LoginScreen(autoPlay: true)));
    await tester.pump();

    expect(
      find.text('Master every concept with step-by-step visual lessons'),
      findsOneWidget,
    );

    // Advance by 4.5 seconds (auto-play timer is 4.2s)
    await tester.pump(const Duration(milliseconds: 4300));
    // Settle page transition
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Build speed and accuracy with bite-sized daily drills'),
      findsOneWidget,
    );

    // Advance by another 4.3 seconds
    await tester.pump(const Duration(milliseconds: 4300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.text('Challenge peers head-to-head in live 1v1 duels'),
      findsOneWidget,
    );
  });

  testWidgets('LoginScreen renders with dark theme tokens without exception', (tester) async {
    await tester.pumpWidget(
      buildFrame(const LoginScreen(autoPlay: false), theme: AptiquTheme.darkTheme),
    );
    await tester.pump();

    expect(find.text('AptiQu'), findsOneWidget);
    expect(find.byType(AptiquButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
