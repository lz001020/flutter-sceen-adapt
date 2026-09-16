// Internal screen metrics and media-query adaptation helpers.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// 定义屏幕适配的基准。
enum ScreenAdaptType {
  /// 基于屏幕宽度进行适配。
  width,

  /// 基于屏幕高度进行适配。
  height,

  /// 基于屏幕宽度和高度中的最小值进行适配。
  min,
}

/// 用于管理屏幕适配参数的核心工具类。
class ScreenSizeUtils {
  /// 设计稿尺寸
  Size designSize = Size.zero;

  /// 屏幕适配基准类型
  ScreenAdaptType adaptType = ScreenAdaptType.width;

  /// 原始的MediaQueryData
  MediaQueryData? originData;

  /// 适配后的MediaQueryData
  MediaQueryData data = const MediaQueryData();

  /// 默认缩放比例
  static const defaultScale = 1.0;

  /// 当前缩放比例
  double scale = defaultScale;

  /// 是否让字体跟随 UI 进行缩放
  bool scaleText = true;

  /// 是否支持系统字体缩放大小设置
  bool supportSystemTextScale = true;

  /// 是否为桌面平台
  bool _isDesktop = false;

  MediaQueryData? _lastSetupInput;
  FlutterView? _lastSetupView;
  Object? _lastSetupState;

  Object get _setupState => (
        designSize,
        adaptType,
        scaleText,
        supportSystemTextScale,
        scale,
        originData,
        data,
      );

  void _rememberSetup(FlutterView view) {
    _lastSetupInput = originData;
    _lastSetupView = view;
    _lastSetupState = _setupState;
  }

  // 单例实现
  factory ScreenSizeUtils() => instance;
  static final ScreenSizeUtils instance = _getInstance();
  static ScreenSizeUtils? _instance;

  static ScreenSizeUtils _getInstance() =>
      _instance ??= ScreenSizeUtils._internal();

  ScreenSizeUtils._internal();

  @visibleForTesting
  FlutterView? Function()? debugCurrentViewProvider;

  FlutterView? _currentViewOrNull() {
    final debugProvider = debugCurrentViewProvider;
    if (debugProvider != null) return debugProvider();

    final views = PlatformDispatcher.instance.views;
    if (views.isEmpty) return null;
    return views.first;
  }

  void _resetToFallbackMetrics() {
    originData = null;
    _lastSetupInput = null;
    data = const MediaQueryData();
    scale = defaultScale;
  }

  bool _detectDesktopPlatform() {
    return Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  }

  /// 设置设计稿尺寸以及可选的适配类型和字体策略。
  void setDesignSize(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.width,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    designSize = size;
    adaptType = type;
    this.scaleText = scaleText;
    this.supportSystemTextScale = supportSystemTextScale;
    _isDesktop = _detectDesktopPlatform();
    _lastSetupInput = null;
    setup();
  }

  /// 将适配重置为原始的屏幕指标。
  reset() {
    _isDesktop = _detectDesktopPlatform();
    final view = _currentViewOrNull();
    if (view == null) {
      designSize = Size.zero;
      _resetToFallbackMetrics();
      scaleText = true;
      supportSystemTextScale = true;
      return;
    }

    originData = MediaQueryData.fromView(view);
    designSize = originData!.size; // 将设计稿尺寸重置为当前屏幕尺寸
    if (designSize.width > designSize.height && !_isDesktop) {
      // 横竖屏切换
      designSize = designSize.flipped;
    }
    scale = defaultScale;
    data = originData!;
    scaleText = true;
    supportSystemTextScale = true;
    _rememberSetup(view);
  }

