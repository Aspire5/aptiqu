import 'package:aptiqu/features/home/presentation/widgets/home_dashboard_view.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'home_dashboard_test.dart' show fixture;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:aptiqu/main.dart';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/routing/app_router.dart';
import 'package:aptiqu/core/theme/appearance_controller.dart';
import 'package:aptiqu/core/theme/appearance_theme.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/auth/domain/models/user_model.dart';
import 'package:aptiqu/features/auth/presentation/controllers/auth_controller.dart';
import 'package:aptiqu/features/auth/presentation/screens/login_screen.dart';
import 'package:aptiqu/features/onboarding/presentation/screens/signup_screen.dart';
import 'package:aptiqu/features/home/presentation/controllers/home_controller.dart';
import 'package:aptiqu/features/home/presentation/screens/home_screen.dart';
import 'package:aptiqu/features/home/presentation/widgets/constellation_roadmap_view.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/practice/controllers/practice_catalog_controller.dart';
import 'package:aptiqu/features/practice/controllers/practice_session_controller.dart';
import 'package:aptiqu/features/practice/views/practice_catalog_view.dart';
import 'package:aptiqu/features/practice/views/practice_session_screen.dart';
import 'package:aptiqu/features/profile/presentation/screens/profile_screen.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_lobby_controller.dart';
import 'package:aptiqu/features/pvp/controllers/pvp_arena_controller.dart';
import 'package:aptiqu/features/pvp/views/pvp_lobby_view.dart';
import 'package:aptiqu/features/pvp/views/pvp_arena_screen.dart';
import 'package:aptiqu/features/daily_challenge/controllers/daily_challenge_controller.dart';
import 'package:aptiqu/features/daily_challenge/presentation/screens/daily_streak_hub_screen.dart';
import 'package:aptiqu/features/daily_challenge/presentation/screens/daily_challenge_quiz_screen.dart';
import 'package:aptiqu/features/social/friends_screen.dart';
import 'package:aptiqu/features/social/friend_requests_screen.dart';
import 'package:aptiqu/features/social/duel_room_screen.dart';
import 'package:aptiqu/features/social/social_controller.dart';
import 'package:aptiqu/features/lesson/views/lesson_feed_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'home_navigation_test.dart' show LocalAuth, LocalHome;
import 'learning_progress_test.dart' show learningMap;
import 'social_test.dart' show FakeSocial;
import 'phase_d_learning_test.dart' as d;
import 'phase_e_social_competitive_test.dart' show ESocket, longName;
import 'phase_f_routed_global_test.dart' show FAdapter;
import 'support/presentation_fonts.dart';

class GAdapter extends FAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    if (o.path == '/user/achievements') {
      return response({
        'items': [
          {
            'id': 'a',
            'title': 'A steady start',
            'description': 'Build a learning habit, one day at a time.',
            'unlocked': true,
            'progress': 3,
            'target': 3,
          },
        ],
        'hasMore': false,
      });
    }
    if (o.path == '/user/profile') {
      return response({
        'id': 'me',
        'firstName': 'Asha',
        'email': 'asha@example.test',
        'isRegistrationComplete': true,
      });
    }
    return super.fetch(o, stream, cancel);
  }
}

// Every S01–S18 view, including the shared shell. State transitions and overlays
// remain exercised by the A–F suites; this matrix adds the full size envelope.
class GFailedStart extends d.HistoryRepository {
  @override
  Future<PracticeSessionModel> createSession({
    String? topicId,
    List<String>? subtopicIds,
    bool smartPicks = false,
    bool timerEnabled = false,
  }) async => throw Exception('Connection unavailable. Try again.');
}

