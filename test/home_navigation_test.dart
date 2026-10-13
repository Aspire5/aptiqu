import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/home/models/home_dashboard_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/screens/home_screen.dart';
import 'package:aptiqu/features/home/presentation/widgets/chat_playground_zone.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/lesson/models/lesson_session_model.dart';
import 'package:aptiqu/features/lesson/repositories/lesson_repository.dart';
import 'home_dashboard_test.dart' show fixture;
import 'practice_catalog_test.dart' show TestFontManifest;

class LocalAuth extends AuthController {
  // Suppress network initialization in these local test controllers.
  @override
  // ignore: must_call_super
  void onInit() {}
  @override
  Future<void> fetchUserProfile() async {}
}

class LocalHome extends HomeController {
  // Suppress network initialization in these local test controllers.
  @override
  // ignore: must_call_super
  void onInit() {
    dashboard.value = fixture(populated: true);
  }

  @override
  Future<void> fetchDashboard() async {}
  @override
  Future<void> fetchActiveRoadmap() async {}
}

class LocalLessons extends LessonRepository {
  bool fail = false;
  String? resumed;
  @override
  Future<ActiveLessonStateModel> getActiveLessonState([
    String? roadmapStepId,
  ]) async {
    if (fail) throw StateError('Offline');
    return ActiveLessonStateModel(
      hasActiveSession: true,
      roadmapStepId: roadmapStepId,
      session: LessonSessionModel.fromJson({
        'sessionId': 'session',
        'status': 'PAUSED',
        'stateVersion': 7,
        'currentNode': {
          'id': 'current',
          'type': 'EXPLANATION',
          'content': {'text': 'One step at a time.'},
        },
        'history': [
          {'id': 'previous', 'isUser': false, 'text': 'Earlier teaching'},
        ],
      }),
    );
  }

  @override
  Future<void> resumeSession(String sessionId) async {
    resumed = sessionId;
  }
}

void main() {
  late LocalHome home;
  late LocalLessons lessons;
  setUp(() {
    Get.testMode = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    font_test.assetManifest = TestFontManifest();
    final bytes = File('test/fonts/Outfit.ttf').readAsBytesSync();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          return key.startsWith('test/fonts/')
              ? ByteData.sublistView(bytes)
              : null;
        });
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
    lessons = LocalLessons();
    Get.put<LessonRepository>(lessons);
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'test',
      email: 'test@example.com',
      firstName: 'A learner with a very long name',
      totalXp: 125,
    );
    home = Get.put<HomeController>(LocalHome()) as LocalHome;
  });
  tearDown(() => Get.reset());
  testWidgets(
    'Home is default and returning from player preserves session state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: AptiquTheme.darkTheme, home: const HomeScreen()),
      );
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        await (FontLoader('Roboto')..addFont(
              Future.value(
                ByteData.sublistView(
                  File('test/fonts/Outfit.ttf').readAsBytesSync(),
                ),
              ),
            ))
            .load();
      });
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HomeDashboardView), findsOneWidget);
      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('PLAY'), findsNothing);
      expect(tester.takeException(), isNull);
      await home.resumeFromHome(const HomeResume('step', 'Lesson', 'Topic'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ChatPlaygroundZone), findsOneWidget);
      expect(home.currentSession.value?.stateVersion, 7);
      expect(home.messages.any((m) => m.text == 'Earlier teaching'), true);
      expect(lessons.resumed, 'session');
      await tester.tap(find.text('HOME'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(HomeDashboardView), findsOneWidget);
      expect(home.currentSession.value?.id, 'session');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed resume returns to Home with a useful error', (
    tester,
  ) async {
    lessons.fail = true;
    await home.resumeFromHome(const HomeResume('step', 'Lesson', 'Topic'));
    expect(home.showHomeDashboard.value, true);
    expect(home.dashboardError.value, contains('could not be opened'));
    expect(home.messages, isEmpty);
  });
  testWidgets('Home exits fullscreen without clearing a conversation', (
    tester,
  ) async {
    home.isFullScreen.value = true;
    home.showHomeDashboard.value = false;
    home.messages.add(
      ChatMessageModel(
        id: 'existing',
        sender: MessageSender.ai,
        text: 'Keep this teaching',
        time: '',
      ),
    );
    home.selectHomeTab();
    expect(home.isFullScreen.value, false);
    expect(home.showHomeDashboard.value, true);
    expect(home.selectedNavIndex.value, 0);
    expect(home.messages.single.id, 'existing');
  });
}
