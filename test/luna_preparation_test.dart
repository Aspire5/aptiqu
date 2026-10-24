import 'dart:convert';
import 'package:aptiqu/core/network/dio_client.dart';
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'support/presentation_fonts.dart';
import 'package:aptiqu/features/practice/models/practice_models.dart';
import 'package:aptiqu/features/practice/repositories/practice_repository.dart';
import 'package:aptiqu/shared/widgets/feedback/app_state_view.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class PreparationAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  PreparationAdapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody response(Object? data, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode({'success': true, 'data': data}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
Map<String, dynamic> session() => {
  'id': 'session',
  'userId': 'learner',
  'subjectId': 'math',
  'topicId': 'numbers',
  'subtopicIds': ['sub'],
  'status': 'ACTIVE',
  'currentIndex': 0,
  'totalQuestions': 10,
  'correctCount': 0,
  'totalTimeMs': 0,
  'xpAwarded': 0,
  'questions': [],
};

void main() {
  setUp(() {
    Get.testMode = true;
    useProductionFontFixtures();
    FlutterSecureStorage.setMockInitialValues({});
    Get.put(DioClient(baseUrl: 'http://invalid.local'));
  });
  tearDown(() => Get.reset());
  test(
    'Luna question keeps hints, explanations and metadata while hiding its internal calculation label',
    () {
      final question = PracticeQuestionModel.fromJson({
        'id': 'q',
        'prompt': 'Add 12 and 8.',
        'options': [],
        'difficulty': 'EASY',
        'estimatedTimeSeconds': 12,
        'calculationMode': 'MENTAL',
        'sourceType': 'LUNA',
        'hints': ['Add the tens.', 'Then the units.'],
        'explanation': '12 + 8 = 20.',
        'method': 'Addition',
        'alternativeExplanation': 'Complete the next ten.',
      });
      expect(question.calculationBadge, isNull);
      expect(question.estimatedTimeSeconds, 12);
      expect(question.hints.length, 2);
      expect(question.explanation, isNotEmpty);
      expect(question.alternativeExplanation, isNotEmpty);
    },
  );
  test(
    'immediate preparation response followed by a recoverable timeout still opens the ready session',
    () async {
      final client = Get.find<DioClient>();
      var starts = 0, polls = 0;
      client.dio.httpClientAdapter = PreparationAdapter((options) async {
        if (options.path == '/practice/sessions') {
          starts++;
          expect(options.headers['Idempotency-Key'], isNotEmpty);
          expect(options.receiveTimeout, const Duration(seconds: 30));
          return response({'id': 'preparation', 'state': 'QUEUED'}, 202);
        }
        if (options.path == '/practice/preparations/preparation') {
          polls++;
          if (polls == 1) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return response({
            'id': 'preparation',
            'state': 'READY',
            'sessionId': 'session',
          });
        }
        if (options.path == '/practice/sessions/session') {
          return response(session());
        }
        throw StateError('Unexpected request ${options.path}');
      });
      final result = await PracticeRepository().createSession(
        subtopicIds: ['sub'],
        timerEnabled: true,
      );
      expect(result.id, 'session');
      expect(result.timerEnabled, isTrue);
      expect(starts, 1);
      expect(polls, 2);
      expect(
        await client.secureStorage.read(key: 'luna_practice_pending_'),
        isNull,
      );
    },
  );
  test(
    'lost initial acknowledgement retries the same request key, not a second batch',
    () async {
      final client = Get.find<DioClient>();
      final keys = <String>[];
      client.dio.httpClientAdapter = PreparationAdapter((options) async {
        if (options.path == '/practice/sessions') {
          keys.add(options.headers['Idempotency-Key'] as String);
          if (keys.length == 1) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return response({'id': 'preparation'}, 202);
        }
        if (options.path == '/practice/preparations/preparation') {
          return response({'state': 'READY', 'sessionId': 'session'});
        }
        if (options.path == '/practice/sessions/session') {
          return response(session());
        }
        throw StateError('Unexpected request');
      });
      expect((await PracticeRepository().createSession()).id, 'session');
      expect(keys.length, 2);
      expect(keys.toSet().length, 1);
    },
  );
  test(
    'app restart resumes the stored preparation without creating a new question batch',
    () async {
      final client = Get.find<DioClient>();
      await client.secureStorage.write(
        key: 'luna_practice_pending_',
        value: jsonEncode({
          'id': 'preparation',
          'requestKey': 'same-key',
          'timerEnabled': false,
          'body': {'smartPicks': false},
        }),
      );
      client.dio.httpClientAdapter = PreparationAdapter((options) async {
        if (options.path == '/practice/preparations/preparation') {
          return response({'state': 'READY', 'sessionId': 'session'});
        }
        if (options.path == '/practice/sessions/session') {
          return response(session());
        }
        throw StateError(
          'A restarted preparation must not POST another session',
        );
      });
      expect(
        (await PracticeRepository().resumePendingPreparation())?.id,
        'session',
      );
    },
  );
  test(
    'backend failure ends preparation and clears the saved handle',
    () async {
      final client = Get.find<DioClient>();
      client.dio.httpClientAdapter = PreparationAdapter(
        (options) async => options.path == '/practice/sessions'
            ? response({'id': 'preparation'}, 202)
            : response({'state': 'FAILED'}),
      );
      await expectLater(
        PracticeRepository().createSession(),
        throwsA(isA<Exception>()),
      );
      expect(
        await client.secureStorage.read(key: 'luna_practice_pending_'),
        isNull,
      );
    },
  );
  for (final entry in [
    ('FAILED', 'LUNA_QUOTA_EXCEEDED', 'temporarily unavailable'),
    ('FAILED', 'QUALITY_REVIEW_FAILED', 'finalise a full set'),
    ('EXPIRED', 'PREPARATION_EXPIRED', 'took too long'),
  ]) {
    test(
      'terminal ${entry.$2} preserves a safe support reference and clears the pending request',
      () async {
        final client = Get.find<DioClient>();
        final records = <String>[];
        final originalPrint = debugPrint;
        debugPrint = (message, {wrapWidth}) {
          if (message != null) records.add(message);
        };
        addTearDown(() => debugPrint = originalPrint);
        client.dio.httpClientAdapter = PreparationAdapter(
          (options) async => options.path == '/practice/sessions'
              ? response({'id': 'preparation-id'}, 202)
              : response({
                  'id': 'preparation-id',
                  'state': entry.$1,
                  'errorCode': entry.$2,
                  'message': 'SECRET_CANARY provider-key prompt contents',
                }),
        );
        await expectLater(
          PracticeRepository().createSession(),
          throwsA(
            isA<PreparationFailed>()
                .having((e) => e.preparationId, 'support id', 'preparation-id')
                .having((e) => e.state, 'state', entry.$1)
                .having((e) => e.code, 'code', entry.$2)
                .having(
                  (e) => e.toString(),
                  'learner message',
                  contains(entry.$3),
                ),
          ),
        );
        expect(
          records.single,
          '[Practice Preparation] id=preparation-id state=${entry.$1} code=${entry.$2}',
        );
        expect(records.join().contains('SECRET_CANARY'), false);
        expect(
          await client.secureStorage.read(key: 'luna_practice_pending_'),
          isNull,
        );
      },
    );
  }
  test(
    'malformed diagnostic fields cannot leak arbitrary server content into logs or notices',
    () {
      final error = PreparationFailed(
        preparationId: 'https://SECRET_CANARY/key',
        state: 'SECRET_CANARY',
        code: 'provider said SECRET_CANARY: key=secret',
      );
      expect(error.preparationId, 'unknown');
      expect(error.state, 'FAILED');
      expect(error.code, 'PREPARATION_FAILED');
      expect('${error.diagnostics} $error'.contains('SECRET_CANARY'), false);
    },
  );
  testWidgets(
    'preparation loader remains readable at narrow phone width and enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AptiquTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: AppStateView(
                  title: 'Finalising your questions…',
                  message: 'This may take a moment.',
                  loading: true,
                  actionLabel: 'Cancel',
                  onAction: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Finalising your questions…'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
