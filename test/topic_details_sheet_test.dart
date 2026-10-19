import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'package:aptiqu/core/theme/aptiqu_theme.dart';
import 'package:aptiqu/features/home/models/roadmap_model.dart';
import 'package:aptiqu/features/home/presentation/widgets/topic_details_sheet.dart';
import 'practice_catalog_test.dart' show TestFontManifest;

void main() {
  setUp(() {
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
  });
  for (final config in [(320.0, 1.0), (320.0, 1.8), (390.0, 1.3)]) {
    testWidgets(
      'aligned actions and long lesson list at width ${config.$1}, scale ${config.$2}',
      (tester) async {
        tester.view.physicalSize = Size(config.$1, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        String? played;
        String? practised;
        var wholeTopic = false;
        final topic = LearningMapTopicItemModel(
          roadmapStepId: 'hcf',
          sequence: 2,
          topicId: 'hcf',
          topicName: 'H.C.F. and L.C.M. of Numbers',
          topicSlug: 'hcf',
          importance: 'medium',
          teachingMinutes: 30,
          teachingDepth: 2,
          state: 'IN_PROGRESS',
          scriptAvailable: true,
          totalSubtopics: 13,
          completedSubtopics: 1,
          subtopics: [
            for (var i = 0; i < 13; i++)
              SubtopicItemModel(
                id: '$i',
                scriptSlug: 'script-$i',
                title: i == 0
                    ? 'Factors, Multiples and Prime Factorization'
                    : 'Lesson ${i + 1}',
                sequence: i + 1,
                isCompleted: i == 0,
                isLocked: i == 12,
              ),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AptiquTheme.darkTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(config.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: TopicDetailsSheet(
                topic: topic,
                scrollController: scroll,
                onPracticeTopic: () => wholeTopic = true,
                onPlayTopic: () {},
                onPracticeSubtopic: (st) => practised = st.id,
                onPlaySubtopic: (st) => played = st.id,
              ),
            ),
          ),
        );
        await tester.runAsync(() => GoogleFonts.pendingFonts());
        await tester.pump();
        final firstCard = find.byKey(const ValueKey('subtopic-0'));
        final practice = find.descendant(
          of: firstCard,
          matching: find.byType(OutlinedButton),
        );
        final play = find.descendant(
          of: firstCard,
          matching: find.byType(FilledButton),
        );
        expect(tester.getSize(practice), tester.getSize(play));
        if (config.$2 < 1.6) {
          expect(tester.getTopLeft(practice).dy, tester.getTopLeft(play).dy);
        } else {
          expect(
            tester.getTopLeft(play).dy,
            greaterThan(tester.getTopLeft(practice).dy),
          );
        }
        if (config.$2 == 1) {
          expect(tester.getSize(play).height, greaterThanOrEqualTo(48));
        }
        await tester.ensureVisible(practice);
        await tester.pumpAndSettle();
        await tester.tap(practice);
        await tester.ensureVisible(play);
        await tester.pumpAndSettle();
        await tester.tap(play);
        expect(practised, '0');
        expect(played, '0');
        final footer = find.byKey(const ValueKey('topic-actions'));
        final footerPractice = find.descendant(
          of: footer,
          matching: find.byType(OutlinedButton),
        );
        final footerPlay = find.descendant(
          of: footer,
          matching: find.byType(FilledButton),
        );
        expect(tester.getSize(footerPractice), tester.getSize(footerPlay));
        expect(tester.getSize(footerPlay).height, tester.getSize(play).height);
        final footerPosition = tester.getTopLeft(footer);
        await tester.scrollUntilVisible(
          find.text('Lesson 13'),
          250,
          scrollable: find.byType(Scrollable),
        );
        expect(tester.getTopLeft(footer), footerPosition);
        final locked = find.descendant(
          of: find.byKey(const ValueKey('subtopic-12')),
          matching: find.byType(FilledButton),
        );
        expect(tester.widget<FilledButton>(locked).onPressed, isNull);
        await tester.tap(footerPractice);
        expect(wholeTopic, true);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
