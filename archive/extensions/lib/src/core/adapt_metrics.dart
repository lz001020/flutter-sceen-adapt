import 'package:flutter/widgets.dart';

/// Defines which design dimension determines the global scale.
enum ScreenAdaptType {
  width,
  height,
  min,
}

/// Immutable input used to calculate adapted screen metrics.
@immutable
class AdaptConfig {
  const AdaptConfig({
    required this.designSize,
    this.adaptType = ScreenAdaptType.width,
    this.scaleText = true,
    this.supportSystemTextScale = true,
  });

  final Size designSize;
  final ScreenAdaptType adaptType;
  final bool scaleText;
  final bool supportSystemTextScale;

  AdaptConfig copyWith({
    Size? designSize,
    ScreenAdaptType? adaptType,
    bool? scaleText,
    bool? supportSystemTextScale,
  }) {
    return AdaptConfig(
      designSize: designSize ?? this.designSize,
      adaptType: adaptType ?? this.adaptType,
      scaleText: scaleText ?? this.scaleText,
      supportSystemTextScale:
          supportSystemTextScale ?? this.supportSystemTextScale,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AdaptConfig &&
      other.designSize == designSize &&
      other.adaptType == adaptType &&
      other.scaleText == scaleText &&
      other.supportSystemTextScale == supportSystemTextScale;

  @override
  int get hashCode => Object.hash(
        designSize,
        adaptType,
        scaleText,
        supportSystemTextScale,
      );
}

/// Immutable output of one adaptation calculation.
@immutable
class AdaptMetrics {
  const AdaptMetrics({
    required this.config,
    required this.origin,
    required this.adapted,
    required this.scale,
  });

  final AdaptConfig config;
  final MediaQueryData origin;
  final MediaQueryData adapted;
  final double scale;
}

/// Pure screen metric calculations with no binding or singleton dependency.
abstract final class AdaptCalculator {
  static AdaptMetrics calculate({
    required AdaptConfig config,
    required MediaQueryData origin,
    required bool isLandscape,
    bool rotateDimensionsInLandscape = true,
    double? scaleOverride,
  }) {
    final scale = scaleOverride ??
        _calculateScale(
          config: config,
          originSize: origin.size,
          isLandscape: isLandscape,
          rotateDimensionsInLandscape: rotateDimensionsInLandscape,
        );
    final adapted = adaptMediaQuery(
      origin: origin,
      scale: scale,
      config: config,
    );
    return AdaptMetrics(
      config: config,
      origin: origin,
      adapted: adapted,
      scale: scale,
    );
  }

  static MediaQueryData adaptMediaQuery({
    required MediaQueryData origin,
    required double scale,
    required AdaptConfig config,
  }) {
    assert(scale.isFinite && scale > 0, 'scale must be finite and positive');

    TextScaler textScaler = config.supportSystemTextScale
        ? origin.textScaler
        : TextScaler.noScaling;
    if (!config.scaleText && scale != 1) {
      textScaler = _DividedTextScaler(textScaler, scale);
    }

    return origin.copyWith(
      size: origin.size / scale,
      devicePixelRatio: origin.devicePixelRatio * scale,
      viewInsets: origin.viewInsets / scale,
      viewPadding: origin.viewPadding / scale,
      padding: origin.padding / scale,
      textScaler: textScaler,
    );
  }

  static double _calculateScale({
    required AdaptConfig config,
    required Size originSize,
    required bool isLandscape,
    required bool rotateDimensionsInLandscape,
  }) {
    if (config.designSize.isEmpty) return 1;

    var currentWidth = originSize.width;
    var currentHeight = originSize.height;
    if (isLandscape && rotateDimensionsInLandscape) {
      currentWidth = originSize.height;
      currentHeight = originSize.width;
    }

    return switch (config.adaptType) {
      ScreenAdaptType.width => currentWidth / config.designSize.width,
      ScreenAdaptType.height => currentHeight / config.designSize.height,
      ScreenAdaptType.min =>
        (currentWidth < currentHeight ? currentWidth : currentHeight) /
            (config.designSize.width < config.designSize.height
                ? config.designSize.width
                : config.designSize.height),
    };
  }
}

/// Preserves a nonlinear system scaler while compensating for UI scaling.
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
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
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
