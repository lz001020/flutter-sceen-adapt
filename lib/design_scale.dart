/// Global design-coordinate adaptation for Android/iOS single-view apps.
library design_scale;

export 'src/core/adapt_config.dart' show AdaptConfig, ScreenAdaptType;
export 'src/core/adapt_metrics.dart' show AdaptMetrics;
export 'src/core/adapt_controller.dart' show AdaptController;
export 'src/binding/adapt_binding.dart'
    show DesignSizeWidgetsFlutterBinding, DesignSizeBindingMixin;