const views = [
  'S01-login',
  'S02-signup',
  'S03-home',
  'S04-embedded',
  'S05-topics',
  'S06-setup',
  'S07-history',
  'S08-practice',
  'S09-ranked',
  'S10-arena',
  'S11-profile',
  'S12-daily',
  'S13-daily-quiz',
  'S14-friends',
  'S15-requests',
  'S16-learner',
  'S17-duel',
  'S18-routed',
];
const envelopes = [
  (Size(390, 844), 1.0, 'phone'),
  (Size(320, 568), 2.0, 'small-large-text'),
  (Size(430, 932), 1.3, 'large-phone'),
  (Size(844, 390), 2.0, 'landscape'),
  (Size(768, 1024), 1.3, 'tablet'),
  (Size(320, 568), 1.0, 'small-phone'),
  (Size(320, 568), 1.3, 'small-phone-medium'),
  (Size(390, 844), 1.3, 'phone-medium'),
  (Size(390, 844), 2.0, 'phone-large-text'),
  (Size(430, 932), 1.0, 'large-phone-normal'),
  (Size(430, 932), 2.0, 'large-phone-large-text'),
  (Size(844, 390), 1.0, 'landscape-normal'),
  (Size(844, 390), 1.3, 'landscape-medium'),
  (Size(768, 1024), 1.0, 'tablet-normal'),
  (Size(768, 1024), 2.0, 'tablet-large-text'),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppearanceController appearance;
  late GAdapter adapter;
  late LocalHome home;
  late ESocket socket;
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    adapter = GAdapter();
    Get.put(
      DioClient(baseUrl: 'http://fixture.invalid/api/v1'),
    ).dio.httpClientAdapter = adapter;
    final auth = Get.put<AuthController>(LocalAuth());
    auth.currentUser.value = const UserModel(
      id: 'me',
      firstName: longName,
      email: 'asha.long.name@example.test',
      isRegistrationComplete: true,
      totalXp: 125,
    );
    appearance = Get.put(AppearanceController());
    Get.put<SocialController>(FakeSocial());
    home = Get.put<HomeController>(LocalHome()) as LocalHome;
    socket = ESocket();
    PackageInfo.setMockInitialValues(
      appName: 'AptiQu',
      packageName: 'test.aptiqu',
      version: '0.0.1',
      buildNumber: '1',
      buildSignature: '',
    );
  });
  tearDown(() async {
    Get.reset();
    await socket.events.close();
  });

  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
  }

  Future<void> fonts(WidgetTester tester) async {
    await loadProductionFontFixtures(tester);
    await tester.runAsync(() async {
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
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_PHASE_G')) return;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final b = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('capture-g')),
      );
      final picture = await b.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('docs/ui_ux_phase_g/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  Widget view(String name, {bool hard = false}) {
    switch (name) {
      case 'S01-login':
        return const LoginScreen();
      case 'S02-signup':
        return const SignUpScreen();
      case 'S03-home':
        return const HomeScreen();
      case 'S04-embedded':
        home.showHomeDashboard.value = false;
        home.activeScriptTitle.value = 'Sharing into equal groups';
        home.messages.add(
          ChatMessageModel(
            id: 'q',
            sender: MessageSender.ai,
            text: 'Try sharing twelve chocolates equally.',
            time: '10:20',
            question: QuestionData(
              title: 'Equal groups',
              desc: hard
                  ? d.explanation * 4
                  : 'Share 12 chocolates equally among 3 people. How many does each person get?',
              inputType: QuestionInputType.select,
              options: ['3', '4', '6', '9'],
              optionIds: ['a', 'b', 'c', 'd'],
            ),
          ),
        );
        return const HomeScreen();
      case 'S05-topics':
        return Scaffold(
          body: ConstellationRoadmapView(
            learningMap: learningMap(
              'math',
              topics: [
                for (final entry in [
                  (1, 'Number System'),
                  (2, 'Problems on Ages'),
                ])
                  LearningMapTopicItemModel(
                    roadmapStepId: 'step-${entry.$1}',
                    sequence: entry.$1,
                    topicId: 'topic-${entry.$1}',
                    topicName: entry.$2,
                    topicSlug: 'topic-${entry.$1}',
                    importance: 'medium',
                    teachingMinutes: 10,
                    teachingDepth: 1,
                    state: 'AVAILABLE',
                    scriptAvailable: true,
                    scriptSlug: 'sharing',
                    totalSubtopics: 1,
                    completedSubtopics: 0,
                    subtopics: [
                      SubtopicItemModel(
                        id: 'subtopic-${entry.$1}',
                        scriptSlug: 'sharing',
                        title: 'Sharing into equal groups',
                        sequence: 1,
                        isCompleted: false,
                        isLocked: false,
                      ),
                    ],
                  ),
              ],
            ),
            subjects: [
              RoadmapSubjectSummary(
                id: 'math',
                slug: 'math',
                name: 'Quantitative Aptitude',
                sequence: 1,
              ),
            ],
            selectedSubjectId: 'math',
            onSelectSubject: (_) {},
            onTopicTap: (_) {},
            onRefresh: () async {},
            onToggleFullScreen: () {},
          ),
        );
      case 'S06-setup':
      case 'S07-history':
        final c = Get.put(
          PracticeCatalogController(repository: d.HistoryRepository()),
        );
        c.showHistory.value = name == 'S07-history';
        if (c.showHistory.value) c.fetchHistory();
        return const Scaffold(body: SafeArea(child: PracticeCatalogView()));
      case 'S08-practice':
        final session = d.practice(long: hard);
        Get.put(
          PracticeSessionController(
            session,
            repository: d.LearningRepository(),
          ),
        );
        return PracticeSessionScreen(initialSession: session);
      case 'S09-ranked':
        Get.put(PvpLobbyController(socketService: socket));
        return const Scaffold(body: SafeArea(child: PvpLobbyView()));
      case 'S10-arena':
        Get.put(
          PvpArenaController(
            matchId: 'match',
            initialPlayersData: [
              {'userId': 'friend', 'firstName': longName},
            ],
            totalQuestions: 10,
            socketService: socket,
          ),
        );
        return const PvpArenaScreen(
          matchId: 'match',
          initialPlayersData: [],
          totalQuestions: 10,
        );
      case 'S11-profile':
        return const ProfileScreen(autoFetch: false);
      case 'S12-daily':
        final c = Get.put<DailyChallengeController>(d.DailyFixture());
        c.status.value = d.dailyStatus();
        c.isLoadingStatus.value = false;
        return const DailyStreakHubScreen();
      case 'S13-daily-quiz':
        final c = Get.put<DailyChallengeController>(d.QuietDaily());
        c.activeSession.value = d.dailySession(long: hard);
        return const DailyChallengeQuizScreen();
      case 'S14-friends':
        return const FriendsScreen();
      case 'S15-requests':
        return const FriendRequestsScreen();
      case 'S16-learner':
        adapter.large = hard;
        adapter.profileName = longName;
        return const FriendProfileScreen(id: 'friend');
      case 'S17-duel':
        adapter.profileName = longName;
        return const DuelRoomScreen(id: 'duel');
      case 'S18-routed':
        adapter.type = 'QUESTION';
        adapter.largeLesson = hard;
        return const LessonFeedScreen(slug: 'sharing');
      default:
        throw StateError(name);
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final envelope in envelopes) {
      for (final name in views) {
        testWidgets('$name ${mode.name} ${envelope.$3}', (tester) async {
          appearance.mode.value = mode;
          final size = envelope.$1;
          final scale = envelope.$2;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final screen = view(name, hard: scale > 1);
          await tester.pumpWidget(
            MaterialApp(
              theme: mode == ThemeMode.light
                  ? AptiquTheme.lightTheme
                  : AptiquTheme.darkTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                  padding: const EdgeInsets.only(top: 24, bottom: 24),
                ),
                child: RepaintBoundary(
                  key: const ValueKey('capture-g'),
                  child: child!,
                ),
              ),
              home: AppearanceTheme(builder: (_) => screen),
            ),
          );
          await fonts(tester);
          await flush(tester);
          await flush(tester);
          if (name == 'S10-arena') {
            socket.emit('QUESTION_STARTED', {
              'questionIndex': 0,
              'durationSeconds': 60,
              'question': d.questionData(0, long: scale > 1),
            });
            await flush(tester);
          }
          expect(tester.takeException(), isNull);
          if (envelope.$3 == 'phone' ||
              (envelope.$3 == 'landscape' &&
                  [
                    'S02-signup',
                    'S04-embedded',
                    'S08-practice',
                    'S11-profile',
                    'S13-daily-quiz',
                    'S18-routed',
                  ].contains(name))) {
            await capture(tester, '$name-${mode.name}-${envelope.$3}');
          }
          final semantics = tester.ensureSemantics();
          if (envelope.$3 == 'phone') {
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            await expectLater(tester, meetsGuideline(textContrastGuideline));
          }
          semantics.dispose();
          final scrollable = find.byType(Scrollable).first;
          if (scrollable.evaluate().isNotEmpty) {
            for (var i = 0; i < 3; i++) {
              await tester.drag(scrollable, const Offset(0, -450));
              await flush(tester);
              expect(tester.takeException(), isNull);
            }
          }
          await tester.pumpWidget(const SizedBox());
          await flush(tester);
        });
      }
    }
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'embedded fullscreen preserves draft, back and lesson ${mode.name}',
      (tester) async {
        appearance.mode.value = mode;
        tester.view.physicalSize = const Size(844, 390);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        home.showHomeDashboard.value = false;
        home.activeScriptTitle.value = 'Sharing into equal groups';
        final question = QuestionData(
          title: 'Equal groups',
          desc: 'Explain how you checked three equal groups.',
          inputType: QuestionInputType.text,
        );
        home.messages.add(
          ChatMessageModel(
            id: 'draft-question',
            sender: MessageSender.ai,
            text: 'Try one yourself.',
            time: '10:20',
            question: question,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: mode == ThemeMode.light
                ? AptiquTheme.lightTheme
                : AptiquTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
                padding: const EdgeInsets.only(top: 24, bottom: 24),
              ),
              child: RepaintBoundary(
                key: const ValueKey('capture-g'),
                child: child!,
              ),
            ),
            home: const HomeScreen(),
          ),
        );
        await fonts(tester);
        await flush(tester);
        await flush(tester);
        final conversation = find.byKey(
          const ValueKey('embedded-conversation'),
        );
        final before = tester.getSize(conversation).height;
        await tester.tap(find.byTooltip('Fullscreen lesson'));
        await flush(tester);
        expect(home.isFullScreen.value, isTrue);
        expect(tester.getSize(conversation).height, greaterThan(before + 120));
        final scroller = find
            .descendant(of: conversation, matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(
          find.byType(TextField),
          160,
          scrollable: scroller,
        );
        await flush(tester);
        await tester.enterText(
          find.byType(TextField),
          'Three groups of four make twelve.',
        );
        await flush(tester);
        final draft = tester
            .widget<EditableText>(find.byType(EditableText))
            .controller;
        await capture(tester, 'embedded-fullscreen-${mode.name}');
        await tester.tap(find.byTooltip('Exit fullscreen lesson'));
        await flush(tester);
        expect(home.isFullScreen.value, isFalse);
        expect(
          tester.widget<EditableText>(find.byType(EditableText)).controller,
          same(draft),
        );
        expect(draft.text, 'Three groups of four make twelve.');
        await tester.tap(find.byTooltip('Fullscreen lesson'));
        await flush(tester);
        await tester.binding.handlePopRoute();
        await flush(tester);
        expect(home.isFullScreen.value, isFalse);
        expect(question.isCompleted, isFalse);
        expect(Get.find<HomeController>(), same(home));
        expect(adapter.calls, isEmpty);
        await tester.tap(find.byTooltip('Close lesson'));
        await flush(tester);
        expect(home.showHomeDashboard.value, isTrue);
        expect(home.isFullScreen.value, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      },
    );
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      testWidgets(
        'Home detail sheets and Daily preparation ${mode.name} $size',
        (tester) async {
          appearance.mode.value = mode;
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          Future<void> mount(Widget child) async {
            await tester.pumpWidget(
              MaterialApp(
                theme: mode == ThemeMode.light
                    ? AptiquTheme.lightTheme
                    : AptiquTheme.darkTheme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(2),
                    disableAnimations: true,
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                  ),
                  child: RepaintBoundary(
                    key: const ValueKey('capture-g'),
                    child: child!,
                  ),
                ),
                home: AppearanceTheme(
                  builder: (_) => Scaffold(body: SafeArea(child: child)),
                ),
              ),
            );
            await fonts(tester);
            await flush(tester);
            await flush(tester);
          }

          Future<void> reach(Finder target) async {
            if (target.evaluate().isEmpty) {
              await tester.scrollUntilVisible(
                target,
                180,
                scrollable: find.byType(Scrollable).first,
              );
            }
            await tester.ensureVisible(target);
            await flush(tester);
            await tester.tap(target);
            await flush(tester);
            expect(tester.takeException(), isNull);
          }

          await mount(
            HomeDashboardContent(
              data: fixture(populated: true),
              onRefresh: () async {},
              onResume: (_) {},
              onTopics: () {},
              onRanked: () {},
              onPractice: () {},
              onDaily: () {},
            ),
          );
          await reach(find.text('Difficulty Breakdown'));
          expect(find.text('Difficulty Breakdown'), findsOneWidget);
          expect(find.text('View difficulty details'), findsNothing);
          await capture(tester, 'O04-${mode.name}-${size.width.toInt()}');
          await reach(find.text('View all achievements'));
          expect(find.text('A steady start'), findsOneWidget);
          await capture(tester, 'O05-${mode.name}-${size.width.toInt()}');
          await reach(find.byTooltip('Close'));
          await tester.pumpWidget(const SizedBox());
          await flush(tester);
          final daily = Get.put<DailyChallengeController>(d.DailyFixture());
          daily.status.value = d.dailyStatus();
          daily.isLoadingStatus.value = false;
          daily.isStarting.value = true;
          await mount(const DailyStreakHubScreen());
          expect(find.textContaining('Preparing today'), findsOneWidget);
          await capture(tester, 'O09-${mode.name}-${size.width.toInt()}');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await flush(tester);
          await mount(view('S05-topics'));
          await reach(find.text('List'));
          await reach(find.text('Number System'));
          await capture(
            tester,
            'O07-reading-${mode.name}-${size.width.toInt()}',
          );
          final actions = find.byKey(const ValueKey('topic-actions'));
          final sheetScrollable = find
              .descendant(
                of: find.byType(BottomSheet),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            actions,
            180,
            scrollable: sheetScrollable,
          );
          await flush(tester);
          final play = find.descendant(
            of: actions,
            matching: find.byType(FilledButton),
          );
          await tester.ensureVisible(play);
          await flush(tester);
          expect(play.hitTestable(), findsOneWidget);
          expect(
            tester
                .getSize(
                  find.descendant(
                    of: actions,
                    matching: find.byType(FilledButton),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
          await capture(
            tester,
            'O07-actions-${mode.name}-${size.width.toInt()}',
          );
          await reach(find.byTooltip('Close topic details'));
          await tester.pumpWidget(const SizedBox());
          await flush(tester);
        },
      );
    }
    testWidgets(
      'root dialogs and notices follow ${mode.name} with native recovery',
      (tester) async {
        appearance.mode.value = mode;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final catalog = Get.put(
          PracticeCatalogController(repository: GFailedStart()),
        );
        final daily = Get.put<DailyChallengeController>(d.QuietDaily());
        await tester.pumpWidget(
          const RepaintBoundary(key: ValueKey('capture-g'), child: AptiquApp()),
        );
        await fonts(tester);
        await flush(tester);
        AppRouter.router.go('/profile');
        await flush(tester);
        await flush(tester);
        await tester.ensureVisible(find.text('Sign out'));
        await flush(tester);
        await tester.tap(find.text('Sign out'));
        await flush(tester);
        expect(
          Theme.of(tester.element(find.byType(AlertDialog))).brightness,
          mode == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
        final opposite = mode == ThemeMode.light
            ? ThemeMode.dark
            : ThemeMode.light;
        await appearance.setMode(opposite);
        await flush(tester);
        expect(
          Theme.of(tester.element(find.byType(AlertDialog))).brightness,
          opposite == ThemeMode.light ? Brightness.light : Brightness.dark,
        );
        await tester.tap(find.text('Cancel'));
        await flush(tester);
        expect(Get.find<AuthController>().currentUser.value, isNotNull);
        await appearance.setMode(mode);
        await flush(tester);
        await catalog.startPracticeSession();
        await flush(tester);
        final snack = tester.widget<SnackBar>(find.byType(SnackBar));
        final context = tester.element(find.byType(SnackBar));
        expect(
          snack.backgroundColor,
          Theme.of(context).colorScheme.errorContainer,
        );
        final text = snack.content as Text;
        expect(
          text.style!.color,
          Theme.of(context).colorScheme.onErrorContainer,
        );
        expect(text.data, contains('Connection unavailable'));
        final semantics = tester.ensureSemantics();
        await expectLater(
          tester,
          meetsGuideline(
            CustomMinimumContrastGuideline(
              finder: find.descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Text),
              ),
            ),
          ),
        );
        semantics.dispose();
        await capture(tester, 'practice-notice-${mode.name}');
        AppRouter.messengerKey.currentState!.removeCurrentSnackBar();
        await flush(tester);
        daily.activeSession.value = d.dailySession();
        AppRouter.router.go('/daily-challenge-quiz');
        await flush(tester);
        await flush(tester);
        final quizContext = tester.element(find.byType(Scaffold).last);
        await daily.submitAnswer(quizContext);
        await flush(tester);
        expect(
          find.text('Please select an option before submitting.'),
          findsOneWidget,
        );
        await expectLater(
          tester,
          meetsGuideline(
            CustomMinimumContrastGuideline(
              finder: find.descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Text),
              ),
            ),
          ),
        );
        await capture(tester, 'daily-selection-notice-${mode.name}');
        AppRouter.messengerKey.currentState!.removeCurrentSnackBar();
        await flush(tester);
        daily.status.value = d.dailyStatus(finished: true);
        await daily.startDailyChallenge(quizContext);
        await flush(tester);
        expect(
          find.textContaining('You cannot start another attempt today.'),
          findsOneWidget,
        );
        await expectLater(
          tester,
          meetsGuideline(
            CustomMinimumContrastGuideline(
              finder: find.descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Text),
              ),
            ),
          ),
        );
        await capture(tester, 'daily-attempt-notice-${mode.name}');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await flush(tester);
      },
    );
  }

  testWidgets(
    'root follows saved mode and OS, retains route and active draft',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      adapter.type = 'TEXT_INPUT';
      await tester.pumpWidget(
        const RepaintBoundary(key: ValueKey('capture-g'), child: AptiquApp()),
      );
      await fonts(tester);
      await flush(tester);
      AppRouter.router.go('/lesson/sharing');
      await flush(tester);
      await tester.enterText(
        find.byType(TextField),
        'I checked three equal groups.',
      );
      await flush(tester);
      final field = tester.widget<EditableText>(find.byType(EditableText));
      final draft = field.controller;
      ThemeData rootTheme() =>
          Theme.of(tester.element(find.byType(Navigator).first));
      expect(rootTheme().brightness, Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await flush(tester);
      expect(rootTheme().brightness, Brightness.dark);
      await appearance.setMode(ThemeMode.light);
      await flush(tester);
      expect(rootTheme().brightness, Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await flush(tester);
      expect(rootTheme().brightness, Brightness.light);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller,
        same(draft),
      );
      expect(draft.text, 'I checked three equal groups.');
      expect(
        AppRouter.router.routeInformationProvider.value.uri.path,
        '/lesson/sharing',
      );
      expect(
        adapter.calls.where((o) => o.path.endsWith('/lessons/sessions')).length,
        1,
      );
      final reloaded = AppearanceController();
      await reloaded.load();
      expect(reloaded.mode.value, ThemeMode.light);
      await appearance.setMode(ThemeMode.system);
      await flush(tester);
      expect(rootTheme().brightness, Brightness.dark);
      final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(regions.last.value.statusBarIconBrightness, Brightness.light);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );

  testWidgets(
    'unmatched route uses active root theme and readable native recovery',
    (tester) async {
      appearance.mode.value = ThemeMode.light;
      await tester.pumpWidget(
        const RepaintBoundary(key: ValueKey('capture-g'), child: AptiquApp()),
      );
      await fonts(tester);
      await flush(tester);
      AppRouter.router.go('/missing-review-route');
      await flush(tester);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      expect(find.text('Page unavailable'), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await flush(tester);
    },
  );
}
