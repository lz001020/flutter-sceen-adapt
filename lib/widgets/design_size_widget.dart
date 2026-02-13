import 'package:flutter/widgets.dart';
import 'package:screen_adapt/base/extension.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';

class DesignSizeWidget extends StatefulWidget {
  final Widget child;
  const DesignSizeWidget({super.key, required this.child});

  @override
  State<DesignSizeWidget> createState() => DesignSizeWidgetState();
}

class DesignSizeWidgetState extends State<DesignSizeWidget> with StateAble {
  void setDesignSize(Size size) {
    ScreenSizeUtils.instance.designSize = size;
    ScreenSizeUtils.instance.setup();
    WidgetsBinding.instance.handleMetricsChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DesignSize(data: this, child: widget.child);
  }
}

class DesignSize extends InheritedWidget {
  final DesignSizeWidgetState data;
  const DesignSize({super.key, required this.data, required super.child});

  static DesignSizeWidgetState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignSize>()?.data;

  @override
  bool updateShouldNotify(DesignSize oldWidget) => false;
}