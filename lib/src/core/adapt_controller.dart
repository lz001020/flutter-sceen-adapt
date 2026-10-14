import 'package:flutter/widgets.dart';

import 'adapt_metrics.dart';
import 'adapt_config.dart';

/// Owns adaptation state without reading a FlutterView or calling a binding.
class AdaptController extends ChangeNotifier {
  AdaptController({required AdaptConfig config}) : _config = config {
    config.validate();
  }

  AdaptConfig _config;
  AdaptMetrics? _metrics;
  MediaQueryData? _origin;
  bool _enabled = true;

  static AdaptController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('No AdaptController found in the widget tree.');
    }
    return controller;
  }

  static AdaptController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdaptControllerScope>()
      ?.controller;

  static AdaptController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdaptControllerScope>()?.controller;

  AdaptConfig get config => _config;
  AdaptMetrics? get metrics => _metrics;
  bool get enabled => _enabled;

  void configure(AdaptConfig config) {
    config.validate();
    if (_config == config && _enabled) return;
    _config = config;
    _enabled = true;
    _recalculate();
  }

  void setDesignSize(Size size) =>
      configure(_config.copyWith(designSize: size));

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _recalculate();
  }

  /// Device reads and platform policy belong to the caller.
  ///
  /// Supply [config] when device metrics and configuration must change
  /// together. Subscribers receive only the combined result. Invalid device
  /// input is ignored; use [configure] to update only the configuration.
  void _updateDeviceMetrics(MediaQueryData? origin, {AdaptConfig? config}) {
    if (origin != null &&
        (!origin.size.isFinite ||
            origin.size.isEmpty ||
            !origin.devicePixelRatio.isFinite ||
            origin.devicePixelRatio <= 0)) {
      return;
    }
    config?.validate();
    final configChanged = config != null && (config != _config || !_enabled);
    if (_origin == origin && !configChanged) {
      return;
    }
    if (config != null) {
      _config = config;
      _enabled = true;
    }
    _origin = origin;
    _recalculate();
  }

  void _recalculate() {
    final origin = _origin;
    final next = origin == null
        ? null
        : !_enabled || _config.designSize.isEmpty
        ? AdaptMetrics(
            config: _config,
            origin: origin,
            adapted: origin,
            scale: 1,
          )
        : AdaptCalculator.calculate(
            config: _config,
            origin: origin,
            isLandscape: origin.size.width > origin.size.height,
          );
    _metrics = next;
    notifyListeners();
  }
}

/// Internal inherited notifier used by [AdaptController.of].
class AdaptControllerScope extends InheritedNotifier<AdaptController> {
  const AdaptControllerScope({
    super.key,
    required AdaptController controller,
    required super.child,
  }) : super(notifier: controller);

  AdaptController get controller => notifier!;
}

/// Internal device input boundary. Not exported by design_scale.dart.
void updateAdaptDeviceMetrics(
  AdaptController controller,
  MediaQueryData? origin, {
  AdaptConfig? config,
}) {
  controller._updateDeviceMetrics(origin, config: config);
}
