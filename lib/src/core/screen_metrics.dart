// Device adapter and compatibility facade for the single-window controller.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'adapt_controller.dart';
import 'adapt_metrics.dart';

export 'adapt_controller.dart';
export 'adapt_metrics.dart';

class ScreenSizeUtils {
  factory ScreenSizeUtils() => instance;
  static final ScreenSizeUtils instance = ScreenSizeUtils._internal();
  ScreenSizeUtils._internal();

  static const defaultScale = 1.0;
  final AdaptController controller = AdaptController();
  AdaptConfig get config => controller.config;
  AdaptMetrics? get metrics => controller.metrics;

  Size get designSize => config.designSize;
  set designSize(Size value) => controller.setDesignSize(value);
  ScreenAdaptType get adaptType => config.adaptType;
  set adaptType(ScreenAdaptType value) =>
      controller.configure(config.copyWith(adaptType: value));
  bool get scaleText => config.scaleText;
  set scaleText(bool value) =>
      controller.configure(config.copyWith(scaleText: value));
  bool get supportSystemTextScale => config.supportSystemTextScale;
  set supportSystemTextScale(bool value) =>
      controller.configure(config.copyWith(supportSystemTextScale: value));

  // Legacy direct writes remain available until the public API is migrated.
  double? _scale;
  MediaQueryData? _origin;
  MediaQueryData? _data;
  double get scale => _scale ?? metrics?.scale ?? defaultScale;
  set scale(double value) => _scale = value;
  MediaQueryData? get originData => _origin ?? metrics?.origin;
  set originData(MediaQueryData? value) => _origin = value;
  MediaQueryData get data =>
      _data ?? metrics?.adapted ?? const MediaQueryData();
  set data(MediaQueryData value) => _data = value;

  @visibleForTesting
  FlutterView? Function()? debugCurrentViewProvider;

  FlutterView? _currentViewOrNull() {
    final provider = debugCurrentViewProvider;
    if (provider != null) return provider();
    final views = PlatformDispatcher.instance.views;
    return views.isEmpty ? null : views.first;
  }

  void setDesignSize(
    Size size, {
    ScreenAdaptType type = ScreenAdaptType.width,
    bool scaleText = true,
    bool supportSystemTextScale = true,
  }) {
    _refresh(
        config: AdaptConfig(
            designSize: size,
            adaptType: type,
            scaleText: scaleText,
            supportSystemTextScale: supportSystemTextScale));
  }

  void updateDesignSize(Size size) => controller.setDesignSize(size);

  void reset() {
    _scale = null;
    _origin = null;
    _data = null;
    controller.reset();
  }

  /// The only device-reading boundary; repeated inputs are deduplicated by
  /// the controller. Desktop policy is retained for compatibility with tests.
  void setup() => _refresh();

  void _refresh({AdaptConfig? config}) {
    final view = _currentViewOrNull();
    if (view != null &&
        (view.physicalSize.isEmpty ||
            !view.devicePixelRatio.isFinite ||
            view.devicePixelRatio <= 0)) {
      // No valid replacement device input: apply configuration to the last
      // good snapshot instead of publishing transient zero-sized metrics.
      if (config != null) controller.configure(config);
      return;
    }
    final desktop = Platform.isLinux || Platform.isMacOS || Platform.isWindows;
    final override = desktop && scale != defaultScale ? scale : null;
    _scale = null;
    _origin = null;
    _data = null;
    controller.updateDeviceMetrics(
      view == null ? null : MediaQueryData.fromView(view),
      config: config,
      rotateDimensionsInLandscape: !desktop,
      scaleOverride: view == null ? null : override,
    );
  }
}

extension MediaQueryDataExtension on MediaQueryData {
  MediaQueryData design() {
    final utils = ScreenSizeUtils.instance;
    return AdaptCalculator.adaptMediaQuery(
      origin: this,
      scale: utils.scale,
      config: utils.config,
    );
  }
}
