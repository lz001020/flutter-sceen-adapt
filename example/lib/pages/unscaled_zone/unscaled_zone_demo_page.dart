import 'dart:math' as math;

import 'package:example/widgets/demo_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:screen_adapt/screen_adapt.dart';

class UnscaledZoneDemoPage extends StatefulWidget {
  const UnscaledZoneDemoPage({super.key});

  @override
  State<UnscaledZoneDemoPage> createState() => _UnscaledZoneDemoPageState();
}

class _UnscaledZoneDemoPageState extends State<UnscaledZoneDemoPage> {
  int _normalTapCount = 0;
  int _contextTapCount = 0;
  int _fullTapCount = 0;
  int _reentryAdaptedTapCount = 0;
  int _reentryRecoveredTapCount = 0;
  final _modeMetrics = <String, _ModeBandMetrics>{};
  final _rowMetrics = <String, _VisualMetrics>{};
  final _nestedMetrics = <String, _VisualMetrics>{};
  final _reentryMetrics = <String, _VisualMetrics>{};

  void _handleModeMetrics(String id, _ModeBandMetrics metrics) {
    if (_modeMetrics[id] == metrics) return;
    setState(() {
      _modeMetrics[id] = metrics;
    });
  }

  void _handleNestedMetrics(String id, _VisualMetrics metrics) {
    if (_nestedMetrics[id] == metrics) return;
    setState(() {
      _nestedMetrics[id] = metrics;
    });
  }

  void _handleRowMetrics(String id, _VisualMetrics metrics) {
    if (_rowMetrics[id] == metrics) return;
    setState(() {
      _rowMetrics[id] = metrics;
    });
  }

