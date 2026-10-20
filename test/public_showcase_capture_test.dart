// Screenshot authoring only. Uses production widgets with in-memory demo data.
// No production screen, account, API, database or golden baseline is modified.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/auth/presentation/screens/login_screen.dart';
import 'package:aptiqu/features/home/models/home_dashboard_model.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/screens/home_screen.dart';
import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_lobby_controller.dart';
import 'package:aptiqu/features/pvp/ranked/ranked_models.dart';
import 'package:aptiqu/features/pvp/views/pvp_lobby_view.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/social/duel_room_screen.dart';
import 'home_navigation_test.dart' show LocalAuth, LocalHome;
import 'social_test.dart' show FakeSocial;
import 'phase_e_social_competitive_test.dart' show EAdapter, ESocket;
import 'ranked_phase_four_test.dart' show RankedTestRepo, rankedSummary;
import 'support/presentation_fonts.dart';

const photoUrl = 'https://showcase.invalid/shagun.jpeg';
const output = 'docs/public_showcase/2026-10-20';

class ShowcaseAdapter extends EAdapter {
  @override
  Map<String, dynamic> get duel => {
    ...super.duel,
    'requester': {'id': 'me', 'name': 'Shagun', 'avatarUrl': photoUrl},
    'recipient': {'id': 'friend', 'name': 'Maya', 'avatarUrl': null},
  };
}

class ShowcaseRankedRepo extends RankedTestRepo {
  @override
  Future<Map<String, dynamic>> history({int page = 1}) async => {
    'history': [
      {
        'matchId': 'showcase-match',
        'score': 8,
        'opponentScore': 5,
        'totalQuestions': 10,
        'isWinner': true,
        'isTie': false,
        'xpAwarded': 100,
        'joinedAt': '2026-10-20T10:30:00Z',
        'status': 'COMPLETED',
        'avgResponseTimeMs': 18500,
        'seasonId': '2026-10',
        'disposition': 'RATED',
        'opponent': {'userId': 'friend', 'name': 'Maya', 'level': 9},
        'rating': {
          'eventId': 'showcase-rating',
          'seasonId': '2026-10',
          'changeKind': 'RATING_CHANGE',
          'before': 1484,
          'delta': 16,
          'after': 1500,
          'leagueBefore': 'PLATINUM',
          'leagueAfter': 'PLATINUM',
          'seasonVersionAfter': 3,
        },
      },
    ],
    'pagination': {'totalPages': 1},
  };
}

