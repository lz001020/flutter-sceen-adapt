import 'package:flutter/widgets.dart';

/// 一个用于在挂载的窗口小部件上安全调用 setState 的 mixin。
mixin StateAble<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (!mounted || !context.mounted) {
      return;
    }
    super.setState(fn);
  }
}
