/// Internal binding implementation for screen_adapt.
library screen_adapt_bindings;

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:screen_adapt/src/core/screen_metrics.dart';
import 'package:screen_adapt/src/widgets/design_size_scope.dart';

/// 屏幕适配的核心 mixin，可与其它自定义 [WidgetsFlutterBinding] mixin 组合使用，
/// 解决和其它依赖自定义 binding 的插件互斥的问题。
///
/// 用法：
/// ```dart
/// class AppBinding extends WidgetsFlutterBinding
///     with OtherPluginBindingMixin, DesignSizeBindingMixin {}
///
/// void main() {
///   DesignSizeBindingMixin.configure(designSize: const Size(360, 690));
///   AppBinding.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// 注意：mixin 中的 `wrapWithDefaultView` 与 `createViewConfigurationFor` 不会调用
/// super，因此 `DesignSizeBindingMixin` 必须放在 `with` 列表的最后，否则会被覆盖。
mixin DesignSizeBindingMixin on WidgetsFlutterBinding {
  static Size? _pendingDesignSize;
  static ScreenAdaptType _pendingAdaptType = ScreenAdaptType.min;
  static bool _pendingScaleText = true;
  static bool _pendingSupportSystemTextScale = true;

  /// 在 binding 实例化前调用，用于把设计稿配置传给 mixin。
  ///
  /// 用 [DesignSizeWidgetsFlutterBinding.ensureInitialized] 时不需要自己调；
  /// 自行组合 binding 时必须在 `ensureInitialized()` 之前调一次。
  static void configure({
    required Size designSize,
    ScreenAdaptType adaptType = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    _pendingDesignSize = designSize;
    _pendingAdaptType = adaptType;
    _pendingScaleText = scaleText;
    _pendingSupportSystemTextScale = supportSystemTextScale;
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
    assert(
      _pendingDesignSize != null,
      'DesignSizeBindingMixin.configure(...) must be called before '
      'ensureInitialized(). Use DesignSizeWidgetsFlutterBinding.ensureInitialized '
      'as a shortcut, or call configure() manually when composing mixins.',
    );
    ScreenSizeUtils.instance.setDesignSize(
      _pendingDesignSize!,
      type: _pendingAdaptType,
      scaleText: _pendingScaleText,
      supportSystemTextScale: _pendingSupportSystemTextScale,
    );
    // 在 super 之前保存：此时拿到的是其它插件在 main 中提前注册的 handler。
    // super.initInstances() 中 GestureBinding 会把它覆盖成自己的默认实现，
    // 那个实现会用未适配的 DPR 重新派发同一份 packet，链下去会重复触发。
    _previousPointerDataPacketCallback =
        PlatformDispatcher.instance.onPointerDataPacket;
    super.initInstances();
    PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
  }

  ui.PointerDataPacketCallback? _previousPointerDataPacketCallback;

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
    // 我们已经替代了 GestureBinding 的默认派发；这里链到我们注册之前就存在的 handler，
    // 让其它插件先前挂的回调继续生效。
    _previousPointerDataPacketCallback?.call(packet);
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

/// 一个自定义的[WidgetsFlutterBinding]，用于提供全局的屏幕适配能力。
///
/// 如果需要与其它依赖自定义 binding 的插件共存，请改用 [DesignSizeBindingMixin]
/// 自行组合 binding。
class DesignSizeWidgetsFlutterBinding extends WidgetsFlutterBinding
    with DesignSizeBindingMixin {
  /// 确保自定义的绑定已经被初始化。
  ///
  /// 这是在 `main` 函数中启动屏幕适配的首选方法。
  static WidgetsBinding ensureInitialized(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    DesignSizeBindingMixin.configure(
      designSize: size,
      adaptType: type,
      scaleText: scaleText,
      supportSystemTextScale: supportSystemTextScale,
    );
    if (WidgetsBinding.instance is! DesignSizeWidgetsFlutterBinding) {
      DesignSizeWidgetsFlutterBinding();
    }
    return WidgetsBinding.instance;
  }
}
