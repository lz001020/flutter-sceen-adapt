/// base/extension.dart
///
/// Created by longzhi on 2024/7/29
import 'package:flutter/widgets.dart'; // 用于 State, StatefulWidget, VoidCallback

/// 一个用于在挂载的窗口小部件上安全调用 setState 的 mixin。
mixin StateAble<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (!mounted || !context.mounted) {
      // 此小部件已卸载，
      return;
    }
    super.setState(fn); 
  }
}
