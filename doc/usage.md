# 核心适配使用指南

唯一公共入口为 `package:design_scale/design_scale.dart`，完整初始化示例见 [README](../README.md)。

## 坐标与策略

`width` 按有效设备宽度与设计宽度计算比例；`height` 按有效高度与设计高度计算；
`min` 按两者短边计算。设备横屏时先交换设备宽高参与计算。
设计稿自身为横屏时也使用此规则，接入前应验证期望布局。

`AdaptConfig` 默认 `width`，内置 binding 初始化及 mixin 配置默认 `min`。
推荐显式指定策略；`min` 表示短边之比，不是宽高两个缩放比中的较小值。

适配后 DPR = 原始 DPR × scale，逻辑尺寸 = 原始逻辑尺寸 ÷ scale。
键盘 viewInsets、安全区 padding/viewPadding 同比例转换，物理触点使用同一快照的 DPR。

## 字体

- `scaleText: true`：字体随全局设计坐标缩放。
- `scaleText: false`：补偿 UI 比例，保持字体的设备逻辑尺寸。
- `supportSystemTextScale: true`：保留系统 TextScaler（包括非线性缩放）。
- `supportSystemTextScale: false`：使用无系统缩放的字号。

系统字体变化会刷新 binding 快照和根 MediaQuery。

## 运行时 API

| API | 行为 |
| --- | --- |
| AdaptController.of(context) | 订阅 Controller，缺少根 Scope 时抛明确错误 |
| maybeOf(context) | 订阅，可返回 null |
| read(context) | 一次性读取，不订阅 |
| config / metrics / enabled | 只读配置、可空快照及开关 |
| configure(config) | 原子替换配置并启用适配；已启用时重复应用相同配置不通知 |
| setDesignSize(size) | 保留策略和字体设置，修改设计尺寸并启用 |
| setEnabled(value) | 保留配置，关闭时恢复原始坐标；重复值不通知 |
| addListener / removeListener | 订阅状态变化；使用方负责退订 |

从上下文获得的 Controller 由 binding 持有，业务不要 dispose。
独立构造的 Controller 由创建者 dispose，且不会自动获取设备指标。设计尺寸必须为有限正数，否则抛出 `ArgumentError`，已有状态保持不变。
无 view 时快照清空；瞬时无效尺寸/DPR 保留上次有效快照。

## 组合 binding

```dart
class AppBinding extends WidgetsFlutterBinding with DesignSizeBindingMixin {}

void main() {
  DesignSizeBindingMixin.configure(designSize: const Size(375, 667));
  AppBinding();
  runApp(const MyApp());
}
```

只创建一次，适配 mixin 放在组合列表最后；它接管 view 配置和根包装。
上例直接调用构造函数创建自定义 binding；Dart 静态初始化方法不会被子类继承。
组合其他 mixin 时，检查它们对根包装和 view 配置的覆盖是否冲突。
不要先创建普通 WidgetsFlutterBinding 再初始化适配 binding。
重复调用内置 ensureInitialized 会复用 binding 并应用传入配置。
