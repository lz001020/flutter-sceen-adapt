/// Internal binding implementation for design_scale.
library design_scale_bindings;

import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import '../core/adapt_config.dart';
import '../core/adapt_controller.dart';
import '../scope/adapt_scope.dart';

/// 屏幕适配的核心 mixin，可与其它自定义 [WidgetsFlutterBinding] mixin 组合使用，
/// 组合前应检查其他 mixin 的 view 配置、根包装和指针回调行为。
///
/// 用法：
/// ```dart
/// class AppBinding extends WidgetsFlutterBinding
///     with OtherPluginBindingMixin, DesignSizeBindingMixin {}
///
/// void main() {
///   DesignSizeBindingMixin.configure(designSize: const Size(360, 690));
///   AppBinding();
///   runApp(const MyApp());
/// }
/// ```
///
/// 注意：mixin 中的 `wrapWithDefaultView` 与 `createViewConfigurationFor` 不会调用
/// super，因此 `DesignSizeBindingMixin` 必须放在 `with` 列表的最后，否则会被覆盖。
mixin DesignSizeBindingMixin on WidgetsFlutterBinding {
  late final AdaptController _adaptController;

  double get _adaptedDpr =>
      _adaptController.metrics?.adapted.devicePixelRatio ?? 1.0;
  static Size? _pendingDesignSize;
  static ScreenAdaptType _pendingAdaptType = ScreenAdaptType.min;
  static bool _pendingScaleText = true;
  static bool _pendingSupportSystemTextScale = true;

  /// 在 binding 实例化前调用，用于把设计稿配置传给 mixin。
  ///
  /// 用 [DesignSizeWidgetsFlutterBinding.ensureInitialized] 时不需要自己调；
  /// 自行组合 binding 时必须在创建实例之前调一次；只用于初始化，
  /// 运行时更新应使用 [AdaptController.configure]。
  static void configure({
    required Size designSize,
    ScreenAdaptType adaptType = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    AdaptConfig(designSize: designSize).validate();
    _pendingDesignSize = designSize;
    _pendingAdaptType = adaptType;
    _pendingScaleText = scaleText;
    _pendingSupportSystemTextScale = supportSystemTextScale;
  }

  /// 步骤1：实现自己的屏幕适配逻辑
  @override
  ViewConfiguration createViewConfigurationFor(RenderView renderView) {
    var view = renderView.flutterView;
    if (!view.physicalSize.isFinite ||
        view.physicalSize.isEmpty ||
        !view.devicePixelRatio.isFinite ||
        view.devicePixelRatio <= 0) {
      final previousDpr = _adaptedDpr;
      final fallbackDpr = previousDpr.isFinite && previousDpr > 0
          ? previousDpr
          : 1.0;
      return ViewConfiguration(
        physicalConstraints: BoxConstraints.tight(Size.zero),
        logicalConstraints: BoxConstraints.tight(Size.zero),
        devicePixelRatio: fallbackDpr,
      );
    }
    final BoxConstraints physicalConstraints =
        BoxConstraints.fromViewConstraints(view.physicalConstraints);
    final double devicePixelRatio = _adaptedDpr;
    if (kDebugMode) {
      debugPrint(
        '[design_scale][view_config] view=${view.viewId} '
        'physical=${view.physicalSize} logical=${physicalConstraints / devicePixelRatio} '
        'dpr=$devicePixelRatio scale=${_adaptController.metrics?.scale ?? 1}',
      );
    }
    return ViewConfiguration(
      physicalConstraints: physicalConstraints,
      logicalConstraints: physicalConstraints / devicePixelRatio,
      devicePixelRatio: devicePixelRatio,
    );
  }

  /// 步骤2：在根 Widget 中接入适配容器
  @override
  Widget wrapWithDefaultView(Widget rootWidget) {
    final view = platformDispatcher.implicitView;
    if (view == null) {
      return AdaptRoot(controller: _adaptController, child: rootWidget);
    }
    return View(
      view: view,
      child: AdaptRoot(controller: _adaptController, child: rootWidget),
    );
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
    _adaptController = AdaptController(
      config: AdaptConfig(
        designSize: _pendingDesignSize!,
        adaptType: _pendingAdaptType,
        scaleText: _pendingScaleText,
        supportSystemTextScale: _pendingSupportSystemTextScale,
      ),
    );
    _readDeviceMetrics();
    // 在 super 之前保存：此时拿到的是其它插件在 main 中提前注册的 handler。
    // super.initInstances() 中 GestureBinding 会把它覆盖成自己的默认实现，
    // 那个实现会用未适配的 DPR 重新派发同一份 packet，链下去会重复触发。
    _previousPointerDataPacketCallback =
        PlatformDispatcher.instance.onPointerDataPacket;
    super.initInstances();
    PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
    _adaptController.addListener(_updateAdaptedViews);
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
      final events = PointerEventConverter.expand(
        packet.data,
        _getAdaptedDevicePixelRatio,
      );
      for (final event in events) {
        if (kDebugMode &&
            (event is PointerDownEvent || event is PointerUpEvent)) {
          debugPrint(
            '[design_scale][pointer] type=${event.runtimeType} '
            'view=${event.viewId} position=${event.position} '
            'local=${event.localPosition} dpr=${_getAdaptedDevicePixelRatio(event.viewId)} '
            'scale=${_adaptController.metrics?.scale ?? 1}',
          );
        }
        _pendingPointerEvents.add(event);
      }
      if (!locked) {
        _flushPointerEventQueue();
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'gestures library',
          context: ErrorDescription('while handling a pointer data packet'),
        ),
      );
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
      return _adaptedDpr;
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

  bool _handlingDeviceMetrics = false;

  void _updateAdaptedViews() {
    if (_handlingDeviceMetrics) return;
    for (final renderView in renderViews) {
      renderView.configuration = createViewConfigurationFor(renderView);
    }
  }

  void _readDeviceMetrics() {
    final view = platformDispatcher.implicitView;
    if (view != null &&
        (!view.physicalSize.isFinite ||
            view.physicalSize.isEmpty ||
            !view.devicePixelRatio.isFinite ||
            view.devicePixelRatio <= 0)) {
      return;
    }
    updateAdaptDeviceMetrics(
      _adaptController,
      view == null ? null : MediaQueryData.fromView(view),
    );
  }

  @override
  void handleTextScaleFactorChanged() {
    _readDeviceMetrics();
    super.handleTextScaleFactorChanged();
  }

  @override
  void handleMetricsChanged() {
    _handlingDeviceMetrics = true;
    try {
      _readDeviceMetrics();
      super.handleMetricsChanged();
    } finally {
      _handlingDeviceMetrics = false;
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
  /// 重复调用复用已有适配 binding 和 Controller，并更新配置。
  /// 已有其他类型的 WidgetsBinding 时抛出 [FlutterError]。
  /// 设计尺寸必须有限且大于零，默认策略为 [ScreenAdaptType.min]。
  /// 应在其他 binding 初始化及 runApp 之前调用。
  static WidgetsBinding ensureInitialized(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.min,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    final config = AdaptConfig(
      designSize: size,
      adaptType: type,
      scaleText: scaleText,
      supportSystemTextScale: supportSystemTextScale,
    );
    config.validate();
    WidgetsBinding? existing;
    try {
      existing = WidgetsBinding.instance;
    } on FlutterError {
      // An uninitialized getter throws FlutterError with assertions enabled.
      // Preserve errors from a partially initialized binding in debug builds.
      if (BindingBase.debugBindingType() != null) rethrow;
    } on TypeError {
      // Without assertions, checkInstance's null check throws TypeError.
    }
    if (existing != null && existing is! DesignSizeWidgetsFlutterBinding) {
      throw FlutterError('A different WidgetsBinding is already initialized.');
    }
    DesignSizeBindingMixin.configure(
      designSize: size,
      adaptType: type,
      scaleText: scaleText,
      supportSystemTextScale: supportSystemTextScale,
    );
    final binding = existing == null
        ? DesignSizeWidgetsFlutterBinding()
        : existing as DesignSizeWidgetsFlutterBinding;
    binding._adaptController.configure(config);
    return binding;
  }
}
