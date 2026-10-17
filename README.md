# design_scale

面向 Android / iOS 单窗口 Flutter 应用的设计稿坐标适配库。
在应用入口统一配置设计尺寸，业务组件直接使用设计稿中的间距、字号和宽高。

```dart
const Padding(
  padding: EdgeInsets.all(24),
  child: SizedBox(
    width: 160,
    height: 48,
    child: Center(child: Text('立即下单', style: TextStyle(fontSize: 16))),
  ),
)
```

## 特点

- **直接写设计尺寸**：在根视图统一映射布局、MediaQuery 与指针坐标，减少逐项尺寸换算。
- **保留 const 表达**：静态布局可使用常量尺寸和 const 组件，配合 Flutter 的子树复用机制。
- **配置集中管理**：支持按宽度、按高度、按短边（min）三种策略，以及字体缩放、运行时设计尺寸切换和适配启停。

适合以统一设计稿为基础的移动端应用。全局缩放负责坐标映射；页面内容重排、平板多栏等响应式布局仍由业务实现。

## 接入

要求 Flutter >=3.22.0、Dart >=3.4.0。

当前版本为 0.2.0，尚未发布到 pub.dev。克隆仓库后，在应用的 `pubspec.yaml` 中添加本地依赖：

```yaml
dependencies:
  design_scale:
    path: ../flutter-sceen-adapt # 改成你的本地仓库路径
```

执行 `flutter pub get`，在应用入口初始化：

```dart
import 'package:flutter/material.dart';
import 'package:design_scale/design_scale.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 812),
    type: ScreenAdaptType.width,
    scaleText: true,
    supportSystemTextScale: true,
  );
  runApp(const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(width: 160, height: 48, child: Text('Hello design_scale')),
        ),
      ),
    ),
  ));
}
```

初始化应早于 `runApp` 和其他 binding 初始化，无需额外包裹根组件。
示例显式选择按宽度缩放；`ensureInitialized` 默认使用 `min` 策略。字体默认随适配缩放并跟随系统字号。

## 高级用法

### 选择缩放策略与字体行为

初始化时通过 `type` 选择策略，运行时通过 `AdaptConfig.adaptType` 配置：

| 策略 | 比例计算 |
| --- | --- |
| `width` | 有效设备宽度 ÷ 设计宽度 |
| `height` | 有效设备高度 ÷ 设计高度 |
| `min` | 设备短边 ÷ 设计短边 |

设备横屏时，width / height 使用交换后的设备宽高计算。`min` 表示短边之比，适合保持短边对应的设计比例。

字体可独立于界面缩放配置。例如，保留设备逻辑字号，并继续跟随用户的系统字号设置：

```dart
final controller = AdaptController.read(context)!;
controller.configure(controller.config.copyWith(
  scaleText: false,
  supportSystemTextScale: true,
));
```

`scaleText` 控制字体是否随设计坐标缩放；`supportSystemTextScale` 控制是否跟随系统字号，两者默认均为 `true`。

### 运行时调整

在事件回调中读取 Controller，切换设计稿或启停适配：

```dart
final controller = AdaptController.read(context)!;
controller.setDesignSize(const Size(390, 844));
controller.setEnabled(false); // 切回设备原始坐标，保留配置
controller.setEnabled(true);
```

需要同时更新设计尺寸和策略时，一次应用配置：

```dart
controller.configure(controller.config.copyWith(
  designSize: const Size(390, 844),
  adaptType: ScreenAdaptType.width,
));
```

`configure` 和 `setDesignSize` 会启用适配；`setEnabled` 保留当前配置。从上下文获得的 Controller 由 binding 管理，无需手动释放。

### 读取适配状态

在组件的 `build` 中使用 `of` 订阅配置与指标变化；事件回调中使用 `read` 一次性读取。

```dart
@override
Widget build(BuildContext context) {
  final adapt = AdaptController.of(context);
  final metrics = adapt.metrics;
  return Text(metrics == null
      ? '等待窗口就绪'
      : '当前逻辑尺寸：${metrics.adapted.size}');
}
```

日常布局仍使用 `MediaQuery.sizeOf(context)` 等 Flutter API，它们已处于适配后的逻辑坐标中；`metrics.origin` 可读取适配前的设备指标。

### 自定义 binding

已有自定义 binding 时，通过 mixin 组合适配能力，替代内置的 `ensureInitialized` 入口：

```dart
class AppBinding extends WidgetsFlutterBinding with DesignSizeBindingMixin {}

void main() {
  DesignSizeBindingMixin.configure(
    designSize: const Size(375, 812),
    adaptType: ScreenAdaptType.width,
  );
  AppBinding();
  runApp(const MaterialApp(home: Scaffold(body: Text('Hello design_scale'))));
}
```

先配置，再创建唯一 binding；与其他 mixin 组合时，将适配 mixin 放在最后。更多生命周期说明见 [使用指南](doc/usage.md)。

## 运行示例

连接 Android 设备或启动 iOS 模拟器：

```sh
cd example
flutter pub get
flutter run -d <device-id>
```

[咖啡下单示例](example/README.md)演示设计稿布局、商品数量调整、备注输入和订单确认，代码位于 [example/lib/main.dart](example/lib/main.dart)。

## 使用范围

支持 Android / iOS 单窗口应用。接入原生视图（PlatformView）或接管指针回调的插件时，需要验证坐标与交互兼容性。具体问题见 [已知限制](doc/known-issues.md)。

## 文档与贡献

- [使用指南](doc/usage.md) · [核心概念](doc/concepts.md) · [常见问题](doc/troubleshooting.md)
- [迁移说明](doc/migration-0.2.md) · [测试与验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/testing.md)
- [Roadmap](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/roadmap.md)
- [性能测试方法与结果](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/performance-validation.md)
- [贡献指南](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/CONTRIBUTING.md) · [问题反馈](https://github.com/lz001020/flutter-sceen-adapt/issues)

维护者的功能回归与性能对照统一位于 [demo/](demo/README.md)，性能场景使用独立启动入口。

使用 [MIT 许可证](LICENSE)，版权归 lz001020。
