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
    ScreenAdaptType adaptType = ScreenAdaptType.width,
  }) {
    // 在绑定初始化时，立即设置设计稿尺寸和适配类型。
    ScreenSizeUtils.instance.setDesignSize(designSize, type: adaptType);
  }

  /// 确保自定义的绑定已经被初始化。
  ///
  /// 这是在 `main` 函数中启动屏幕适配的首选方法。
  static WidgetsBinding ensureInitialized(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.width,
  }) {
    // 调用构造函数来创建并注册绑定实例
    DesignSizeWidgetsFlutterBinding(size, adaptType: type);
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

  /// 步骤2：在根 Widget 中替换 devicePixelRatio
  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    final view = platformDispatcher.implicitView!;

    final mediaQueryData = ScreenSizeUtils.instance.data;
    rootWidget = MediaQuery(
      data: mediaQueryData,
      child: rootWidget,
    );
    // 注意: DesignSizeWidget 需要是可访问的，它位于 lib/widgets/design_size_widget.dart
    return View(view: view, child: DesignSizeWidget(child: rootWidget));
  }

  /// 步骤3：挂钩 GestureBinding 以处理手势
  @override
  void initInstances() {
    super.initInstances();
    // F GestureBinding
    PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
  }

  @override
  void unlocked() {
    super.unlocked();
    _flushPointerEventQueue();
  }

  final Queue<PointerEvent> _pendingPointerEvents = Queue<PointerEvent>();

  _handlePointerDataPacket(ui.PointerDataPacket packet) {
    try {
      _pendingPointerEvents.addAll(
          PointerEventConverter.expand(packet.data, _devicePixelRatioForView));
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

  double? _devicePixelRatioForView(int viewId) {
    if (viewId == 0) {
      return ScreenSizeUtils.instance.data.devicePixelRatio;
    }
    return platformDispatcher.view(id: viewId)?.devicePixelRatio;
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
}