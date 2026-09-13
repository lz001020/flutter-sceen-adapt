import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/main.dart';

void main() {
  testWidgets('navigate, record independent targets, reset, and inspect zones',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('指针与手势'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(ValueKey('target-$i')));
      await tester.pump();
      expect(find.text('${String.fromCharCode(65 + i)}: 1'), findsOneWidget);
    }
    await tester.drag(
        find.byKey(const ValueKey('drag-area')), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(find.text('横向拖动累计：0.0'), findsNothing);
    await tester.tap(find.byTooltip('重置记录'));
    await tester.pump();
    expect(find.text('A: 0'), findsOneWidget);
    expect(find.text('横向拖动累计：0.0'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('UnscaledZone'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PASS 几何'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
