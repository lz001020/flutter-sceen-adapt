// Public migration helper for isolating legacy flutter_screenutil subtrees.
import 'package:flutter/material.dart';

import 'package:screen_adapt/src/core/screen_metrics.dart';
import 'package:screen_adapt/src/widgets/unscaled_zone.dart';

/// 对 legacy 子树做额外包装的回调。
typedef LegacyChildWrapper = Widget Function(BuildContext context, Widget child);

/// 用于过渡 `flutter_screenutil` 子树的兼容容器。
///
/// 典型用法是把尚未迁移完成的 legacy 页面整体包起来，再在其内部继续使用
/// `ScreenUtilInit` 和 `.w / .h / .sp`。这样可以让该子树重新拿到原始
/// `MediaQuery`，并按需退出 `screen_adapt` 的全局缩放语义。
///
/// 常见迁移写法：
///
/// ```dart
/// LegacyScreenUtilScope(
///   child: ScreenUtilInit(
///     designSize: const Size(375, 812),
///     builder: (_, __) => const LegacyOrderPage(),
///   ),
/// )
/// ```
///
/// 默认使用 [UnscaledZoneMode.full]，适合“整页旧模块逐页迁移”的场景。
/// 如果只想让 legacy 子树恢复原始 `MediaQuery` 和绘制语义，但保留外层当前
/// 的布局槽位，可以改用 [UnscaledZoneMode.contextFallback]。
class LegacyScreenUtilScope extends StatelessWidget {
  const LegacyScreenUtilScope({
    super.key,
    required this.child,
    this.mode = UnscaledZoneMode.full,
  });

  final Widget child;
  final UnscaledZoneMode mode;

  @override
  Widget build(BuildContext context) {
    final originMediaQuery =
        ScreenSizeUtils.instance.originData ?? MediaQuery.maybeOf(context);

    Widget result = UnscaledZone(
      mode: mode,
      child: child,
    );

    if (originMediaQuery != null) {
      result = MediaQuery(
        data: originMediaQuery,
        child: result,
      );
    }

    return result;
  }
}

/// 生成一个会自动套上 [LegacyScreenUtilScope] 的 [WidgetBuilder]。
///
/// 适合路由入口做统一过渡包装；如果旧页面还依赖 `flutter_screenutil`，
/// 可以通过 [wrapChild] 在 legacy 作用域内部继续套一层 `ScreenUtilInit`。
///
/// 示例：
///
/// ```dart
/// builder: legacyScopeBuilder(
///   (_) => const OldOrderPage(),
///   wrapChild: (_, child) => ScreenUtilInit(
///     designSize: const Size(375, 812),
///     builder: (_, __) => child,
///   ),
/// )
/// ```
WidgetBuilder legacyScopeBuilder(
  WidgetBuilder builder, {
  UnscaledZoneMode mode = UnscaledZoneMode.full,
  LegacyChildWrapper? wrapChild,
}) {
  return (context) {
    Widget child = Builder(builder: builder);
    if (wrapChild != null) {
      child = wrapChild(context, child);
    }
    return LegacyScreenUtilScope(
      mode: mode,
      child: child,
    );
  };
}

/// 构建一个默认包裹 [LegacyScreenUtilScope] 的 [MaterialPageRoute]。
///
/// 如果旧页面仍依赖 `.w / .h / .sp`，可结合 [wrapChild] 在 route 入口处继续
/// 初始化 `ScreenUtilInit`。
MaterialPageRoute<T> legacyMaterialPageRoute<T>({
  required WidgetBuilder builder,
  RouteSettings? settings,
  bool maintainState = true,
  bool fullscreenDialog = false,
  UnscaledZoneMode mode = UnscaledZoneMode.full,
  LegacyChildWrapper? wrapChild,
}) {
  return MaterialPageRoute<T>(
    builder: legacyScopeBuilder(
      builder,
      mode: mode,
      wrapChild: wrapChild,
    ),
    settings: settings,
    maintainState: maintainState,
    fullscreenDialog: fullscreenDialog,
  );
}
