## 0.2.0

Breaking changes (release preparation; not yet published):

- Rename the package to design_scale and the public entry to design_scale.dart.

- Keep only global adaptation in the public API. Archive UnscaledZone,
  AdaptedPlatformView, PhysicalPixelZone, LegacyScreenUtilScope and route helpers.
- Remove ScreenSizeUtils, MediaQueryData.design(), DesignSizeWidget and old
  import shims. Import package:design_scale/design_scale.dart and use
  AdaptController.of/maybeOf/read for configuration and enable state.
- Binding owns its Controller and device reads; the root borrows the same
  instance. Device injection, Calculator and Scope are no longer exported.
- Require positive finite design sizes; invalid configuration throws before
  state changes. Preserve valid snapshots through transient invalid metrics.
- Notify enable changes even at scale 1; refresh snapshots on system font changes.
- Move performance experiments and ScreenUtil dependency to benchmark/ with
  separate Android/iOS application identifiers and build output.
- Require Flutter >=3.35.0 and Dart >=3.9.0; validated using Flutter 3.35.7.

## 0.1.0

Historical implementation included global adaptation and local compensation
extensions. The pre-removal source, tests and documentation are retained in
archive/extensions. This entry does not assert that 0.1.0 was published.
