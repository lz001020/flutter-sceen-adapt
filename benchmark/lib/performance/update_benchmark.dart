import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:ui' show FramePhase;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'mixed_feed_content.dart';

enum UpdateVariant {
  designConst,
  designDynamic,
  screenUtilOptimized,
  screenUtilInline;

  bool get usesScreenUtil =>
      this == screenUtilOptimized || this == screenUtilInline;

  bool get reusesStaticTree =>
      this == designConst || this == screenUtilOptimized;
}

enum UpdateScenario { parentRebuild, localUpdate, complexParentRebuild }

const complexFeedCardCount = 12;

TextStyle benchmarkTextStyle(double size, double scale) => TextStyle(
  inherit: false,
  color: const Color(0xFF17243A),
  fontSize: size * scale,
  height: 1.25,
  letterSpacing: 0,
  fontWeight: FontWeight.w400,
  fontFamily: 'sans-serif',
);

/// Counts only the named benchmark boundaries, not every Flutter widget build.
class UpdateBuildCounts {
  static bool recording = false;
  static int grid = 0;
  static int card = 0;
  static int details = 0;
  static int price = 0;
  static int complexFeed = 0;
  static int complexCard = 0;

  static void reset() {
    grid = 0;
    card = 0;
    details = 0;
    price = 0;
    complexFeed = 0;
    complexCard = 0;
  }

  static Map<String, int> snapshot() => {
    'grid': grid,
    'card': card,
    'details': details,
    'price': price,
    'complexFeed': complexFeed,
    'complexCard': complexCard,
  };
}

class UpdateWorkloadController {
  UpdateWorkloadController(this.scenario);

  final UpdateScenario scenario;
  final ValueNotifier<int> parentTick = ValueNotifier(0);
  final List<ValueNotifier<int>> prices = List.generate(
    8,
    (_) => ValueNotifier(0),
  );
  int steps = 0;

  void advance() {
    if (scenario == UpdateScenario.parentRebuild ||
        scenario == UpdateScenario.complexParentRebuild) {
      parentTick.value++;
    } else {
      final index = steps % prices.length;
      prices[index].value++;
    }
    steps++;
  }

  void dispose() {
    parentTick.dispose();
    for (final price in prices) {
      price.dispose();
    }
  }
}

class UpdateBenchmarkView extends StatelessWidget {
  const UpdateBenchmarkView({
    super.key,
    required this.variant,
    required this.controller,
  });

  final UpdateVariant variant;
  final UpdateWorkloadController controller;