  void _handleReentryMetrics(String id, _VisualMetrics metrics) {
    if (_reentryMetrics[id] == metrics) return;
    setState(() {
      _reentryMetrics[id] = metrics;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final origin = ScreenSizeUtils.instance.originData ?? mediaQuery;
    final scale = ScreenSizeUtils.instance.scale;
    final unscaledFactor = 1 / scale;
    final overriddenMediaQuery = mediaQuery.copyWith(
      alwaysUse24HourFormat: !origin.alwaysUse24HourFormat,
    );

    return DemoPageScaffold(
      title: 'UnscaledZone',
      subtitle:
          '这一页按当前实现模型拆开验证 context / paint / layout 三层。切换设计稿后，重点看 slotScale、paintScale，以及 DesignSizeWidget 中途重进适配态时是否只补缺失层。',
      children: [
        DemoCard(
          title: 'How To Read',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  '当前实现不是一个“大一统 RenderObject”，而是三层拼装：恢复 context、恢复 paint、可选恢复 layout。'),
              const SizedBox(height: 6),
              const Text(
                  'contextFallback = context + paint；full = context + layout + paint。'),
              const SizedBox(height: 6),
              const Text('slotScale = UnscaledZone 向父布局汇报的占位宽度 / child 逻辑宽度。'),
              const SizedBox(height: 6),
              const Text('paintScale = 屏幕上真实绘制宽度 / child 逻辑宽度。'),
              const SizedBox(height: 6),
              const Text('nextDx = 下一个兄弟组件起点相对 child 起点的距离，用来验证父布局槽位是否变化。'),
              const SizedBox(height: 6),
              Text(
                '当前 scale=${scale.toStringAsFixed(3)}，所以预期：normal = 1.00 / 1.00；'
                'contextFallback = 1.00 / ${unscaledFactor.toStringAsFixed(3)}；'
                'full = ${unscaledFactor.toStringAsFixed(3)} / ${unscaledFactor.toStringAsFixed(3)}。',
              ),
              const SizedBox(height: 6),
              Text(
                '若中途重进适配态又重复做 paint 反缩放，paintScale 会错误掉到 ${(unscaledFactor * unscaledFactor).toStringAsFixed(3)}。',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExpectationPill(
                    label: 'Scale',
                    value: scale.toStringAsFixed(3),
                  ),
                  _ExpectationPill(
                    label: 'Origin MQ',
                    value: formatSize(origin.size),
                  ),
                  _ExpectationPill(
                    label: 'Adapted MQ',
                    value: formatSize(mediaQuery.size),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Mode Comparison',
          subtitle:
              '从外到内看：Parent Viewport -> Layout Bound -> Zone Shell -> 150 x 120 Child。重点只看 4 个值：mqWidth、zoneLogicalWidth、zonePaintWidth、cardPaintScale。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ModeBandSection(
                title: 'Normal adapted',
                expected: '看点：mq=Adapted，zone 逻辑宽度和绘制宽度一致，cardScale=1.00',
                reason: '机制：不回退任何层，context / layout / paint 都保持适配态。',
                metrics: _modeMetrics['normal'],
                child: _MeasuredModeBand(
                  id: 'normal',
                  onMetrics: _handleModeMetrics,
                  childBuilder: (shellKey, cardKey) => _LayoutBoundFrame(
                    child: _ModeBandShell(
                      key: shellKey,
                      color: const Color(0xFFFFE9D8),
                      child: _ProbeCard(
                        key: cardKey,
                        width: 150,
                        height: 120,
                        sizeLabel: '150 x 120 Child',
                        label: 'Normal',
                        color: const Color(0xFFFFD7BA),
                        tapCount: _normalTapCount,
                        onTap: () => setState(() => _normalTapCount++),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ModeBandSection(
                title: 'UnscaledZone.contextFallback',
                expected:
                    '看点：mq=Origin，zoneLogicalWidth 仍是当前可用宽度，zonePaintWidth 和 cardScale 变成 ${unscaledFactor.toStringAsFixed(3)}',
                reason:
                    '机制：只回退 context + paint，不回退 layout，所以 shell 会视觉变窄，但占位语义不变。',
                metrics: _modeMetrics['context'],
                child: _MeasuredModeBand(
                  id: 'context',
                  onMetrics: _handleModeMetrics,
                  childBuilder: (shellKey, cardKey) => _LayoutBoundFrame(
                    child: UnscaledZone(
                      child: _ModeBandShell(
                        key: shellKey,
                        color: const Color(0xFFE9F3FF),
                        child: _ProbeCard(
                          key: cardKey,
                          width: 150,
                          height: 120,
                          sizeLabel: '150 x 120 Child',
                          label: 'contextFallback',
                          color: const Color(0xFFD7ECFF),
                          tapCount: _contextTapCount,
                          onTap: () => setState(() => _contextTapCount++),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _ModeBandSection(
                title: 'UnscaledZone.full',
                expected:
                    '看点：mq=Origin，zoneLogicalWidth 回到 origin 宽度，zonePaintWidth 重新铺满 viewport，cardScale=${unscaledFactor.toStringAsFixed(3)}',
                reason:
                    '机制：同时回退 context + layout + paint，逻辑宽度先恢复，再用 paint 反缩放回当前屏幕。',
                metrics: _modeMetrics['full'],
                child: _MeasuredModeBand(
                  id: 'full',
                  onMetrics: _handleModeMetrics,
                  childBuilder: (shellKey, cardKey) => _LayoutBoundFrame(
                    child: UnscaledZone(
                      mode: UnscaledZoneMode.full,
                      child: _ModeBandShell(
                        key: shellKey,
                        color: const Color(0xFFE3F2DA),
                        child: _ProbeCard(
                          key: cardKey,
                          width: 150,
                          height: 120,
                          sizeLabel: '150 x 120 Child',
                          label: 'full',
                          color: const Color(0xFFD8F2D0),
                          tapCount: _fullTapCount,
                          onTap: () => setState(() => _fullTapCount++),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Row Sibling Impact',
          subtitle:
              '这里只看一件事：右侧 sibling 会不会被左边的逻辑坑位推开。左边固定 150 x 120，右边是 sibling，只保留两个指标：paintWidth 和 nextDx。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RowImpactSection(
                title: 'Normal adapted',
                expected: '看点：paintWidth 和 nextDx 接近，说明 sibling 就贴在左块右边。',
                metrics: _rowMetrics['row-normal'],
                slotWidth: 220,
                slotHeight: 140,
                child: _RowSiblingImpactCase(
                  id: 'row-normal',
                  onMetrics: _handleRowMetrics,
                  childBuilder: (paintKey) => _RowImpactSourceBlock(
                    key: paintKey,
                    color: const Color(0xFFFFD7BA),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _RowImpactSection(
                title: 'UnscaledZone.contextFallback',
                expected:
                    '看点：paintWidth 变小到约 ${(150 / scale).toStringAsFixed(1)}，但 nextDx 仍接近 150，说明 sibling 还在吃原坑位。',
                metrics: _rowMetrics['row-context'],
                slotWidth: 220,
                slotHeight: 140,
                child: _RowSiblingImpactCase(
                  id: 'row-context',
                  onMetrics: _handleRowMetrics,
                  childBuilder: (paintKey) => UnscaledZone(
                    child: _RowImpactSourceBlock(
                      key: paintKey,
                      color: const Color(0xFFD7ECFF),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _RowImpactSection(
                title: 'UnscaledZone.full',
                expected:
                    '看点：paintWidth 和 nextDx 会一起回落到约 ${(150 / scale).toStringAsFixed(1)}，说明 sibling 跟着真实占位走。',
                metrics: _rowMetrics['row-full'],
                slotWidth: 220,
                slotHeight: 140,
                child: _RowSiblingImpactCase(
                  id: 'row-full',
                  onMetrics: _handleRowMetrics,
                  childBuilder: (paintKey) => UnscaledZone(
                    mode: UnscaledZoneMode.full,
                    child: _RowImpactSourceBlock(
                      key: paintKey,
                      color: const Color(0xFFD8F2D0),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'Nested Reuse',
          subtitle:
              '验证嵌套时不会重复反缩放。这里量的是整个 outer subtree 的 slot / paint 结果，所以重点看 subtreePaintScale 是否稳定为 0.50，而不是继续缩到 0.25。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MeasuredProbeSection(
                title: 'Outer full -> Inner full',
                expected:
                    '预期 outer subtree: slotScale=${unscaledFactor.toStringAsFixed(3)}, paintScale=${unscaledFactor.toStringAsFixed(3)}',
                metrics: _nestedMetrics['outer-full'],
                slotWidth: 304,
                slotHeight: 188,
                child: _NestedMeasurementCase(
                  id: 'outer-full',
                  onMetrics: _handleNestedMetrics,
                  outerBuilder: (paintKey) => UnscaledZone(
                    mode: UnscaledZoneMode.full,
                    child: _NestedOuterCard(
                      key: paintKey,
                      title: 'Outer full',
                      color: const Color(0xFFF2ECE3),
                      inner: const UnscaledZone(
                        mode: UnscaledZoneMode.full,
                        child: _NestedInnerCard(
                          label: 'Inner full',
                          color: Color(0xFFC7D9DD),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MeasuredProbeSection(
                title: 'Outer contextFallback -> Inner full',
                expected:
                    '预期 outer subtree: slotScale=1.00, paintScale=${unscaledFactor.toStringAsFixed(3)}',
                metrics: _nestedMetrics['outer-context'],
                slotWidth: 304,
                slotHeight: 188,
                child: _NestedMeasurementCase(
                  id: 'outer-context',
                  onMetrics: _handleNestedMetrics,
                  outerBuilder: (paintKey) => UnscaledZone(
                    child: _NestedOuterCard(
                      key: paintKey,
                      title: 'Outer contextFallback',
                      color: const Color(0xFFE9F3FF),
                      inner: const UnscaledZone(
                        mode: UnscaledZoneMode.full,
                        child: _NestedInnerCard(
                          label: 'Inner full',
                          color: Color(0xFFDDEFCB),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'DesignSizeWidget Re-entry',
          subtitle:
              '中间的 DesignSizeWidget 只会把 MediaQuery 切回适配态，不会清掉祖先已经生效的 render 反缩放。第二个 case 如果实现错误，会把 paintScale 错缩到 0.25。',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MeasuredProbeSection(
                title: 'Outer contextFallback -> DesignSizeWidget',
                expected:
                    '预期 slotScale=1.00, paintScale=${unscaledFactor.toStringAsFixed(3)}；卡片内 mq 应回到 Adapted 值',
                metrics: _reentryMetrics['reentry-adapted'],
                child: _FlowMeasurementProbe(
                  id: 'reentry-adapted',
                  onMetrics: _handleReentryMetrics,
                  childBuilder: (paintKey) => UnscaledZone(
                    child: DesignSizeWidget(
                      child: _ProbeCard(
                        key: paintKey,
                        label: 're-adapted',
                        color: const Color(0xFFFFF1C9),
                        tapCount: _reentryAdaptedTapCount,
                        onTap: () => setState(() => _reentryAdaptedTapCount++),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _MeasuredProbeSection(
                title:
                    'Outer contextFallback -> DesignSizeWidget -> Inner full',
                expected:
                    '预期 slotScale=${unscaledFactor.toStringAsFixed(3)}, paintScale=${unscaledFactor.toStringAsFixed(3)}；卡片内 mq 应恢复 Origin，且不会掉到 ${(unscaledFactor * unscaledFactor).toStringAsFixed(3)}',
                metrics: _reentryMetrics['reentry-recovered'],
                child: _FlowMeasurementProbe(
                  id: 'reentry-recovered',
                  onMetrics: _handleReentryMetrics,
                  childBuilder: (paintKey) => UnscaledZone(
                    child: DesignSizeWidget(
                      child: UnscaledZone(
                        mode: UnscaledZoneMode.full,
                        child: _ProbeCard(
                          key: paintKey,
                          label: 'recovered full',
                          color: const Color(0xFFDFF1D6),
                          tapCount: _reentryRecoveredTapCount,
                          onTap: () =>
                              setState(() => _reentryRecoveredTapCount++),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        DemoCard(
          title: 'MediaQuery Recovery',
          subtitle:
              '手动改写一个非尺寸字段 alwaysUse24HourFormat。若 UnscaledZone 只恢复 size / dpr，这里会失败；当前实现应恢复完整 originData，而不是只改尺寸相关字段。',
          child: MediaQuery(
            data: overriddenMediaQuery,
            child: const Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MediaQueryProbeCard(
                  title: 'Override only',
                  color: Color(0xFFFFEDD6),
                ),
                UnscaledZone(
                  mode: UnscaledZoneMode.full,
                  child: _MediaQueryProbeCard(
                    title: 'Inner UnscaledZone.full',
                    color: Color(0xFFDCEBD4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeBandSection extends StatelessWidget {
  const _ModeBandSection({
    required this.title,
    required this.expected,
    required this.reason,
    required this.child,
    this.metrics,
  });

  final String title;
  final String expected;
  final String reason;
  final Widget child;
  final _ModeBandMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          expected,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666257),
              ),
        ),
        const SizedBox(height: 4),
        Text(
          reason,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF7A7568),
              ),
        ),
        const SizedBox(height: 8),
        if (metrics != null) _ModeBandMetricsTable(metrics: metrics!),
        if (metrics != null) const SizedBox(height: 8),
        DemoSlot(
          width: double.infinity,
          height: 176,
          label: 'Parent Viewport',
          child: child,
        ),
      ],
    );
  }
}

class _MeasuredProbeSection extends StatelessWidget {
  const _MeasuredProbeSection({
    required this.title,
    required this.expected,
    required this.child,
    this.metrics,
    this.slotWidth = 240,
    this.slotHeight = 170,
  });

  final String title;
  final String expected;
  final Widget child;
  final _VisualMetrics? metrics;
  final double slotWidth;
  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          expected,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666257),
              ),
        ),
        const SizedBox(height: 8),
        if (metrics != null) _MetricsTable(metrics: metrics!),
        if (metrics != null) const SizedBox(height: 8),
        DemoSlot(
          width: slotWidth,
          height: slotHeight,
          label: 'Measured viewport',
          child: child,
        ),
      ],
    );
  }
}

class _RowImpactSection extends StatelessWidget {
  const _RowImpactSection({
    required this.title,
    required this.expected,
    required this.child,
    this.metrics,
    this.slotWidth = 220,
    this.slotHeight = 140,
  });

  final String title;
  final String expected;
  final Widget child;
  final _VisualMetrics? metrics;
  final double slotWidth;
  final double slotHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          expected,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF666257),
              ),
        ),
        const SizedBox(height: 8),
        if (metrics != null) _RowImpactMetricsTable(metrics: metrics!),
        if (metrics != null) const SizedBox(height: 8),
        DemoSlot(
          width: slotWidth,
          height: slotHeight,
          label: 'Measured viewport',
          child: child,
        ),
      ],
    );
  }
}

class _ModeBandMetricsTable extends StatelessWidget {
  const _ModeBandMetricsTable({
    required this.metrics,
  });

  final _ModeBandMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ExpectationPill(
          label: 'mqWidth',
          value: metrics.mediaQueryWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'zoneLogical',
          value: metrics.zoneLogicalWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'zonePaint',
          value: metrics.zonePaintWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'cardPaint',
          value: metrics.cardPaintWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'cardScale',
          value: metrics.cardPaintScale.toStringAsFixed(3),
        ),
      ],
    );
  }
}

class _RowImpactMetricsTable extends StatelessWidget {
  const _RowImpactMetricsTable({
    required this.metrics,
  });

  final _VisualMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ExpectationPill(
          label: 'paintWidth',
          value: metrics.paintWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'nextDx',
          value: metrics.nextSiblingDx.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _MetricsTable extends StatelessWidget {
  const _MetricsTable({
    required this.metrics,
  });

  final _VisualMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ExpectationPill(
          label: 'slotScale',
          value: metrics.slotScale.toStringAsFixed(3),
        ),
        _ExpectationPill(
          label: 'paintScale',
          value: metrics.paintScale.toStringAsFixed(3),
        ),
        _ExpectationPill(
          label: 'slotWidth',
          value: metrics.slotWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'paintWidth',
          value: metrics.paintWidth.toStringAsFixed(1),
        ),
        _ExpectationPill(
          label: 'nextDx',
          value: metrics.nextSiblingDx.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _ExpectationPill extends StatelessWidget {
  const _ExpectationPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label  $value'),
    );
  }
}

class _MeasuredModeBand extends StatefulWidget {
  const _MeasuredModeBand({
    required this.id,
    required this.childBuilder,
    required this.onMetrics,
  });

  final String id;
  final Widget Function(Key shellKey, Key cardKey) childBuilder;
  final void Function(String id, _ModeBandMetrics metrics) onMetrics;

  @override
  State<_MeasuredModeBand> createState() => _MeasuredModeBandState();
}

class _MeasuredModeBandState extends State<_MeasuredModeBand> {
  final _shellKey = GlobalKey();
  final _cardKey = GlobalKey();
  bool _frameScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasuredModeBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;

      final shellContext = _shellKey.currentContext;
      final cardContext = _cardKey.currentContext;
      if (shellContext == null || cardContext == null) return;

      final shellRender = shellContext.findRenderObject() as RenderBox?;
      final cardRender = cardContext.findRenderObject() as RenderBox?;
      if (shellRender == null || cardRender == null) return;

      final shellRect = MatrixUtils.transformRect(
        shellRender.getTransformTo(null),
        Offset.zero & shellRender.size,
      );
      final cardRect = MatrixUtils.transformRect(
        cardRender.getTransformTo(null),
        Offset.zero & cardRender.size,
      );
      final mq = MediaQuery.of(shellContext);

      widget.onMetrics(
        widget.id,
        _ModeBandMetrics(
          mediaQueryWidth: mq.size.width,
          zoneLogicalWidth: shellRender.size.width,
          zonePaintWidth: shellRect.width,
          cardLogicalWidth: cardRender.size.width,
          cardPaintWidth: cardRect.width,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: widget.childBuilder(_shellKey, _cardKey),
    );
  }
}

class _FlowMeasurementProbe extends StatelessWidget {
  const _FlowMeasurementProbe({
    required this.id,
    required this.childBuilder,
    required this.onMetrics,
  });

  final String id;
  final Widget Function(Key paintKey) childBuilder;
  final void Function(String id, _VisualMetrics metrics) onMetrics;

  @override
  Widget build(BuildContext context) {
    return _MeasuredFlowRow(
      id: id,
      onMetrics: onMetrics,
      sibling: const _NextSiblingMarker(),
      logicalChildSize: const Size(120, 90),
      childBuilder: childBuilder,
    );
  }
}

class _RowSiblingImpactCase extends StatelessWidget {
  const _RowSiblingImpactCase({
    required this.id,
    required this.childBuilder,
    required this.onMetrics,
  });

  final String id;
  final Widget Function(Key paintKey) childBuilder;
  final void Function(String id, _VisualMetrics metrics) onMetrics;

  @override
  Widget build(BuildContext context) {
    return _MeasuredFlowRow(
      id: id,
      onMetrics: onMetrics,
      sibling: const _RowSiblingBlock(),
      logicalChildSize: const Size(150, 120),
      childBuilder: childBuilder,
    );
  }
}

class _RowImpactSourceBlock extends StatelessWidget {
  const _RowImpactSourceBlock({
    super.key,
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 120,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Text(
        '150 x 120',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _RowSiblingBlock extends StatelessWidget {
  const _RowSiblingBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0x12255EE8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF255EE8),
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: const Color(0xFF255EE8),
              fontWeight: FontWeight.w700,
            ),
        child: const Text(
          'sibling',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _LayoutBoundFrame extends StatelessWidget {
  const _LayoutBoundFrame({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(
          painter: _DashedRoundedRectPainter(
            color: Color(0xFFB8891A),
            radius: 18,
          ),
        ),
        child,
        Positioned(
          top: 4,
          right: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0B8),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFB8891A)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: Text(
                'Layout Bound',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF7A5B11),
                      fontSize: 10,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeBandShell extends StatelessWidget {
  const _ModeBandShell({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0x33000000),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: child,
          ),
        ),
        Positioned(
          top: 4,
          left: 8,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0x22000000)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  'Zone Shell',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dashLength = 8.0;
    const dashGap = 6.0;
    final rect = Offset.zero & size;
    if (rect.isEmpty) return;

    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class _NestedMeasurementCase extends StatelessWidget {
  const _NestedMeasurementCase({
    required this.id,
    required this.outerBuilder,
    required this.onMetrics,
  });

  final String id;
  final Widget Function(Key paintKey) outerBuilder;
  final void Function(String id, _VisualMetrics metrics) onMetrics;

  @override
  Widget build(BuildContext context) {
    return _MeasuredFlowRow(
      id: id,
      onMetrics: onMetrics,
      sibling: const _NextSiblingMarker(
        label: 'outer\nnext',
        height: 112,
      ),
      logicalChildSize: const Size(196, 84),
      childBuilder: outerBuilder,
    );
  }
}

class _MeasuredFlowRow extends StatefulWidget {
  const _MeasuredFlowRow({
    required this.id,
    required this.onMetrics,
    required this.sibling,
    required this.logicalChildSize,
    required this.childBuilder,
  });

  final String id;
  final void Function(String id, _VisualMetrics metrics) onMetrics;
  final Widget sibling;
  final Size logicalChildSize;
  final Widget Function(Key paintKey) childBuilder;

  @override
  State<_MeasuredFlowRow> createState() => _MeasuredFlowRowState();
}

class _MeasuredFlowRowState extends State<_MeasuredFlowRow> {
  final _slotKey = GlobalKey();
  final _paintKey = GlobalKey();
  final _siblingKey = GlobalKey();
  bool _frameScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant _MeasuredFlowRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (!mounted) return;

      final slotContext = _slotKey.currentContext;
      final paintContext = _paintKey.currentContext;
      final siblingContext = _siblingKey.currentContext;
      if (slotContext == null ||
          paintContext == null ||
          siblingContext == null) {
        return;
      }

      final slotRender = slotContext.findRenderObject() as RenderBox?;
      final paintRender = paintContext.findRenderObject() as RenderBox?;
      final siblingRender = siblingContext.findRenderObject() as RenderBox?;
      if (slotRender == null || paintRender == null || siblingRender == null) {
        return;
      }

      final transform = paintRender.getTransformTo(null);
      final paintedRect = MatrixUtils.transformRect(
        transform,
        Offset.zero & paintRender.size,
      );
      final paintOffset = paintRender.localToGlobal(Offset.zero);
      final siblingOffset = siblingRender.localToGlobal(Offset.zero);

      widget.onMetrics(
        widget.id,
        _VisualMetrics(
          slotWidth: slotRender.size.width,
          paintWidth: paintedRect.width,
          nextSiblingDx: siblingOffset.dx - paintOffset.dx,
          slotScale: slotRender.size.width / widget.logicalChildSize.width,
          paintScale: paintedRect.width / widget.logicalChildSize.width,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SlotMarker(
          key: _slotKey,
          child: widget.childBuilder(_paintKey),
        ),
        KeyedSubtree(
          key: _siblingKey,
          child: widget.sibling,
        ),
      ],
    );
  }
}

class _SlotMarker extends SingleChildRenderObjectWidget {
  const _SlotMarker({
    super.key,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => RenderProxyBox();
}

class _ProbeCard extends StatelessWidget {
  const _ProbeCard({
    super.key,
    required this.label,
    required this.color,
    required this.tapCount,
    required this.onTap,
    this.width = 120,
    this.height = 90,
    this.sizeLabel,
  });

  final String label;
  final Color color;
  final int tapCount;
  final VoidCallback onTap;
  final double width;
  final double height;
  final String? sizeLabel;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final mqLabel =
        'mq ${mq.size.width.toStringAsFixed(0)}x${mq.size.height.toStringAsFixed(0)}';
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sizeLabel != null) const SizedBox(height: 18),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                mqLabel,
                style: const TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'dpr ${mq.devicePixelRatio.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              SizedBox(
                height: 20,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 9),
                  ),
                  child: Text('tap $tapCount'),
                ),
              ),
            ],
          ),
          if (sizeLabel != null)
            Positioned(
              top: 0,
              left: 0,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x1A000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    child: Text(
                      sizeLabel!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NestedOuterCard extends StatelessWidget {
  const _NestedOuterCard({
    super.key,
    required this.title,
    required this.color,
    required this.inner,
  });

  final String title;
  final Color color;
  final Widget inner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              inner,
              const _NextSiblingMarker(
                label: 'inner\nnext',
                height: 60,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NestedInnerCard extends StatelessWidget {
  const _NestedInnerCard({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _NextSiblingMarker extends StatelessWidget {
  const _NextSiblingMarker({
    this.label = 'next\nchild',
    this.height = 90,
  });

  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0x12255EE8),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(
            color: Color(0xFF255EE8),
            width: 3,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: const Color(0xFF255EE8),
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _MediaQueryProbeCard extends StatelessWidget {
  const _MediaQueryProbeCard({
    required this.title,
    required this.color,
  });

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final mqLabel =
        'mq ${mq.size.width.toStringAsFixed(0)}x${mq.size.height.toStringAsFixed(0)}';
    return Container(
      width: 144,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            '24h ${mq.alwaysUse24HourFormat}',
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            mqLabel,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'dpr ${mq.devicePixelRatio.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ModeBandMetrics {
  const _ModeBandMetrics({
    required this.mediaQueryWidth,
    required this.zoneLogicalWidth,
    required this.zonePaintWidth,
    required this.cardLogicalWidth,
    required this.cardPaintWidth,
  });

  final double mediaQueryWidth;
  final double zoneLogicalWidth;
  final double zonePaintWidth;
  final double cardLogicalWidth;
  final double cardPaintWidth;

  double get cardPaintScale => cardPaintWidth / cardLogicalWidth;

  @override
  bool operator ==(Object other) {
    return other is _ModeBandMetrics &&
        other.mediaQueryWidth == mediaQueryWidth &&
        other.zoneLogicalWidth == zoneLogicalWidth &&
        other.zonePaintWidth == zonePaintWidth &&
        other.cardLogicalWidth == cardLogicalWidth &&
        other.cardPaintWidth == cardPaintWidth;
  }

  @override
  int get hashCode => Object.hash(
        mediaQueryWidth,
        zoneLogicalWidth,
        zonePaintWidth,
        cardLogicalWidth,
        cardPaintWidth,
      );
}

class _VisualMetrics {
  const _VisualMetrics({
    required this.slotWidth,
    required this.paintWidth,
    required this.nextSiblingDx,
    required this.slotScale,
    required this.paintScale,
  });

  final double slotWidth;
  final double paintWidth;
  final double nextSiblingDx;
  final double slotScale;
  final double paintScale;

  @override
  bool operator ==(Object other) {
    return other is _VisualMetrics &&
        other.slotWidth == slotWidth &&
        other.paintWidth == paintWidth &&
        other.nextSiblingDx == nextSiblingDx &&
        other.slotScale == slotScale &&
        other.paintScale == paintScale;
  }

  @override
  int get hashCode => Object.hash(
        slotWidth,
        paintWidth,
        nextSiblingDx,
        slotScale,
        paintScale,
      );
}
