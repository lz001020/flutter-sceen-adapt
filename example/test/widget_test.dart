import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('screen_adapt demos'), findsOneWidget);
    expect(find.text('Choose a demo'), findsOneWidget);
    expect(find.text('Adaptation Gallery'), findsOneWidget);
    expect(find.text('UnscaledZone'), findsOneWidget);
    expect(find.text('Pointer Events'), findsOneWidget);

    final listFinder = find.byType(Scrollable);

    await tester.scrollUntilVisible(
      find.text('PlatformView'),
      300,
      scrollable: listFinder,
    );
    expect(find.text('PlatformView'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Physical Pixels'),
      300,
      scrollable: listFinder,
    );
    expect(find.text('Physical Pixels'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Keyboard & Insets'),
      300,
      scrollable: listFinder,
    );
    expect(find.text('Keyboard & Insets'), findsOneWidget);
  });
}
