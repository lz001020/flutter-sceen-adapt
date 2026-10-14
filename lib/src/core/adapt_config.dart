import 'package:flutter/widgets.dart';

/// Defines which design dimension determines the global scale.
enum ScreenAdaptType { width, height, min }

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
