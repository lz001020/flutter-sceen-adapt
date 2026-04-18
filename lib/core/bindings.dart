/// core/bindings.dart
///
/// Created by longzhi on 2024/7/29
import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/widgets/design_size_widget.dart';

/// 一个自定义的[WidgetsFlutterBinding]，用于提供全局的屏幕适配能力。
class DesignSizeWidgetsFlutterBinding extends WidgetsFlutterBinding {
  /// 使用给定的设计稿尺寸和适配类型初始化绑定。
  ///
  /// [designSize] 是设计稿的逻辑尺寸 (例如: Size(360, 690))。
  /// [adaptType] 是屏幕适配的基准类型 (默认为 [ScreenAdaptType.width])。
  DesignSizeWidgetsFlutterBinding(
    Size designSize, {
    ScreenAdaptType adaptType = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    // 在绑定初始化时，立即设置设计稿尺寸和适配类型。
    ScreenSizeUtils.instance.setDesignSize(
      designSize,
      type: adaptType,
      scaleText: scaleText,
      supportSystemTextScale: supportSystemTextScale,
    );
  }

  /// 确保自定义的绑定已经被初始化。
  ///
  /// 这是在 `main` 函数中启动屏幕适配的首选方法。
  static WidgetsBinding ensureInitialized(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    // 调用构造函数来创建并注册绑定实例
    DesignSizeWidgetsFlutterBinding(
      size,
      adaptType: type,
      scaleText: scaleText,
      supportSystemTextScale: supportSystemTextScale,
    );
    return WidgetsBinding.instance;
  }

  /// 步骤1：实现自己的屏幕适配逻辑
  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    var view = renderView.flutterView;
    ScreenSizeUtils.instance.setup();
    final BoxConstraints physicalConstraints =
        BoxConstraints.fromViewConstraints(view.physicalConstraints);
    final double devicePixelRatio =
        ScreenSizeUtils.instance.data.devicePixelRatio;
    return ViewConfiguration(
      physicalConstraints: physicalConstraints,
      logicalConstraints: physicalConstraints / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// 步骤2：在根 Widget 中接入适配容器
  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    final view = platformDispatcher.implicitView!;
    // 只挂 DesignSizeWidget，由它基于最新 originData 生成 MediaQuery。
    return View(view: view, child: DesignSizeWidget(child: rootWidget));
  }

  /// 步骤3：挂钩 GestureBinding 以处理手势
  @override
  void initInstances() {
    super.initInstances();
    // 关键点：将引擎层的手势包处理逻辑重定向到我们自定义的函数
    PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
  }

  @override
  void unlocked() {
    super.unlocked();
    _flushPointerEventQueue();
  }

  final Queue<PointerEvent> _pendingPointerEvents = Queue<PointerEvent>();

  void _handlePointerDataPacket(ui.PointerDataPacket packet) {
    try {
      _pendingPointerEvents.addAll(
          PointerEventConverter.expand(packet.data, _getAdaptedDevicePixelRatio));
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

  // 动态获取 DPR
  double? _getAdaptedDevicePixelRatio(int viewId) {
    // 获取当前视图的原始 DPR
    final view = platformDispatcher.view(id: viewId);
    if (view == null) return null;

    // 如果是主视图（或者是我们正在适配的视图），应用缩放比例
    // 通常 implicitView 是我们要适配的对象
    if (viewId == platformDispatcher.implicitView?.viewId) {
      return ScreenSizeUtils.instance.data.devicePixelRatio;
    }

    return view.devicePixelRatio;
  }

  @override
  cancelPointer(int pointer) {
    if (_pendingPointerEvents.isEmpty && !locked) {
      scheduleMicrotask(_flushPointerEventQueue);
    }
    _pendingPointerEvents.addFirst(PointerCancelEvent(pointer: pointer));
  }

  _flushPointerEventQueue() {
    assert(!locked);

    while (_pendingPointerEvents.isNotEmpty) {
      handlePointerEvent(_pendingPointerEvents.removeFirst());
    }
  }

  @override
  void handleMetricsChanged() {
    super.handleMetricsChanged();
    // 屏幕参数改变时，重新计算缩放并通知渲染树
    ScreenSizeUtils.instance.setup();
    // 强制更新 RenderView 的配置
    for (var renderView in renderViews) {
      renderView.configuration = createViewConfigurationFor(renderView);
    }
  }
}