HomeDashboardModel demoHome() {
  final activity = List.generate(50, (i) {
    final day = DateTime(2026, 9, 1).add(Duration(days: i));
    final active = day.month == 10 && ![5, 10, 16].contains(day.day);
    return HomeActivityDay(
      day.toIso8601String().substring(0, 10),
      active ? 16 : 0,
      active ? 12 : 0,
      dailyChallengeCompleted:
          active &&
          ([3, 4, 8, 9, 12, 13, 14].contains(day.day) || day.day >= 17),
    );
  });
  final attempted = activity.fold(0, (n, d) => n + d.attempted);
  final correct = activity.fold(0, (n, d) => n + d.correct);
  final summary = rankedSummary();
  (summary['standing'] as Map)['position'] = 128;
  return HomeDashboardModel(
    today: '2026-10-20',
    performance: HomePerformance(
      attempted: attempted,
      correct: correct,
      accuracy: .75,
      averageSolveTimeMs: 18500,
    ),
    difficulty: const {
      'EASY': HomePerformance(
        attempted: 120,
        correct: 96,
        accuracy: .8,
        averageSolveTimeMs: 14000,
      ),
      'MEDIUM': HomePerformance(
        attempted: 100,
        correct: 75,
        accuracy: .75,
        averageSolveTimeMs: 19500,
      ),
      'HARD': HomePerformance(
        attempted: 52,
        correct: 33,
        accuracy: 33 / 52,
        averageSolveTimeMs: 27000,
      ),
    },
    activity: activity,
    badges: const [
      HomeBadge('First steps', 'Complete your first lesson', 1, 1, true),
      HomeBadge(
        'Century of answers',
        'Get 100 answers correct',
        100,
        100,
        true,
      ),
    ],
    resume: const HomeResume(
      'step',
      'Place Value, Face Value and Number Formation',
      'Number System',
    ),
    rankedLeague: RankedSection('AVAILABLE', RankedSummary.fromJson(summary)),
    rankedGlobalRank: '#128',
    rankedPercentile: 'Top 18%',
    rankedDefaultRating: 1500,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('render refreshed public showcase assets', (tester) async {
    Get.testMode = true;
    FlutterSecureStorage.setMockInitialValues({});
    useProductionFontFixtures();
    final adapter = ShowcaseAdapter()
      ..profileName = 'Maya'
      ..duelStatus = 'ACTIVE'
      ..ownFinished = true;
    Get.put(
      DioClient(baseUrl: 'https://fixture.invalid/api/v1'),
    ).dio.httpClientAdapter = adapter;
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      email: 'shagun@example.test',
      firstName: 'Shagun',
      avatarUrl: photoUrl,
      level: 8,
      totalXp: 648,
      xpIntoCurrentLevel: 88,
      xpRequiredForNextLevel: 160,
      progress: .55,
      streak: '4d',
      coins: 240,
      highestStreak: 7,
      isRegistrationComplete: true,
      dailyChallengeCompleted: true,
    );
    final appearance = Get.put(AppearanceController());
    Get.put<SocialController>(FakeSocial());
    final home = Get.put<HomeController>(LocalHome()) as LocalHome;
    home.dashboard.value = demoHome();
    final socket = ESocket();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      Get.reset();
      await socket.events.close();
    });

    await tester.runAsync(() async {
      for (final family in ['Outfit', 'PlusJakartaSans']) {
        final folder = family == 'Outfit' ? 'outfit' : 'plus_jakarta_sans';
        final loader = FontLoader(family);
        for (final weight in [
          'Regular',
          'Medium',
          'SemiBold',
          'Bold',
          'ExtraBold',
        ]) {
          loader.addFont(
            Future.value(
              ByteData.sublistView(
                File(
                  'assets/fonts/$folder/$family-$weight.ttf',
                ).readAsBytesSync(),
              ),
            ),
          );
        }
        await loader.load();
      }
      final bytes = File(
        'admin-dashboard/public/showcase/brand/shagun.jpeg',
      ).readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      PaintingBinding.instance.imageCache.putIfAbsent(
        const NetworkImage(photoUrl),
        () => MultiFrameImageStreamCompleter(
          codec: Future.value(codec),
          scale: 1,
        ),
      );
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
    });

    Future<void> flush() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> show(Widget widget, {bool light = false}) async {
      await tester.pumpWidget(const SizedBox());
      appearance.mode.value = light ? ThemeMode.light : ThemeMode.dark;
      await tester.pumpWidget(
        MaterialApp(
          theme: light ? AptiquTheme.lightTheme : AptiquTheme.darkTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              padding: const EdgeInsets.only(top: 24, bottom: 24),
            ),
            child: RepaintBoundary(
              key: const ValueKey('showcase'),
              child: child!,
            ),
          ),
          home: widget,
        ),
      );
      await loadProductionFontFixtures(tester);
      await flush();
      await tester.runAsync(() async {
        for (final element in find.byType(Image).evaluate().toList()) {
          await precacheImage((element.widget as Image).image, element);
        }
      });
      await flush();
    }

    Future<void> capture(String name) async {
      await flush();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('showcase')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$output/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final light in [false, true]) {
      home.showHomeDashboard.value = true;
      await show(const HomeScreen(), light: light);
      expect(find.text('Shagun'), findsOneWidget);
      expect(find.text('75%'), findsWidgets);
      await capture(light ? 'home-light' : 'home-dark');
      if (!light) {
        await tester.scrollUntilVisible(
          find.text('Your consistency'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -280));
        await capture('consistency-dark');
      }
    }
    // Preserve the existing lesson content, only refreshing current shell identity.
    home.showHomeDashboard.value = false;
    home.activeScriptTitle.value = 'Sharing into equal groups';
    home.messages.assignAll([
      ChatMessageModel(
        id: 'q',
        sender: MessageSender.ai,
        text: 'Try sharing twelve chocolates equally.',
        time: '10:20',
        question: QuestionData(
          title: 'Equal groups',
          desc:
              'Share 12 chocolates equally among 3 people. How many does each person get?',
          inputType: QuestionInputType.select,
          options: ['3', '4', '6', '9'],
          optionIds: ['a', 'b', 'c', 'd'],
        ),
      ),
    ]);
    await show(const HomeScreen());
    await capture('lesson-dark');

    // Capture all three actual carousel pages; never recreate the login interface.
    await show(const LoginScreen(autoPlay: false));
    await capture('login-learn-dark');
    await show(const LoginScreen(autoPlay: false), light: true);
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3001);
    await flush();
    await capture('login-practice-light');
    await show(const LoginScreen(autoPlay: false));
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(3002);
    await flush();
    await capture('login-compete-dark');

    final repo = ShowcaseRankedRepo();
    (repo.summary['standing'] as Map)['position'] = 128;
    final lobby = Get.put(
      PvpLobbyController(socketService: socket, repository: repo),
    );
    await lobby.refreshRanked();
    await show(const Scaffold(body: PvpLobbyView()));
    await capture('ranked-dark');
    await show(const DuelRoomScreen(id: 'duel'));
    await flush();
    await capture('duel-dark');
    await tester.pumpWidget(const SizedBox());
    await flush();
  });
}
