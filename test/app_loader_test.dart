import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptiqu/shared/widgets/indicators/app_loader.dart';
import 'package:aptiqu/shared/widgets/indicators/aptiqu_loading_indicator.dart';

void main() {
  testWidgets(
    'fast calls never display a loader and slower calls have a stable minimum',
    (tester) async {
      Future<void> show(bool loading) => tester.pumpWidget(
        MaterialApp(
          home: Center(child: AppLoader(loading: loading)),
        ),
      );
      await show(true);
      await tester.pump(const Duration(milliseconds: 150));
      await show(false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AptiquLoadingIndicator), findsNothing);
      await show(true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(AptiquLoadingIndicator), findsOneWidget);
      await show(false);
      expect(find.byType(AptiquLoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 360));
      expect(find.byType(AptiquLoadingIndicator), findsNothing);
    },
  );

  testWidgets(
    'loader fits small button slots and disposal cancels delayed work',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: SizedBox(width: 16, height: 16, child: AppLoader()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );
}
