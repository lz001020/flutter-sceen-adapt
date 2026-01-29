/// widgets/design_size_widget.dart
///
/// Created by longzhi on 2024/7/29
import 'package:flutter/material.dart'; // 用于 Widget, BuildContext, State, StatefulWidget, InheritedWidget
import 'package:flutter/widgets.dart'; // 用于 MediaQuery, Size

import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/base/extension.dart'; // 用于 StateAble

/// 一个向其子级提供设计尺寸上下文的小部件。
///
/// 在应用程序的根部或重要的子树上使用它，为后代启用基于设计的缩放。
class DesignSizeWidget extends StatefulWidget {
  final Widget child;

  const DesignSizeWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => DesignSizeWidgetState();
}

class DesignSizeWidgetState extends State<DesignSizeWidget> with StateAble {
  /// 设置屏幕适配的设计尺寸。
  /// 这将触发屏幕指标的重新计算。
  void setDesignSize(Size size) {
    ScreenSizeUtils.instance.setDesignSize(size);
    _handleMetricsChanged();
  }

  /// 将屏幕适配重置为默认设备指标。
  /// 这将触发屏幕指标的重新计算。
  void reset() {
    ScreenSizeUtils.instance.reset();
    _handleMetricsChanged();
  }

  /// 强制重新构建依赖于屏幕指标的小部件。
  void _handleMetricsChanged() {
    WidgetsBinding.instance.handleMetricsChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否已经存在 DesignSize 祖先
    final outerDesignSizeState = DesignSize.maybeOf(context);

    // 无论如何都应用缩放逻辑。这确保了在 UnscaledZone 之后能正确恢复缩放。
    final mediaQueryData = MediaQuery.of(context).design();

    // 如果我们是顶层的 DesignSizeWidget，则提供 InheritedWidget。
    // 如果我们是嵌套的，则不需要提供另一个。任何后代小部件需要状态时，
    // 它们会找到顶层的那个。
    if (outerDesignSizeState == null) {
      // 我们是顶层提供者。
      return MediaQuery(
        data: mediaQueryData,
        child: DesignSize(
          data: this,
          child: widget.child,
        ),
      );
    } else {
      // 我们是嵌套的。只应用 MediaQuery，不提供新的 InheritedWidget。
      // 这可以防止状态冲突，并确保所有 of(context) 调用都找到顶层状态。
      return MediaQuery(
        data: mediaQueryData,
        child: widget.child,
      );
    }
  }
}

/// 一个 [InheritedWidget]，用于向其后代提供 [DesignSizeWidgetState]。
///
/// 用于从窗口小部件树中的任何位置访问 [setDesignSize] 和 [reset] 等方法。
class DesignSize extends InheritedWidget {
  final DesignSizeWidgetState data;

  const DesignSize({super.key, required this.data, required super.child});

  /// 从最近的 [DesignSize] 祖先返回 [DesignSizeWidgetState]。
  /// 如果找不到 [DesignSize] 祖先，则返回 `null`。
  static DesignSizeWidgetState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesignSize>()?.data;
  }

  /// 从最近的 [DesignSize] 祖先返回 [DesignSizeWidgetState]。
  /// 如果找不到 [DesignSize] 祖先，则会引发断言错误。
  static DesignSizeWidgetState of(BuildContext context) {
    final DesignSizeWidgetState? result = maybeOf(context);
    assert(result != null, 'No DesignSizeWidgetState found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(DesignSize oldWidget) => data != oldWidget.data;
}
