import 'package:flutter/widgets.dart'; // For State, StatefulWidget, VoidCallback

/// A mixin to safely call setState on a mounted widget.
mixin StateAble<T extends StatefulWidget> on State<T> {
  @override
  void setState(VoidCallback fn) {
    if (!mounted || !context.mounted) {
      // This widget has been unmounted,
      return;
    }
    super.setState(fn);
  }
}
