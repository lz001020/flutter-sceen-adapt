import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'screen_size_utils.dart';
import 'strategy/adaptation_strategy.dart';

/// 设计稿适配绑定层
///
/// 职责：
/// 1. 挂钩系统指标变化 (Metrics Changed)，触发策略重新匹配。
/// 2. 拦截并修正手势坐标 (Pointer Data Packet)。
/// 3. 委派策略层生成 [ViewConfiguration] 和 根组件包装逻辑。
class DesignSizeWidgetsFlutterBinding extends WidgetsFlutterBinding {

  /// 初始化入口
  /// [designSize] 设计稿尺寸
  /// [customStrategies] 可选的自定义适配策略列表，优先级高于内置策略
  static WidgetsBinding ensureInitialized({
    required Size designSize,
    List<ScreenAdaptStrategy>? customStrategies,
  }) {
    if (WidgetsBinding.instance is! DesignSizeWidgetsFlutterBinding) {
      DesignSizeWidgetsFlutterBinding();
    }

    // 初始化逻辑中枢
    ScreenSizeUtils.instance.init(
      designSize: designSize,
      customStrategies: customStrategies,
    );

    return WidgetsBinding.instance;
  }

  // ==========================================================
  // 1. 渲染管线挂钩 (View Configuration)
  // ==========================================================

  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    // 逻辑：不再硬编码 DPR 缩放，而是委派给当前匹配的策略。
    // 这允许不同设备（如折叠屏、车机）有完全不同的逻辑约束。
    return ScreenSizeUtils.instance.createViewConfiguration(renderView);
  }

  @override
  void handleMetricsChanged() {
    super.handleMetricsChanged();

    // 当屏幕尺寸、旋转或折叠状态改变时，重新运行策略计算
    ScreenSizeUtils.instance.setup();

    // 强制根节点重绘，以响应 wrapWithDefaultView 层的结构切换（如从 Mobile 切换到 Expanded 窗口模式）
    rootElement?.markNeedsBuild();
  }

  // ==========================================================
  // 2. UI 容器挂钩 (Widget Wrapping)
  // ==========================================================

  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    // 逻辑：将根 Widget 的包装权交给策略。
    // - 在 MobileStrategy 下，可能直接返回 rootWidget。
    // - 在 ExpandedStrategy 下，可能返回带居中容器、背景色和拖动手柄的窗口布局。
    return ScreenSizeUtils.instance.wrapRootWidget(rootWidget);
  }

  // ==========================================================
  // 3. 手势事件修正 (Pointer Interception)
  // ==========================================================

  @override
  void initInstances() {
    super.initInstances();
    // 拦截底层的物理坐标数据包
    ui.PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
  }

  final Queue<PointerEvent> _pendingPointerEvents = Queue<PointerEvent>();

  void _handlePointerDataPacket(ui.PointerDataPacket packet) {
    // 核心逻辑：
    // 如果 UI 窗口因为适配策略产生了位移（TotalOffset），
    // 那么物理层传来的点击坐标必须经过反向变换才能命中正确的 Widget。

    final utils = ScreenSizeUtils.instance;
    final totalOffset = utils.totalOffset;

    // 构建反向平移矩阵
    final transform = Matrix4.translationValues(-totalOffset.dx, -totalOffset.dy, 0);

    // 获取当前策略计算出的适配 DPR
    final currentDpr = utils.currentConfig.dpr;

    try {
      // 1. 物理坐标 -> 逻辑坐标转换
      final events = PointerEventConverter.expand(
        packet.data,
            (viewId) => currentDpr, // 使用适配后的 DPR
      ).map((event) {
        // 2. 应用平移矩阵，修正因为窗口偏移（居中/拖动）产生的误差
        return event.transformed(transform);
      });

      _pendingPointerEvents.addAll(events);

      if (!locked) {
        _flushPointerEventQueue();
      }
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'gestures library',
        context: ErrorDescription('while handling a pointer data packet'),
      ));
    }
  }

  @override
  void unlocked() {
    super.unlocked();
    _flushPointerEventQueue();
  }

  @override
  void cancelPointer(int pointer) {
    if (_pendingPointerEvents.isEmpty && !locked) {
      scheduleMicrotask(_flushPointerEventQueue);
    }
    _pendingPointerEvents.addFirst(PointerCancelEvent(pointer: pointer));
  }

  void _flushPointerEventQueue() {
    assert(!locked);

    while (_pendingPointerEvents.isNotEmpty) {
      handlePointerEvent(_pendingPointerEvents.removeFirst());
    }
  }
}