  /// 根据所选的 [adaptType] 设置屏幕适配参数。
  setup() {
    _isDesktop = _detectDesktopPlatform();
    final view = _currentViewOrNull();
    // Flutter 在窗口创建、销毁或旋转过渡期间可能短暂报告 0 尺寸/0 DPR。
    // 此时保留上一份有效指标，避免后续除法产生 NaN。
    if (view == null ||
        view.physicalSize.isEmpty ||
        !view.devicePixelRatio.isFinite ||
        view.devicePixelRatio <= 0) {
      if (view == null) _resetToFallbackMetrics();
      return;
    }

    final currentData = MediaQueryData.fromView(view);
    if (identical(_lastSetupView, view) &&
        _lastSetupInput == currentData &&
        _lastSetupState == _setupState &&
        originData != null) {
      return;
    }
    originData = currentData;

    if (designSize.isEmpty) {
      designSize = originData!.size;
      if (designSize.width > designSize.height && !_isDesktop) {
        designSize = designSize.flipped;
      }
      scale = defaultScale;
      data = originData!;
      _rememberSetup(view);
      return;
    }

    if (_isDesktop && scale != defaultScale) {
      data = originData!.design(); // 对于桌面端，如果 scale 是自定义的，则应用它
      _rememberSetup(view);
      return;
    }

    double currentWidth = originData!.size.width;
    double currentHeight = originData!.size.height;

    // 处理非桌面设备的横屏情况
    if (view.physicalSize.width > view.physicalSize.height && !_isDesktop) {
      // 在横屏模式下，如果按宽度或最小值适配，则翻转参考尺寸
      currentWidth = originData!.size.height; // 使用高度作为横屏适配的有效宽度
      currentHeight = originData!.size.width; // 使用宽度作为有效高度
    }

    switch (adaptType) {
      case ScreenAdaptType.width:
        scale = currentWidth / designSize.width;
        break;
      case ScreenAdaptType.height:
        scale = currentHeight / designSize.height;
        break;
      case ScreenAdaptType.min:
        scale = (currentWidth < currentHeight ? currentWidth : currentHeight) /
            (designSize.width < designSize.height
                ? designSize.width
                : designSize.height);
        break;
    }

    data = originData!.design();
    _rememberSetup(view);
  }
}

extension MediaQueryDataExtension on MediaQueryData {
  /// 基于[ScreenSizeUtils]中的缩放比例[scale]来适配当前的[MediaQueryData]
  MediaQueryData design() {
    final scale = ScreenSizeUtils.instance.scale;

    final utils = ScreenSizeUtils.instance;
    // 保留系统 TextScaler 的非线性曲线。只读取 scale(1) 再构造线性
    // TextScaler 会让大字号被错误放大（例如 28 -> 36.4）。
    TextScaler adaptedTextScaler =
        utils.supportSystemTextScale ? textScaler : TextScaler.noScaling;
    if (!utils.scaleText && scale != ScreenSizeUtils.defaultScale) {
      adaptedTextScaler = _DividedTextScaler(adaptedTextScaler, scale);
    }

    return copyWith(
      size: size / scale,
      devicePixelRatio: devicePixelRatio * scale,
      viewInsets: viewInsets / scale,
      viewPadding: viewPadding / scale,
      padding: padding / scale,
      textScaler: adaptedTextScaler,
    );
  }
}

/// 将文字缩放结果按 UI scale 调整，同时保留底层 scaler 的非线性行为。
class _DividedTextScaler implements TextScaler {
  const _DividedTextScaler(this.delegate, this.divisor);

  final TextScaler delegate;
  final double divisor;

  @override
  // TextScaler still requires this compatibility getter in Flutter 3.35.
  // ignore: deprecated_member_use
  double get textScaleFactor => delegate.textScaleFactor / divisor;

  @override
  double scale(double fontSize) => delegate.scale(fontSize) / divisor;

  @override
  TextScaler clamp(
      {double minScaleFactor = 0, double maxScaleFactor = double.infinity}) {
    return _DividedTextScaler(
      delegate.clamp(
        minScaleFactor: minScaleFactor * divisor,
        maxScaleFactor: maxScaleFactor * divisor,
      ),
      divisor,
    );
  }

  @override
  String toString() => '$delegate / $divisor';

  @override
  bool operator ==(Object other) =>
      other is _DividedTextScaler &&
      other.delegate == delegate &&
      other.divisor == divisor;

  @override
  int get hashCode => Object.hash(delegate, divisor);
}
