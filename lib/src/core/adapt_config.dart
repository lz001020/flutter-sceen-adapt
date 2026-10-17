import 'package:flutter/widgets.dart';

/// Defines which design dimension determines the global scale.
enum ScreenAdaptType {
  /// Scales by the effective device width divided by the design width.
  width,

  /// Scales by the effective device height divided by the design height.
  height,

  /// Scales by the shortest device side divided by the shortest design side.
  min,
}

/// Immutable input used to calculate adapted screen metrics.
@immutable
class AdaptConfig {
  /// Creates a configuration. Validation occurs when a controller applies it.
  ///
  /// Unlike the binding initializer, this constructor defaults to width mode.
  const AdaptConfig({
    required this.designSize,
    this.adaptType = ScreenAdaptType.width,
    this.scaleText = true,
    this.supportSystemTextScale = true,
  });

  /// Design dimensions; both must be finite and greater than zero.
  final Size designSize;

  /// Dimension used to calculate the global scale.
  final ScreenAdaptType adaptType;

  /// Whether fonts scale with the design coordinates.
  ///
  /// When false, compensates for UI scaling to preserve device-logical sizes.
  final bool scaleText;

  /// Whether to preserve the system TextScaler, including nonlinear scaling.
  final bool supportSystemTextScale;

  /// Rejects invalid configuration before any state is changed.
  void validate() {
    if (!designSize.isFinite || designSize.isEmpty) {
      throw ArgumentError.value(
        designSize,
        'designSize',
        'Both dimensions must be finite and positive.',
      );
    }
  }

  /// Returns a configuration with the supplied fields replaced.
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
  int get hashCode =>
      Object.hash(designSize, adaptType, scaleText, supportSystemTextScale);
}
