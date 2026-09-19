import 'package:flutter/widgets.dart';

import 'adapt_metrics.dart';

/// Owns adaptation state without reading a FlutterView or calling a binding.
class AdaptController extends ChangeNotifier {
  AdaptController(
      {AdaptConfig config = const AdaptConfig(designSize: Size.zero)})
      : _config = config;

  AdaptConfig _config;
  AdaptMetrics? _metrics;
  MediaQueryData? _origin;
  bool _rotateDimensions = true;
  double? _scaleOverride;
  bool _enabled = true;

  AdaptConfig get config => _config;
  AdaptMetrics? get metrics => _metrics;

  void configure(AdaptConfig config) {
    if (_config == config && _enabled) return;
    _config = config;
    _enabled = true;
    _recalculate();
  }

  void setDesignSize(Size size) =>
      configure(_config.copyWith(designSize: size));

  /// Device reads and platform policy belong to the caller.
  ///
  /// Supply [config] when device metrics and configuration must change
  /// together. Subscribers receive only the combined result. Invalid device
  /// input is ignored; use [configure] to update only the configuration.
  void updateDeviceMetrics(
    MediaQueryData? origin, {
    AdaptConfig? config,
    bool rotateDimensionsInLandscape = true,
    double? scaleOverride,
  }) {
    if (origin != null &&
        (origin.size.isEmpty ||
            !origin.devicePixelRatio.isFinite ||
            origin.devicePixelRatio <= 0)) {
      return;
    }
    final configChanged = config != null && (config != _config || !_enabled);
    if (_origin == origin &&
        _rotateDimensions == rotateDimensionsInLandscape &&
        _scaleOverride == scaleOverride &&
        !configChanged) {
      return;
    }
    if (config != null) {
      _config = config;
      _enabled = true;
    }
    _origin = origin;
    _rotateDimensions = rotateDimensionsInLandscape;
    _scaleOverride = scaleOverride;
    _recalculate();
  }

  /// Restores device coordinates until a design size is explicitly selected.
  void reset() {
    if (!_enabled) return;
    _enabled = false;
    _config = _config.copyWith(
      designSize: _origin?.size ?? Size.zero,
      scaleText: true,
      supportSystemTextScale: true,
    );
    _recalculate();
  }

  void _recalculate() {
    final origin = _origin;
    final next = origin == null
        ? null
        : !_enabled || _config.designSize.isEmpty
            ? AdaptMetrics(
                config: _config, origin: origin, adapted: origin, scale: 1)
            : AdaptCalculator.calculate(
                config: _config,
                origin: origin,
                isLandscape: origin.size.width > origin.size.height,
                rotateDimensionsInLandscape: _rotateDimensions,
                scaleOverride: _scaleOverride,
              );
    final old = _metrics;
    if (old != null &&
        next != null &&
        old.config == next.config &&
        old.origin == next.origin &&
        old.adapted == next.adapted &&
        old.scale == next.scale) {
      return;
    }
    _metrics = next;
    notifyListeners();
  }
}
