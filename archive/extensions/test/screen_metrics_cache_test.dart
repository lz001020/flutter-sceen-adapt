import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  testWidgets('兼容入口合并配置和设备变化为一次通知', (tester) async {
    final utils = ScreenSizeUtils.instance;
    utils.debugCurrentViewProvider = () => tester.view;
    addTearDown(() {
      utils.debugCurrentViewProvider = null;
      tester.view.reset();
    });
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    utils.scale = 1;
    utils.setDesignSize(const Size(200, 400));
    final snapshots = <AdaptMetrics?>[];
    void record() => snapshots.add(utils.metrics);
    utils.controller.addListener(record);
    addTearDown(() => utils.controller.removeListener(record));

    tester.view.physicalSize = const Size(1200, 2400);
    utils.scale = 1;
    utils.setDesignSize(const Size(150, 300));
    expect(snapshots, hasLength(1));
    expect(snapshots.single!.origin.size, const Size(600, 1200));
    expect(snapshots.single!.config.designSize, const Size(150, 300));
    expect(snapshots.single!.scale, 4);

    snapshots.clear();
    utils.reset();
    expect(snapshots, hasLength(1));
    expect(snapshots.single!.scale, 1);
    utils.reset();
    expect(snapshots, hasLength(1));
  });

  testWidgets('重复指标通知复用相同的适配结果', (tester) async {
    final utils = ScreenSizeUtils.instance;
    utils.debugCurrentViewProvider = () => tester.view;
    addTearDown(() => utils.debugCurrentViewProvider = null);
    utils.setDesignSize(const Size(375, 667));
    await tester.pumpWidget(const SizedBox());

    utils.setup();
    final firstOrigin = utils.originData;
    final firstData = utils.data;
    final firstMetrics = utils.metrics;
    utils.setup();

    expect(identical(utils.originData, firstOrigin), isTrue);
    expect(identical(utils.data, firstData), isTrue);
    expect(identical(utils.metrics, firstMetrics), isTrue);
  });

  testWidgets('窗口、键盘和配置变化使缓存失效', (tester) async {
    final utils = ScreenSizeUtils.instance;
    utils.debugCurrentViewProvider = () => tester.view;
    addTearDown(() {
      utils.debugCurrentViewProvider = null;
      tester.view.reset();
    });
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    utils.scale = 1;
    utils.setDesignSize(const Size(375, 667));

    tester.view.viewInsets = const FakeViewPadding(bottom: 400);
    utils.setup();
    expect(utils.originData!.viewInsets.bottom, 200);
    expect(utils.data.viewInsets.bottom, 200 / utils.scale);

    tester.view.devicePixelRatio = 3;
    utils.setup();
    expect(utils.originData!.devicePixelRatio, 3);
    tester.view.physicalSize = const Size(1334, 750);
    utils.setup();
    expect(utils.originData!.size, const Size(1334 / 3, 250));

    for (final update in <VoidCallback>[
      () => utils.designSize = const Size(320, 640),
      () => utils.adaptType = ScreenAdaptType.height,
      () => utils.scaleText = false,
      () => utils.supportSystemTextScale = false,
      () => utils.scale = 2,
    ]) {
      final previous = utils.data;
      update();
      utils.setup();
      expect(identical(utils.data, previous), isFalse);
      final updated = utils.data;
      utils.setup();
      expect(identical(utils.data, updated), isTrue);
    }

    utils.debugCurrentViewProvider = () => null;
    utils.setup();
    expect(utils.originData, isNull);
    utils.debugCurrentViewProvider = () => tester.view;
    utils.setup();
    expect(utils.originData, isNotNull);
  });

  testWidgets('只更新设计尺寸时保留当前适配策略', (tester) async {
    final utils = ScreenSizeUtils.instance;
    utils.debugCurrentViewProvider = () => tester.view;
    addTearDown(() => utils.debugCurrentViewProvider = null);
    utils.setDesignSize(
      const Size(375, 667),
      type: ScreenAdaptType.height,
      scaleText: false,
      supportSystemTextScale: false,
    );

    utils.updateDesignSize(const Size(390, 844));

    expect(utils.designSize, const Size(390, 844));
    expect(utils.adaptType, ScreenAdaptType.height);
    expect(utils.scaleText, isFalse);
    expect(utils.supportSystemTextScale, isFalse);
    expect(utils.metrics?.config, utils.config);
  });
}
