## 0.1.0

Initial public release.

- Binding-level logical coordinate remapping via `DesignSizeWidgetsFlutterBinding`
- Pointer event coordinate correction for accurate hit-testing after global scaling
- `UnscaledZone` with `contextFallback` and `full` modes for local de-adaptation
- `AdaptedPlatformView` for native view size and click compensation
- `PhysicalPixelZone` for sub-logical-pixel drawing
- `DesignSizeWidget` for runtime design-size switching
- `AdaptScope` for explicit nested unscale-state propagation
- `LegacyScreenUtilScope` for isolating legacy `flutter_screenutil` pages during migration
- `legacyScopeBuilder` and `legacyMaterialPageRoute` to reduce legacy route boilerplate
