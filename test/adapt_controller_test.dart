import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:design_scale/design_scale.dart';
import 'package:design_scale/src/core/adapt_controller.dart'
    show updateAdaptDeviceMetrics;
import 'package:design_scale/src/scope/adapt_scope.dart';

class TrackedController extends AdaptController {
  TrackedController({required super.config});
  bool get subscribed => hasListeners;
}

void main() {
  const origin = MediaQueryData(size: Size(400, 800), devicePixelRatio: 2);

  test('device and configuration changes publish only the combined result', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    updateAdaptDeviceMetrics(controller, origin);
    final snapshots = <AdaptMetrics?>[];
    controller.addListener(() => snapshots.add(controller.metrics));
    final nextOrigin = origin.copyWith(size: const Size(600, 1200));
    const nextConfig = AdaptConfig(designSize: Size(150, 300));
    updateAdaptDeviceMetrics(controller, nextOrigin, config: nextConfig);
    expect(snapshots, hasLength(1));
    expect(snapshots.single!.origin, nextOrigin);
    expect(snapshots.single!.config, nextConfig);
    expect(snapshots.single!.scale, 4);
    updateAdaptDeviceMetrics(controller, nextOrigin, config: nextConfig);
    expect(snapshots, hasLength(1));
  });

  test('configuration and device updates publish one coherent snapshot', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400), scaleText: false),
    );
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() {
      notifications++;
      expect(controller.metrics!.config, controller.config);
    });
    updateAdaptDeviceMetrics(controller, origin);
    expect(controller.metrics!.scale, 2);
    final first = controller.metrics;
    updateAdaptDeviceMetrics(controller, origin);
    expect(identical(first, controller.metrics), isTrue);
    expect(notifications, 1);
    controller.setDesignSize(const Size(100, 200));
    expect(notifications, 2);
    expect(controller.metrics!.scale, 4);
    expect(controller.config.scaleText, isFalse);
    updateAdaptDeviceMetrics(
      controller,
      origin.copyWith(viewInsets: const EdgeInsets.only(bottom: 200)),
    );
    expect(notifications, 3);
    expect(controller.metrics!.adapted.viewInsets.bottom, 50);
  });

  test('reset remains unadapted across rotation until explicitly enabled', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    updateAdaptDeviceMetrics(controller, origin);
    controller.setEnabled(false);
    expect(controller.metrics!.scale, 1);
    final rotated = origin.copyWith(size: const Size(800, 400));
    updateAdaptDeviceMetrics(controller, rotated);
    expect(controller.metrics!.adapted, rotated);
    controller.setDesignSize(const Size(200, 400));
    expect(controller.metrics!.scale, 2);
  });

  test(
    'invalid transient metrics retain last result; missing view clears it',
    () {
      final controller = AdaptController(
        config: const AdaptConfig(designSize: Size(200, 400)),
      );
      addTearDown(controller.dispose);
      updateAdaptDeviceMetrics(controller, origin);
      final first = controller.metrics;
      updateAdaptDeviceMetrics(controller, origin.copyWith(size: Size.zero));
      expect(identical(first, controller.metrics), isTrue);
      updateAdaptDeviceMetrics(controller, null);
      expect(controller.metrics, isNull);
      updateAdaptDeviceMetrics(controller, origin);
      expect(controller.metrics!.scale, 2);
    },
  );

  testWidgets('root scope observes controller without a metrics callback', (
    tester,
  ) async {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    controller.configure(const AdaptConfig(designSize: Size(200, 400)));
    updateAdaptDeviceMetrics(controller, origin);
    MediaQueryData? observed;
    late AdaptController actions;
    await tester.pumpWidget(
      AdaptRoot(
        controller: controller,
        child: Builder(
          builder: (context) {
            observed = MediaQuery.of(context);
            actions = AdaptController.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(observed!.size.width, 200);
    actions.setDesignSize(const Size(100, 200));
    await tester.pump();
    expect(observed!.size.width, 100);
    actions.setEnabled(false);
    await tester.pump();
    expect(observed, origin);
    await tester.pumpWidget(const SizedBox());
    controller.setDesignSize(const Size(300, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DesignSize dependency rebuilds when metrics change', (
    tester,
  ) async {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    controller.configure(const AdaptConfig(designSize: Size(200, 400)));
    updateAdaptDeviceMetrics(controller, origin);
    var builds = 0;
    var scale = 0.0;
    await tester.pumpWidget(
      AdaptRoot(
        controller: controller,
        child: Builder(
          builder: (context) {
            builds++;
            scale = AdaptController.of(context).metrics!.scale;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(scale, 2);

    controller.setDesignSize(const Size(100, 200));
    await tester.pump();

    expect(scale, 4);
    expect(builds, 2);
  });

  testWidgets(
    'missing metrics use ambient MediaQuery and notify config readers',
    (tester) async {
      final controller = AdaptController(
        config: const AdaptConfig(designSize: Size(200, 400)),
      );
      addTearDown(controller.dispose);
      MediaQueryData? observed;
      Size? design;
      var builds = 0;
      await tester.pumpWidget(
        MediaQuery(
          data: origin,
          child: AdaptRoot(
            controller: controller,
            child: Builder(
              builder: (context) {
                builds++;
                observed = MediaQuery.of(context);
                design = AdaptController.of(context).config.designSize;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(observed, origin);
      controller.setDesignSize(const Size(100, 200));
      await tester.pump();
      expect(observed, origin);
      expect(design, const Size(100, 200));
      expect(builds, 2);
    },
  );

  test(
    'repeated reset does not notify again with or without device metrics',
    () {
      final controller = AdaptController(
        config: const AdaptConfig(designSize: Size(200, 400)),
      );
      addTearDown(controller.dispose);
      var calls = 0;
      controller.addListener(() => calls++);
      controller.setEnabled(false);
      controller.setEnabled(false);
      expect(calls, 1);
      updateAdaptDeviceMetrics(controller, origin);
      final before = calls;
      controller.setEnabled(false);
      expect(calls, before);
      expect(controller.metrics!.adapted, origin);
    },
  );

  testWidgets('controller context APIs distinguish dependency reads', (
    tester,
  ) async {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    late AdaptController dependent;
    late AdaptController? optional;
    late AdaptController? plain;
    await tester.pumpWidget(
      AdaptRoot(
        controller: controller,
        child: Builder(
          builder: (context) {
            dependent = AdaptController.of(context);
            optional = AdaptController.maybeOf(context);
            plain = AdaptController.read(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(optional, same(dependent));
    expect(plain, same(dependent));
    expect(dependent.enabled, isTrue);
  });

  test('setEnabled preserves configuration and toggles adapted metrics', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    updateAdaptDeviceMetrics(controller, origin);
    controller.setEnabled(false);
    expect(controller.enabled, isFalse);
    expect(controller.config.designSize, const Size(200, 400));
    expect(controller.metrics!.adapted, origin);
    controller.setEnabled(true);
    expect(controller.enabled, isTrue);
    expect(controller.metrics!.scale, 2);
  });

  test('scale-one enable changes notify once and preserve configuration', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(400, 800)),
    );
    addTearDown(controller.dispose);
    updateAdaptDeviceMetrics(controller, origin);
    var calls = 0;
    controller.addListener(() => calls++);
    controller.setEnabled(false);
    expect(calls, 1);
    expect(controller.enabled, isFalse);
    controller.setEnabled(false);
    expect(calls, 1);
    controller.setEnabled(true);
    expect(calls, 2);
    controller.configure(controller.config);
    expect(calls, 2);
  });

  test(
    'invalid configuration is atomic and invalid devices preserve snapshot',
    () {
      final controller = AdaptController(
        config: const AdaptConfig(designSize: Size(200, 400)),
      );
      addTearDown(controller.dispose);
      updateAdaptDeviceMetrics(controller, origin);
      final first = controller.metrics;
      var calls = 0;
      controller.addListener(() => calls++);
      for (final size in [
        Size.zero,
        const Size(-1, 10),
        const Size(double.infinity, 10),
        const Size(double.nan, 10),
      ]) {
        expect(() => controller.setDesignSize(size), throwsArgumentError);
        expect(controller.metrics, same(first));
        updateAdaptDeviceMetrics(controller, origin.copyWith(size: size));
        expect(controller.metrics, same(first));
      }
      for (final dpr in [0.0, -1.0, double.infinity, double.nan]) {
        updateAdaptDeviceMetrics(
          controller,
          origin.copyWith(devicePixelRatio: dpr),
        );
        expect(controller.metrics, same(first));
      }
      expect(calls, 0);
    },
  );

  testWidgets(
    'scope replacement unsubscribes without disposing borrowed state',
    (tester) async {
      final first = TrackedController(
        config: const AdaptConfig(designSize: Size(200, 400)),
      );
      final second = TrackedController(
        config: const AdaptConfig(designSize: Size(100, 200)),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      updateAdaptDeviceMetrics(first, origin);
      updateAdaptDeviceMetrics(second, origin);
      var reads = 0;
      var watches = 0;
      final child = Row(
        textDirection: TextDirection.ltr,
        children: [
          Builder(
            builder: (context) {
              AdaptController.read(context);
              reads++;
              return const SizedBox();
            },
          ),
          Builder(
            builder: (context) {
              AdaptController.of(context);
              watches++;
              return const SizedBox();
            },
          ),
        ],
      );
      await tester.pumpWidget(AdaptRoot(controller: first, child: child));
      first.setEnabled(false);
      await tester.pump();
      expect(reads, 1);
      expect(watches, 2);
      await tester.pumpWidget(AdaptRoot(controller: second, child: child));
      expect(first.subscribed, isFalse);
      expect(second.subscribed, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(second.subscribed, isFalse);
      first.setEnabled(true);
      second.setEnabled(false);
      expect(tester.takeException(), isNull);
    },
  );
}