  @override
  Widget build(BuildContext context) {
    final scale = variant.usesScreenUtil ? ScreenUtil().scaleWidth : 1.0;
    final font = variant.usesScreenUtil ? ScreenUtil().scaleText : 1.0;
    Widget content() {
      if (controller.scenario == UpdateScenario.complexParentRebuild) {
        return switch (variant) {
          UpdateVariant.designConst => const _ComplexFeed(
            variant: UpdateVariant.designConst,
          ),
          UpdateVariant.designDynamic ||
          UpdateVariant.screenUtilInline => _ComplexFeed(variant: variant),
          UpdateVariant.screenUtilOptimized => const _ComplexFeed(
            variant: UpdateVariant.screenUtilOptimized,
          ),
        };
      }
      return switch (variant) {
        UpdateVariant.designConst => const _ProductGrid(
          variant: UpdateVariant.designConst,
        ),
        UpdateVariant.designDynamic ||
        UpdateVariant.screenUtilInline => _ProductGrid(variant: variant),
        UpdateVariant.screenUtilOptimized => const _ProductGrid(
          variant: UpdateVariant.screenUtilOptimized,
        ),
      };
    }

    final stableContent = variant.reusesStaticTree ? content() : null;
    final scenarioLabel =
        controller.scenario == UpdateScenario.complexParentRebuild
        ? '复杂信息流'
        : '商品信息';
    return _ControllerScope(
      controller: controller,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: ValueListenableBuilder<int>(
              valueListenable: controller.parentTick,
              child: stableContent,
              builder: (context, tick, child) {
                final body = child ?? content();
                return Column(
                  children: [
                    SizedBox(
                      key: const ValueKey('benchmarkHeader'),
                      height: 32 * scale,
                      child: Center(
                        child: Text(
                          '$scenarioLabel · ${tick % 2 == 0 ? 'A' : 'B'}',
                          style: benchmarkTextStyle(14, font),
                        ),
                      ),
                    ),
                    Expanded(
                      child: const bool.fromEnvironment('PERF_ISOLATE_PAINT')
                          ? RepaintBoundary(child: body)
                          : body,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ControllerScope extends InheritedWidget {
  const _ControllerScope({required this.controller, required super.child});

  final UpdateWorkloadController controller;

  @override
  bool updateShouldNotify(_ControllerScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.variant});

  final UpdateVariant variant;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.grid++;
    final controller =
        (context.getInheritedWidgetOfExactType<_ControllerScope>()!).controller;
    // ScreenUtil's optimized const subtree must still react to window changes.
    if (variant == UpdateVariant.screenUtilOptimized) {
      MediaQuery.sizeOf(context);
    }
    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          Expanded(
            child: Row(
              children: [
                for (var column = 0; column < 2; column++)
                  Expanded(
                    child: _ProductCard(
                      variant: variant,
                      index: row * 2 + column,
                      price: controller.prices[row * 2 + column],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.variant,
    required this.index,
    required this.price,
  });

  final UpdateVariant variant;
  final int index;
  final ValueNotifier<int> price;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.card++;
    final scale = variant.usesScreenUtil ? ScreenUtil().scaleWidth : 1.0;
    return Padding(
      padding: EdgeInsets.all(4 * scale),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F6FC),
          borderRadius: BorderRadius.circular(8 * scale),
          border: Border.all(color: const Color(0xFFBACBE1), width: scale),
        ),
        child: Padding(
          padding: EdgeInsets.all(8 * scale),
          child: ValueListenableBuilder<int>(
            valueListenable: price,
            // Passing a stable child is the normal ScreenUtil optimization.
            child: variant.reusesStaticTree
                ? _ProductDetails(variant: variant, index: index)
                : null,
            builder: (context, value, staticChild) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      staticChild ??
                      _ProductDetails(variant: variant, index: index),
                ),
                _Price(value: value, usesScreenUtil: variant.usesScreenUtil),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetails extends StatelessWidget {
  const _ProductDetails({required this.variant, required this.index});

  final UpdateVariant variant;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.details++;
    final scale = variant.usesScreenUtil ? ScreenUtil().scaleWidth : 1.0;
    final font = variant.usesScreenUtil ? ScreenUtil().scaleText : 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('商品 ${index + 1}', style: benchmarkTextStyle(16, font)),
        SizedBox(height: 4 * scale),
        Text('规格 · 现货', style: benchmarkTextStyle(12, font)),
        SizedBox(height: 4 * scale),
        Container(
          width: 72 * scale,
          height: 12 * scale,
          decoration: const BoxDecoration(color: Color(0xFFB9D8F2)),
        ),
      ],
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.value, required this.usesScreenUtil});

  final int value;
  final bool usesScreenUtil;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.price++;
    final font = usesScreenUtil ? ScreenUtil().scaleText : 1.0;
    return Text('¥${99 + value}', style: benchmarkTextStyle(14, font));
  }
}

/// A deliberately expensive static subtree for parent-update comparisons.
///
/// It uses the same deterministic local content as the mixed-feed workload:
/// cached local images, rich text, variable-height cards, chips, shadows,
/// clipping and custom-painted charts. No network or random input is used.
class _ComplexFeed extends StatelessWidget {
  const _ComplexFeed({required this.variant});

  final UpdateVariant variant;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.complexFeed++;
    if (variant == UpdateVariant.screenUtilOptimized) {
      // Keep the optimized ScreenUtil subtree responsive to window changes.
      MediaQuery.sizeOf(context);
    }
    final scale = variant.usesScreenUtil ? ScreenUtil().scaleWidth : 1.0;
    final font = variant.usesScreenUtil ? ScreenUtil().scaleText : 1.0;
    double size(double value) => value * scale;
    double text(double value) => value * font;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(size(14), size(12), size(14), 0),
            child: Row(
              children: [
                Text('为你推荐', style: benchmarkTextStyle(20, font)),
                const Spacer(),
                Text('12 条内容', style: benchmarkTextStyle(12, font)),
              ],
            ),
          ),
          for (var index = 0; index < complexFeedCardCount; index++)
            _ComplexCard(index: index, scale: size, font: text),
        ],
      ),
    );
  }
}

class _ComplexCard extends StatelessWidget {
  const _ComplexCard({
    required this.index,
    required this.scale,
    required this.font,
  });

  final int index;
  final FeedScale scale;
  final FeedScale font;

  @override
  Widget build(BuildContext context) {
    if (UpdateBuildCounts.recording) UpdateBuildCounts.complexCard++;
    return MixedFeedCard(
      index: index,
      scale: scale,
      font: font,
      expanded: false,
    );
  }
}

class UpdateBenchmarkApp extends StatefulWidget {
  const UpdateBenchmarkApp({
    super.key,
    required this.variant,
    required this.scenario,
  });

  final UpdateVariant variant;
  final UpdateScenario scenario;

  @override
  State<UpdateBenchmarkApp> createState() => _UpdateBenchmarkAppState();
}

class _UpdateBenchmarkAppState extends State<UpdateBenchmarkApp> {
  static const warmupUpdates = 30;
  static const measuredUpdates = 180;
  late final UpdateWorkloadController controller;
  final List<int> totalUs = [];
  final List<int> uiUs = [];
  final List<int> rasterUs = [];
  final List<int> vsyncUs = [];
  final List<int> gapUs = [];
  final List<FrameTiming> rawFrames = [];
  static const diagnostics = bool.fromEnvironment('PERF_DIAGNOSTICS');
  bool collecting = false;

  @override
  void initState() {
    super.initState();
    controller = UpdateWorkloadController(widget.scenario);
    SchedulerBinding.instance.addTimingsCallback(_record);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _record(List<FrameTiming> frames) {
    if (!collecting) return;
    for (final frame in frames) {
      totalUs.add(frame.totalSpan.inMicroseconds);
      uiUs.add(frame.buildDuration.inMicroseconds);
      rasterUs.add(frame.rasterDuration.inMicroseconds);
      vsyncUs.add(frame.vsyncOverhead.inMicroseconds);
      gapUs.add(
        frame.totalSpan.inMicroseconds -
            frame.vsyncOverhead.inMicroseconds -
            frame.buildDuration.inMicroseconds -
            frame.rasterDuration.inMicroseconds,
      );
      if (diagnostics) rawFrames.add(frame);
    }
  }

  int _percentile(List<int> values, int percentile) {
    final sorted = List<int>.of(values)..sort();
    return sorted[((sorted.length - 1) * percentile / 100).round()];
  }

  Future<void> _run() async {
    if (widget.scenario == UpdateScenario.complexParentRebuild) {
      // Keep image decoding out of the measured parent-update window.
      await precacheImage(const AssetImage('assets/feed.png'), context);
    }
    await Future<void>.delayed(const Duration(seconds: diagnostics ? 5 : 1));
    for (var i = 0; i < warmupUpdates; i++) {
      if (!mounted) return;
      controller.advance();
      await WidgetsBinding.instance.endOfFrame;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    UpdateBuildCounts.reset();
    UpdateBuildCounts.recording = true;
    collecting = true;
    final measurement = diagnostics
        ? (developer.TimelineTask()..start('update.measurement'))
        : null;
    for (var i = 0; i < measuredUpdates; i++) {
      if (!mounted) return;
      controller.advance();
      await WidgetsBinding.instance.endOfFrame;
    }
    measurement?.finish();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    collecting = false;
    UpdateBuildCounts.recording = false;
    if (totalUs.length < measuredUpdates - 10) {
      debugPrint(
        '[demo:update_benchmark] error=insufficientFrames frames=${totalUs.length}',
      );
      return;
    }
    final result = <String, Object>{
      'variant': widget.variant.name,
      'isolatePaint': const bool.fromEnvironment('PERF_ISOLATE_PAINT'),
      'scenario': widget.scenario.name,
      'warmupUpdates': warmupUpdates,
      'updates': measuredUpdates,
      'frames': totalUs.length,
      ...UpdateBuildCounts.snapshot(),
      'uiP90Us': _percentile(uiUs, 90),
      'uiP99Us': _percentile(uiUs, 99),
      'rasterP90Us': _percentile(rasterUs, 90),
      'vsyncP90Us': _percentile(vsyncUs, 90),
      'gapP90Us': _percentile(gapUs, 90),
      'totalP90Us': _percentile(totalUs, 90),
      'totalP99Us': _percentile(totalUs, 99),
      'over16667Us': totalUs.where((value) => value > 16667).length,
    };
    debugPrint('[demo:update_benchmark] ${jsonEncode(result)}');
    if (diagnostics) {
      for (var i = 0; i < rawFrames.length; i++) {
        final frame = rawFrames[i];
        debugPrint(
          '[demo:update_frame] ${jsonEncode({'index': i, 'vsyncStartUs': frame.timestampInMicroseconds(FramePhase.vsyncStart), 'buildStartUs': frame.timestampInMicroseconds(FramePhase.buildStart), 'buildFinishUs': frame.timestampInMicroseconds(FramePhase.buildFinish), 'rasterStartUs': frame.timestampInMicroseconds(FramePhase.rasterStart), 'rasterFinishUs': frame.timestampInMicroseconds(FramePhase.rasterFinish)})}',
        );
      }
    }
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_record);
    UpdateBuildCounts.recording = false;
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UpdateBenchmarkView(variant: widget.variant, controller: controller);
}
