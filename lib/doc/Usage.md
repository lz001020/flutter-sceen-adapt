# `screen_adapt` 使用指南

本文档只回答两个问题：

- 怎么接入
- 遇到局部特殊场景时该用哪个能力

如果你想看底层原理，读 [Concept.md](../../lib/doc/Concept.md)；如果你想看当前限制，读 [KnownIssues.md](../../lib/doc/KnownIssues.md)。

## 1. 接入

### 在 `main()` 里初始化 binding

```dart
import 'package:flutter/material.dart';
import 'package:screen_adapt/screen_adapt.dart';

void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
  );
  runApp(const MyApp());
}
```

这是唯一必须的接入步骤。

初始化之后，Flutter 的全局逻辑坐标系会被映射到你的设计稿尺寸语义上。

## 2. 适配模式

`DesignSizeWidgetsFlutterBinding.ensureInitialized(...)` 支持 `ScreenAdaptType`：

- `ScreenAdaptType.width`
  默认模式，按宽度适配
- `ScreenAdaptType.height`
  按高度适配
- `ScreenAdaptType.min`
  按宽高最小边适配

示例：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 667),
  type: ScreenAdaptType.width,
);
```

## 3. 正常写布局

大多数场景下，你可以直接按设计稿尺寸写 Flutter UI：

```dart
class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 180,
          height: 100,
          color: Colors.orange,
          alignment: Alignment.center,
          child: const Text(
            '180 x 100',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
```

这里的 `180 / 100 / 16` 都直接使用设计稿语义，不需要再写 `.w / .h / .sp`。

## 4. 运行时切换设计稿

如果树中存在 `DesignSizeWidget`，可以在运行时切换设计稿：

```dart
DesignSize.of(context).setDesignSize(const Size(390, 844));
DesignSize.of(context).reset();
```

适合：

- 调试不同设计稿基线
- 平板 / 桌面场景下按窗口或断点切换设计稿

## 5. 局部退出全局适配

### `UnscaledZone`

`UnscaledZone` 用于“全局适配已经打开，但局部区域不该跟着适配”的场景。

当前实现按三层能力拼装：

- 恢复 `MediaQuery`
- 恢复绘制与命中测试
- 可选恢复布局占位

#### `contextFallback`

默认模式。

恢复：

- `context`
- `paint`

不恢复：

- `layout`

效果：

- 子树看起来回到原始尺寸
- 但父布局里的占位不变

适合：

- 局部图表、自绘区域、坐标系、标尺
- 只想让子树恢复原尺寸，但不想打乱外层布局节奏

示例：

```dart
UnscaledZone(
  child: Container(
    width: 180,
    height: 100,
    color: Colors.green,
  ),
)
```

#### `full`

恢复：

- `context`
- `layout`
- `paint`

效果：

- 子树看起来回到原始尺寸
- 子树对父布局汇报的占位也一起回退

适合：

- legacy 模块
- 相邻 widget 的排布必须跟着真实尺寸变化
- 局部独立子系统、第三方复杂组件

示例：

```dart
UnscaledZone(
  mode: UnscaledZoneMode.full,
  child: Container(
    width: 180,
    height: 100,
    color: Colors.orange,
  ),
)
```

### 该选哪一个

- 普通页面：不用 `UnscaledZone`
- 只想让子树自己恢复原尺寸，父布局别动：`contextFallback`
- 连占位和相邻排版都要一起回退：`full`

## 6. 原生视图

### `AdaptedPlatformView`

`PlatformView` 在全局适配下常见问题：

- 视觉尺寸失真
- 容器边界和原生内容不对齐
- 点击区域错位

这类场景优先使用 `AdaptedPlatformView`。

## 7. 物理像素绘制

### `PhysicalPixelZone`

用于处理：

- 1px 线条
- 细网格
- 像素级绘制

注意：

- 它主要改变的是内部绘制语义
- 不会自动改变外层父布局占位

## 8. 示例工程怎么读

示例入口：

- [example/lib/main.dart](../../example/lib/main.dart)
- [example/lib/home_page.dart](../../example/lib/home_page.dart)

专题页：

- [example/lib/adaptation_gallery_page.dart](../../example/lib/adaptation_gallery_page.dart)
  看全局适配和设计稿切换
- [example/lib/unscaled_zone_demo_page.dart](../../example/lib/unscaled_zone_demo_page.dart)
  看 `UnscaledZone` 两种模式、嵌套、row sibling 影响、重进适配态
- [example/lib/demo3/pointer_test_page.dart](../../example/lib/demo3/pointer_test_page.dart)
  看点击和拖拽是否准确
- [example/lib/platform_view_demo.dart](../../example/lib/platform_view_demo.dart)
  看原生视图补偿
- [example/lib/physical_pixel_demo_page.dart](../../example/lib/physical_pixel_demo_page.dart)
  看物理像素语义
- [example/lib/keyboard_media_query_page.dart](../../example/lib/keyboard_media_query_page.dart)
  看键盘与 `viewInsets`

## 9. 常见判断

- 想按设计稿直接写 UI：初始化 binding
- 想动态切设计稿：`DesignSize.of(context)`
- 想局部恢复原始尺寸但不影响父布局：`UnscaledZone.contextFallback`
- 想连占位一起恢复：`UnscaledZone.full`
- 想处理原生视图尺寸失真：`AdaptedPlatformView`
- 想做 1px / 像素级绘制：`PhysicalPixelZone`
