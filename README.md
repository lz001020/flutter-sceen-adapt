# design_scale

面向 Android / iOS 单窗口 Flutter 应用的全局设计稿坐标适配库。
通过 binding 同步转换布局 DPR、MediaQuery 与指针坐标，业务组件可直接使用设计稿尺寸。
当前版本只维护核心适配；局部反适配、原生视图补偿、物理像素区域和 ScreenUtil 迁移扩展不属于当前 API。

## 适合什么场景

适合希望统一使用设计稿尺寸、减少逐项尺寸换算的单窗口应用。组件可以保留常量尺寸表达，并使用 Flutter 的 const 子树复用；ScreenUtil 合理封装同样可以复用子树，因此不承诺普遍性能领先。

采用前应在目标设备验证原生视图、插件和系统字号行为。真机基准存在场景与轮次差异，不能把构建次数减少直接等同于帧耗时下降；设备证据和未解决问题见 [性能验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-validation.md)。

## 原理与性能

**核心价值是按设计稿坐标书写布局、减少逐处尺寸换算，并让常量布局更容易保留；不以普遍快于 ScreenUtil 为承诺。**

- **转换位置不同。** ScreenUtil 通常通过 `.w`、`.h`、`.sp` 在业务构建时换算具体尺寸；design_scale 在根视图统一调整有效 DPR 与逻辑约束，并同步 MediaQuery 和指针坐标。倍率随设备指标或配置变化更新，普通父级重建不需要逐个业务尺寸调用换算。它改变坐标映射，不减少屏幕真实像素或自动降低绘制工作量。
- **潜在收益来自减少重复构建。** 业务可直接写 `const SizedBox(width: 100, height: 48)`。当父级再次返回同一个 Widget 实例时，Flutter 可以跳过该处由父级更新引起的重复更新；子树仍可能因自身状态或依赖变化重建。收益取决于实际跳过的工作，不能只用少了多少次尺寸乘法解释。
- **复用不是本库独有。** ScreenUtil 也可通过 `const` 封装组件、内部尺寸换算及稳定的 `child` 复用静态子树，并正确响应窗口变化。两边都合理优化后，页面变复杂不一定扩大库间差距；`const` 也不意味着免除布局、重绘或图片解码。

2026-10-15 小米 14 竖屏 Profile 的复杂图文父级更新专项中，两库优化组均将每轮复杂卡片 build 从 2160 次降为 0；相对各自动态写法，UI p90 下降约 61%–64%，整帧 total p90 下降约 15%–16%。这证明复杂静态子树的复用收益，**不是 design_scale 相对 ScreenUtil 的加速比例**。两库优化组耗时接近，逐轮快慢方向变化，未证明稳定领先。

该专项使用 12 张全部挂载、图片已预缓存的本地图文卡片，不代表首次图片解码或虚拟化长列表。vivo 快速滚动的 raster 长帧波动仍未解决，不据此宣称所有设备无性能回退；开发工时收益也尚未量化。测试方法与完整边界见 [核心测试与验证](doc/testing.md)，逐轮数据见 [发布前性能复核](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-final-20261015.md)。

## 接入

要求 Flutter >=3.22.0、Dart >=3.4.0。核心库、example 和 benchmark 已在 Flutter 3.22.3 / Dart 3.4.4 上通过分析与测试；设备回归记录使用 Flutter 3.35.7 / Dart 3.9.2。

当前为 0.2.0 首次发布准备，尚未上传 pub.dev。发布前可在应用的 `pubspec.yaml` 中使用本地路径：

```yaml
dependencies:
  design_scale:
    path: ../flutter-sceen-adapt # 改成你的本地仓库路径
```

执行 `flutter pub get` 后初始化：

```dart
import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
    scaleText: true,
    supportSystemTextScale: true,
  );
  runApp(const MaterialApp(home: Scaffold(body: SizedBox(width: 100, height: 48))));
}
```

初始化必须在 `runApp` 和其他 binding 初始化之前。根 Scope 自动挂载，不需要业务包装。
`ensureInitialized` 的默认策略为 `min`；推荐显式指定需要的策略。
`AdaptConfig` 构造函数默认策略为 `width`，两者默认值不同。

```dart
// build 中订阅配置和指标变化。
final adapt = AdaptController.of(context);
final AdaptMetrics? metrics = adapt.metrics;

// 回调中读取，不建立重建依赖。
final controller = AdaptController.read(context)!;
controller.setDesignSize(const Size(390, 844));
controller.setEnabled(false); // 恢复设备原始坐标，保留配置
controller.setEnabled(true);
```

设计尺寸必须有限且大于零。无设备快照时 `metrics` 为 null。
业务不能注入设备指标或覆盖 scale，也不应销毁借用的 binding Controller。

## 范围与验证

- 支持 width / height / min 策略、系统字体策略、键盘 inset、设计稿切换及启停。
- 不承诺 Web、桌面、多窗口或任意第三方 PlatformView 兼容。
- 指针回调被插件再次覆盖及高刷重采样仍需按接入场景验证。
- 自动测试通过不代表移动端真机回归或发布完成，具体见发布清单。

## 仓库导航

- [使用说明](doc/usage.md)
- [核心概念](doc/concepts.md)
- [核心测试与验证](doc/testing.md)
- [发布前性能复核](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-final-20261015.md)
- [常见问题](doc/troubleshooting.md)
- [已知限制](doc/known-issues.md)
- [0.2 迁移说明](doc/migration-0.2.md)
- [发布检查](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/release-checklist.md)
- `example/`：窗口、字体、键盘和指针功能实验室。
- `benchmark/`：独立性能实验及 ScreenUtil 对照，不参与发布。
- `archive/extensions/`：移除前扩展及依赖上下文的历史快照，不参与分析、测试或发布。
- [归档索引](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/archive/README.md)：历史资料分类及保留规则。

## 运行示例与参与贡献

克隆仓库后连接 Android 设备或启动 iOS 模拟器：

```sh
cd example
flutter pub get
flutter run -d <device-id>
```

示例启动配置与系统字号选项见 [示例说明](example/README.md)。提交问题请附最小复现、Flutter/设备版本和适配配置；修改流程见 [贡献指南](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/CONTRIBUTING.md)。

使用 [MIT 许可证](LICENSE)，版权归 lz001020。
