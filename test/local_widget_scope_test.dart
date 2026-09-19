import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';
import 'package:screen_adapt/src/core/adapt_scope.dart';

void main() {
  const origin = MediaQueryData(size: Size(400, 800), devicePixelRatio: 2);
  const adapted = MediaQueryData(size: Size(200, 400), devicePixelRatio: 4);

  Widget scoped(Widget child) {
    return MediaQuery(
      data: adapted,
      child: AdaptScope(
        state: const AdaptScopeState(
          scale: 2,
          originMediaQuery: origin,
          adaptedMediaQuery: adapted,
        ),
        child: child,
      ),
    );
  }

  testWidgets(
      'UnscaledZone without AdaptScope ignores global compatibility state',
      (tester) async {
    final utils = ScreenSizeUtils.instance;
    utils.scale = 2;
    utils.originData = origin;
    utils.data = adapted;
    addTearDown(() {
      utils.scale = 1;
      utils.originData = null;
      utils.data = const MediaQueryData();
    });
    await tester.pumpWidget(
      const MediaQuery(
        data: origin,
        child: Align(
          alignment: Alignment.topLeft,
          child: UnscaledZone(
            child: SizedBox(key: ValueKey('zone'), width: 80, height: 48),
          ),
        ),
      ),
    );

    final box =
        tester.renderObject<RenderBox>(find.byKey(const ValueKey('zone')));
    expect(box.size, const Size(80, 48));
    expect(box.localToGlobal(const Offset(80, 0)).dx, 80);
  });

  testWidgets('LegacyScreenUtilScope restores origin data from AdaptScope',
      (tester) async {
    MediaQueryData? observed;
    await tester.pumpWidget(scoped(LegacyScreenUtilScope(
      child: Builder(builder: (context) {
        observed = MediaQuery.of(context);
        return const SizedBox(width: 20, height: 20);
      }),
    )));

    expect(observed, origin);
  });

  testWidgets('LegacyScreenUtilScope is transparent without AdaptScope',
      (tester) async {
    MediaQueryData? observed;
    await tester.pumpWidget(MediaQuery(
      data: adapted,
      child: LegacyScreenUtilScope(
        child: Builder(builder: (context) {
          observed = MediaQuery.of(context);
          return const SizedBox();
        }),
      ),
    ));

    expect(observed, adapted);
  });

  testWidgets('AdaptedPlatformView consumes scope and current MediaQuery',
      (tester) async {
    const childKey = ValueKey('platform-child');
    var taps = 0;
    await tester.pumpWidget(scoped(Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        height: 100,
        child: AdaptedPlatformView(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(key: childKey),
          ),
        ),
      ),
    )));

    final box = tester.renderObject<RenderBox>(find.byKey(childKey));
    expect(box.size, const Size(100, 50));
    expect(
      box.localToGlobal(const Offset(100, 50)) - box.localToGlobal(Offset.zero),
      const Offset(200, 100),
    );
    await tester.tapAt(const Offset(199, 99));
    expect(taps, 1);
  });

  testWidgets('AdaptedPlatformView is transparent without AdaptScope',
      (tester) async {
    const childKey = ValueKey('plain-platform-child');
    await tester.pumpWidget(const MediaQuery(
      data: adapted,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 200,
          height: 100,
          child: AdaptedPlatformView(child: SizedBox(key: childKey)),
        ),
      ),
    ));

    expect(
      tester.renderObject<RenderBox>(find.byKey(childKey)).size,
      const Size(200, 100),
    );
  });

  testWidgets('PhysicalPixelZone safely degrades for unbounded constraints',
      (tester) async {
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: PhysicalPixelZone(
            child:
                SizedBox(key: ValueKey('pixel-child'), width: 80, height: 40),
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('pixel-child')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nested legacy scopes use nearest snapshot across updates',
      (tester) async {
    MediaQueryData? observed;
    for (final scale in [2.0, 0.5, 1.0]) {
      const innerOrigin = MediaQueryData(
        size: Size(360, 720),
        devicePixelRatio: 3,
      );
      final innerAdapted = innerOrigin.copyWith(
        size: innerOrigin.size / scale,
        devicePixelRatio: 3 * scale,
      );
      await tester.pumpWidget(scoped(AdaptScope(
        state: AdaptScopeState(
            scale: scale,
            originMediaQuery: innerOrigin,
            adaptedMediaQuery: innerAdapted),
        child: MediaQuery(
          data: innerAdapted,
          child: LegacyScreenUtilScope(child: LegacyScreenUtilScope(
            child: Builder(builder: (context) {
              observed = MediaQuery.of(context);
              return const SizedBox();
            }),
          )),
        ),
      )));
      expect(observed, innerOrigin);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('platform wrapper inside full zone does not compensate twice',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(scoped(Align(
      alignment: Alignment.topLeft,
      child: UnscaledZone(
        mode: UnscaledZoneMode.full,
        child: AdaptedPlatformView(
          child: SizedBox(key: key, width: 80, height: 40),
        ),
      ),
    )));
    final box = tester.renderObject<RenderBox>(find.byKey(key));
    expect(box.size, const Size(80, 40));
    expect(
        box.localToGlobal(const Offset(80, 40)) -
            box.localToGlobal(Offset.zero),
        const Offset(40, 20));
    expect(find.byType(Transform), findsNothing);
  });
}
