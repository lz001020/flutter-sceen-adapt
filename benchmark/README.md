# 独立性能实验

不发布的 Flutter 应用；Android/iOS 标识为 dev.screenadapt.benchmark，构建输出位于 benchmark/build。
ScreenUtil 对照依赖仅存在于此工程。列表规模、滚动次数、持续时间及采样逻辑沿用原实验。

```sh
cd benchmark
flutter pub get
flutter analyze
flutter test
flutter build apk --profile
```

| 实验 | 入口 |
| --- | --- |
| 指标计算 | test/metrics_benchmark_test.dart |
| 指针/设计稿切换帧采集 | lib/main.dart |
| 复杂列表 | lib/performance/screen_adapt_list_main.dart、screenutil_list_main.dart |
| const 高频重建 | lib/performance/screen_adapt_rebuild_main.dart、screenutil_rebuild_main.dart |

仓库根目录的 tool/*performance.sh 已改为构建、安装本工程，不再覆盖 example 应用。
必须同设备、Profile 模式、相同操作比较；历史报告不代表迁移后的性能结论。
设备未连接时脚本会失败，不伪造测量通过。性能条件详见 ../docs/performance-validation.md。

## 混合信息流对比

在仓库根目录运行 `zsh tool/compare_mixed_feed_performance.sh <device-id>`，两入口各运行三轮 Profile 对照。包含四类可变高度卡片、横向轮播、富文本、标签换行、本地图片、图表、阴影、裁剪和展开动画。

手动体验（在 benchmark 目录执行；另一个方案将 target 换为 screenutil_list_main.dart）：

```sh
flutter run --profile -d <device-id> \
  --target lib/performance/screen_adapt_list_main.dart \
  --dart-define=PERF_MIXED_FEED=true
```

测量与限制见 [当前性能报告](../docs/performance-validation.md)。原固定行列表保留，便于分别比较规则列表与混合内容。

## iOS 模拟器构建

仓库根目录执行 `zsh tool/build_ios_simulator.sh benchmark`，按本机 arm64 / x86_64 架构构建并验证 Runner 二进制。产物位于 `build/benchmark-ios-simulator/Build/Products/Debug-iphonesimulator/Runner.app`。
当前 Xcode 的 lipo 多架构校验失败会阻止 Flutter 3.35.7 通用模拟器构建；此脚本明确选择单架构，不修改 SDK、不跳过架构校验，也不表示跨架构构建已修复。

库包名已改为 `design_scale`；性能入口文件名、engine 标签 `screen_adapt` 及宿主标识 `dev.screenadapt.benchmark` 保留，便于对照已有报告。它们不是 pub.dev 包名。
