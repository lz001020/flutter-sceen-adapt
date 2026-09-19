import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  const origin = MediaQueryData(size: Size(400, 800), devicePixelRatio: 2);

  test('device and configuration changes publish only the combined result', () {
    final controller = AdaptController(
      config: const AdaptConfig(designSize: Size(200, 400)),
    );
    addTearDown(controller.dispose);
    controller.updateDeviceMetrics(origin);
    final snapshots = <AdaptMetrics?>[];
    controller.addListener(() => snapshots.add(controller.metrics));
    final nextOrigin = origin.copyWith(size: const Size(600, 1200));
    const nextConfig = AdaptConfig(designSize: Size(150, 300));
    controller.updateDeviceMetrics(nextOrigin, config: nextConfig);
    expect(snapshots, hasLength(1));
    expect(snapshots.single!.origin, nextOrigin);
    expect(snapshots.single!.config, nextConfig);
    expect(snapshots.single!.scale, 4);
    controller.updateDeviceMetrics(nextOrigin, config: nextConfig);
    expect(snapshots, hasLength(1));
  });

  test('configuration and device updates publish one coherent snapshot', () {
    final controller = AdaptController(
        config:
            const AdaptConfig(designSize: Size(200, 400), scaleText: false));
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() {
      notifications++;
      expect(controller.metrics!.config, controller.config);
    });
    controller.updateDeviceMetrics(origin);
    expect(controller.metrics!.scale, 2);
    final first = controller.metrics;
    controller.updateDeviceMetrics(origin);
    expect(identical(first, controller.metrics), isTrue);
    expect(notifications, 1);
    controller.setDesignSize(const Size(100, 200));
    expect(notifications, 2);
    expect(controller.metrics!.scale, 4);
    expect(controller.config.scaleText, isFalse);
    controller.updateDeviceMetrics(
        origin.copyWith(viewInsets: const EdgeInsets.only(bottom: 200)));
    expect(notifications, 3);
    expect(controller.metrics!.adapted.viewInsets.bottom, 50);
  });

  test('reset remains unadapted across rotation until explicitly enabled', () {
    final controller =
        AdaptController(config: const AdaptConfig(designSize: Size(200, 400)));
    addTearDown(controller.dispose);
    controller.updateDeviceMetrics(origin);
    controller.reset();
    expect(controller.metrics!.scale, 1);
    final rotated = origin.copyWith(size: const Size(800, 400));
    controller.updateDeviceMetrics(rotated);
    expect(controller.metrics!.adapted, rotated);
    controller.setDesignSize(const Size(200, 400));
    expect(controller.metrics!.scale, 2);
  });

  test('invalid transient metrics retain last result; missing view clears it',
      () {
    final controller =
        AdaptController(config: const AdaptConfig(designSize: Size(200, 400)));
    addTearDown(controller.dispose);
    controller.updateDeviceMetrics(origin);
    final first = controller.metrics;
    controller.updateDeviceMetrics(origin.copyWith(size: Size.zero));
    expect(identical(first, controller.metrics), isTrue);
    controller.updateDeviceMetrics(null);
    expect(controller.metrics, isNull);
    controller.updateDeviceMetrics(origin);
    expect(controller.metrics!.scale, 2);
  });

  testWidgets('root scope observes controller without a metrics callback',
      (tester) async {
    final controller = ScreenSizeUtils.instance.controller;
    controller.configure(const AdaptConfig(designSize: Size(200, 400)));
    controller.updateDeviceMetrics(origin);
    MediaQueryData? observed;
    late DesignSizeWidgetState actions;
    await tester.pumpWidget(DesignSizeWidget(child: Builder(builder: (context) {
      observed = MediaQuery.of(context);
      actions = DesignSize.of(context);
      return const SizedBox();
    })));
    expect(observed!.size.width, 200);
    actions.setDesignSize(const Size(100, 200));
    await tester.pump();
    expect(observed!.size.width, 100);
    actions.reset();
    await tester.pump();
    expect(observed, origin);
    await tester.pumpWidget(const SizedBox());
    controller.setDesignSize(const Size(300, 600));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DesignSize dependency rebuilds when metrics change',
      (tester) async {
    final controller = ScreenSizeUtils.instance.controller;
    controller.configure(const AdaptConfig(designSize: Size(200, 400)));
    controller.updateDeviceMetrics(origin);
    var builds = 0;
    var scale = 0.0;
    await tester.pumpWidget(DesignSizeWidget(child: Builder(builder: (context) {
      builds++;
      scale = DesignSize.of(context).metrics!.scale;
      return const SizedBox();
    })));
    expect(scale, 2);

    controller.setDesignSize(const Size(100, 200));
    await tester.pump();

    expect(scale, 4);
    expect(builds, 2);
  });

  testWidgets(
      'missing metrics use ambient MediaQuery and notify config readers',
      (tester) async {
    final utils = ScreenSizeUtils.instance;
    final controller = utils.controller;
    controller.updateDeviceMetrics(null);
    controller.configure(const AdaptConfig(designSize: Size(200, 400)));
    utils.scale = 99;
    utils.originData = const MediaQueryData(size: Size(99, 99));
    addTearDown(() {
      utils.scale = 1;
      utils.originData = null;
    });
    MediaQueryData? observed;
    Size? design;
    var builds = 0;
    await tester.pumpWidget(MediaQuery(
      data: origin,
      child: DesignSizeWidget(child: Builder(builder: (context) {
        builds++;
        observed = MediaQuery.of(context);
        design = DesignSize.of(context).config.designSize;
        return const SizedBox();
      })),
    ));
    expect(observed, origin);
    controller.setDesignSize(const Size(100, 200));
    await tester.pump();
    expect(observed, origin);
    expect(design, const Size(100, 200));
    expect(builds, 2);
  });

  test('repeated reset does not notify again with or without device metrics',
      () {
    final controller = AdaptController();
    addTearDown(controller.dispose);
    var calls = 0;
    controller.addListener(() => calls++);
    controller.reset();
    controller.reset();
    expect(calls, 1);
    controller.updateDeviceMetrics(origin);
    final before = calls;
    controller.reset();
    expect(calls, before);
    expect(controller.metrics!.adapted, origin);
  });
}
