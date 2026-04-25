import 'package:flutter/widgets.dart';

/// 描述当前子树的局部适配状态。
///
/// 这层状态只记录 `UnscaledZone` 已经在当前子树生效到什么阶段，
/// 以及恢复原始上下文所需的基准 `MediaQueryData`。
@immutable
class AdaptScopeState {
  const AdaptScopeState({
    required this.scale,
    required this.originMediaQuery,
    required this.adaptedMediaQuery,
    this.paintUnscaled = false,
    this.layoutUnscaled = false,
  });

  final double scale;
  final MediaQueryData originMediaQuery;
  final MediaQueryData adaptedMediaQuery;
  final bool paintUnscaled;
  final bool layoutUnscaled;

  AdaptScopeState copyWith({
    double? scale,
    MediaQueryData? originMediaQuery,
    MediaQueryData? adaptedMediaQuery,
    bool? paintUnscaled,
    bool? layoutUnscaled,
  }) {
    return AdaptScopeState(
      scale: scale ?? this.scale,
      originMediaQuery: originMediaQuery ?? this.originMediaQuery,
      adaptedMediaQuery: adaptedMediaQuery ?? this.adaptedMediaQuery,
      paintUnscaled: paintUnscaled ?? this.paintUnscaled,
      layoutUnscaled: layoutUnscaled ?? this.layoutUnscaled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdaptScopeState &&
        other.scale == scale &&
        other.originMediaQuery == originMediaQuery &&
        other.adaptedMediaQuery == adaptedMediaQuery &&
        other.paintUnscaled == paintUnscaled &&
        other.layoutUnscaled == layoutUnscaled;
  }

  @override
  int get hashCode => Object.hash(
        scale,
        originMediaQuery,
        adaptedMediaQuery,
        paintUnscaled,
        layoutUnscaled,
      );
}

/// 将当前子树的局部适配状态向下传递。
class AdaptScope extends InheritedWidget {
  const AdaptScope({
    super.key,
    required this.state,
    required super.child,
  });

  final AdaptScopeState state;

  static AdaptScopeState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdaptScope>()?.state;
  }

  static AdaptScopeState of(BuildContext context) {
    final result = maybeOf(context);
    assert(result != null, 'No AdaptScope found in context.');
    return result!;
  }

  @override
  bool updateShouldNotify(covariant AdaptScope oldWidget) {
    return state != oldWidget.state;
  }
}
