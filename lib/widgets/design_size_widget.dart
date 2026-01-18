import 'package:flutter/material.dart'; // For Widget, BuildContext, State, StatefulWidget, InheritedWidget
import 'package:flutter/widgets.dart'; // For MediaQuery, Size

import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/base/extension.dart'; // For StateAble

/// A widget that provides the design size context to its children.
///
/// Use this at the root of your application or a significant sub-tree
/// to enable design-based scaling for descendants.
class DesignSizeWidget extends StatefulWidget {
  final Widget child;

  const DesignSizeWidget({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => DesignSizeWidgetState();
}

class DesignSizeWidgetState extends State<DesignSizeWidget> with StateAble {
  /// Sets the design size for screen adaptation.
  /// This will trigger a recalculation of screen metrics.
  void setDesignSize(Size size) {
    ScreenSizeUtils.instance.setDesignSize(size);
    _handleMetricsChanged();
  }

  /// Resets the screen adaptation to default device metrics.
  /// This will trigger a recalculation of screen metrics.
  void reset() {
    ScreenSizeUtils.instance.reset();
    _handleMetricsChanged();
  }



  /// Forces a rebuild of widgets that depend on screen metrics.
  void _handleMetricsChanged() {
    WidgetsBinding.instance.handleMetricsChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Apply the adapted MediaQueryData provided by ScreenSizeUtils.
    final mediaQueryData = MediaQuery.of(context).design();
    return MediaQuery(
      data: mediaQueryData,
      child: DesignSize(
        data: this,
        child: widget.child,
      ),
    );
  }
}

/// An [InheritedWidget] to provide [DesignSizeWidgetState] to its descendants.
///
/// Used to access methods like [setDesignSize] and [reset] from anywhere
/// in the widget tree.
class DesignSize extends InheritedWidget {
  final DesignSizeWidgetState data;

  const DesignSize({super.key, required this.data, required super.child});

  /// Returns the [DesignSizeWidgetState] from the nearest [DesignSize] ancestor.
  /// Returns `null` if no [DesignSize] ancestor is found.
  static DesignSizeWidgetState? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DesignSize>()?.data;
  }

  /// Returns the [DesignSizeWidgetState] from the nearest [DesignSize] ancestor.
  /// Throws an assertion error if no [DesignSize] ancestor is found.
  static DesignSizeWidgetState of(BuildContext context) {
    final DesignSizeWidgetState? result = maybeOf(context);
    assert(result != null, 'No DesignSizeWidgetState found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(DesignSize oldWidget) => data != oldWidget.data;
}
