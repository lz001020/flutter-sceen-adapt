# design_scale

面向 Android / iOS 单窗口 Flutter 应用的全局设计稿坐标适配库。
通过 binding 同步转换布局 DPR、MediaQuery 与指针坐标，业务组件可直接使用设计稿尺寸。
当前版本只维护核心适配；局部反适配、原生视图补偿、物理像素区域和 ScreenUtil 迁移扩展已归档，不在发布包中。

## 接入

要求 Flutter >=3.35.0、Dart >=3.9.0。当前验收 SDK 为 Flutter 3.35.7 / Dart 3.9.2。

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
- [常见问题](doc/troubleshooting.md)
- [已知限制](doc/known-issues.md)
- [0.2 迁移说明](doc/migration-0.2.md)
- [发布检查](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/release-checklist.md)
- `example/`：窗口、字体、键盘和指针功能实验室。
- `benchmark/`：独立性能实验及 ScreenUtil 对照，不参与发布。
- `archive/extensions/`：移除前扩展及依赖上下文的历史快照，不参与分析、测试或发布。
- [归档索引](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/archive/README.md)：历史资料分类及保留规则。
