import 'package:flutter_test/flutter_test.dart';
import 'package:aptiqu/core/bindings/initial_binding.dart';
import 'package:aptiqu/main.dart';

void main() {
  testWidgets('Aptiqu app initial smoke test', (WidgetTester tester) async {
    InitialBinding().dependencies();
    await tester.pumpWidget(const AptiquApp());
    // Pump a single frame rather than pumpAndSettle because of ambient repeating animation
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AptiquApp), findsOneWidget);
  });
}
