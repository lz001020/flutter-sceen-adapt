import 'package:flutter/widgets.dart';

import 'adapt_metrics.dart';
import 'adapt_config.dart';

/// Owns adaptation state without reading a FlutterView or calling a binding.
///
/// Use [of] in build methods and [read] in callbacks. The binding owns the
/// controller returned by these lookups; application code must not dispose it.
/// Independently constructed controllers do not acquire device metrics.
class AdaptController extends ChangeNotifier {
  /// Creates a controller and validates [config] before accepting it.
  AdaptController({required AdaptConfig config}) : _config = config {
    config.validate();
  }

  AdaptConfig _config;
  AdaptMetrics? _metrics;
  MediaQueryData? _origin;
  bool _enabled = true;

  /// Returns the controller and subscribes this context to state changes.
  ///
  /// Throws [FlutterError] when the context is outside the adaptation root.
  static AdaptController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller == null) {
      throw FlutterError('No AdaptController found in the widget tree.');
    }
    return controller;
  }

  /// Subscribes to state changes, or returns null outside the adaptation root.
  static AdaptController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AdaptControllerScope>()
      ?.controller;

  /// Reads without subscribing, or returns null outside the adaptation root.
  static AdaptController? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AdaptControllerScope>()?.controller;

  /// Current configuration, retained while adaptation is disabled.
  AdaptConfig get config => _config;

  /// Current device snapshot, or null when no view snapshot is available.
  AdaptMetrics? get metrics => _metrics;

  /// Whether adaptation is enabled; a scale of one does not imply disabled.
  bool get enabled => _enabled;

  /// Applies a valid configuration and enables adaptation.
  ///
  /// Invalid input throws [ArgumentError] before state changes. Applying the
  /// same configuration while enabled does not notify listeners.
  void configure(AdaptConfig config) {
    config.validate();
    if (_config == config && _enabled) return;
    _config = config;
    _enabled = true;
    _recalculate();
  }

  /// Changes design dimensions, retains other settings and enables adaptation.
  void setDesignSize(Size size) =>
      configure(_config.copyWith(designSize: size));

  /// Toggles adaptation while retaining configuration.
  ///
  /// Disabling restores device coordinates. Repeating the current value does
  /// not notify listeners; later device changes preserve the disabled state.
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
