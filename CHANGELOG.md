## 0.2.0

Breaking changes:

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
- Consolidate the benchmark host into demo/ alongside behavior regressions;
  keep independent performance entry points and update scripts and CI paths.
  Historical device measurements retain their original host conditions.
- Require Flutter >=3.22.0 and Dart >=3.4.0; compatibility checks use
  Flutter 3.22.3 and 3.35.7. Device checks use Flutter 3.35.7.
- Restrict binding configuration and pointer diagnostics to debug mode.
- Document initialization, controller ownership, font policy and validation
  boundaries in the bundled doc/ guides. Correct the custom binding example
  to instantiate its class directly; static initializers are not inherited.
- Add equal-workload update benchmarks and portrait checks in the repository.
  These experiments do not establish a universal advantage over ScreenUtil.

## 0.1.0

Historical implementation included global adaptation and local compensation
extensions. The pre-removal source, tests and documentation are retained in
archive/extensions. This entry does not assert that 0.1.0 was published.
