# screen_adapt

一个基于 Flutter 底层渲染链路的屏幕适配方案。

它的目标不是在业务代码里到处写 `.w / .h / .sp`，而是在全局逻辑坐标系层面一次性完成设计稿映射。接入后，业务层大多数场景可以直接按设计稿尺寸写布局；当某个局部区域不适合参与全局适配时，再通过 `UnscaledZone`、`AdaptedPlatformView`、`PhysicalPixelZone` 做精确补偿。

## 适合什么问题

- 希望直接按设计稿尺寸写 Flutter UI，而不是在业务层手动换算
- 希望运行时切换设计稿尺寸，并立即看到全局结果
- 希望全局适配后，点击、拖拽等手势坐标仍然准确
- 希望在少数局部区域退出全局适配
- 希望处理 `PlatformView` 和物理像素绘制这类对尺寸语义更敏感的场景

## 核心思路

`screen_adapt` 的核心不是扩展方法，而是自定义 `WidgetsFlutterBinding`：

- 通过重写 `createViewConfigurationFor()` 改写逻辑尺寸与 `devicePixelRatio`
- 让 Flutter 在更上游的逻辑坐标系里直接工作在“设计稿尺寸”语义下
- 同时修正指针事件坐标，避免全局缩放后点击偏移

这样做的结果是：

- 业务组件可以直接写设计稿上的宽高、间距、字号
- 不需要在每个组件上显式做尺寸换算
- `const` 优化不会因为 `.w` 这类扩展写法被迫失效

## 能力概览

- 全局适配：统一映射逻辑尺寸与 `devicePixelRatio`
- 运行时切换设计稿：支持动态切换和重置
- 手势坐标修正：点击、拖拽、命中测试和全局适配一致
- 局部反适配：`UnscaledZone` 支持 `contextFallback` 和 `full`
- 原生视图补偿：`AdaptedPlatformView`
- 物理像素绘制：`PhysicalPixelZone`

## 快速开始

### 1. 初始化 binding

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

### 2. 按设计稿尺寸写布局

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

接入后，这里的 `180 / 100 / 16` 都直接按设计稿语义参与布局。

## 适配模式

`DesignSizeWidgetsFlutterBinding.ensureInitialized(...)` 支持 `ScreenAdaptType`：

- `ScreenAdaptType.width`
  按宽度适配。默认模式，最常用。
- `ScreenAdaptType.height`
  按高度适配。适合高度基准更强的页面。
- `ScreenAdaptType.min`
  按宽高最小边适配。适合希望手机/平板视觉比例更稳定的场景。

示例：

```dart
DesignSizeWidgetsFlutterBinding.ensureInitialized(
  const Size(375, 667),
  type: ScreenAdaptType.width,
);
```

## 运行时切换设计稿

当应用树中有 `DesignSizeWidget` 时，可以在运行时切换设计稿：

```dart
DesignSize.of(context).setDesignSize(const Size(390, 844));
DesignSize.of(context).reset();
```

这类能力已经在示例工程首页和各专题 demo 里集成。

## `UnscaledZone`

`UnscaledZone` 用来处理“全局适配已经打开，但某个局部区域不应该跟着适配”的场景。

当前实现不是一个“大一统 RenderObject”，而是按三层能力拼装：

- 恢复原始 `MediaQuery`
- 恢复绘制与命中测试坐标
- 可选恢复布局占位

### `UnscaledZoneMode.contextFallback`

默认模式。

它会恢复：

- `context`
- `paint`

但不会恢复：

- `layout`

效果是：

- 子树看起来回到原始尺寸
- 父布局里的占位仍保持当前适配态

适合：

- 局部图表、画布、自绘区域
- 只想让这块内容恢复原始尺寸，但不想打乱父级排版节奏

### `UnscaledZoneMode.full`

它会同时恢复：

- `context`
- `layout`
- `paint`

效果是：

- 子树看起来回到原始尺寸
- 子树对父布局汇报的占位也一起回退

适合：

- 需要连同占位一起退出适配的子树
- legacy 模块、第三方组件、局部独立子系统
- 相邻 widget 的排布必须跟着真实回退尺寸变化的场景

### 示例

```dart
Column(
  children: [
    Container(
      width: 180,
      height: 100,
      color: Colors.blue,
    ),
    const SizedBox(height: 12),
    UnscaledZone(
      child: Container(
        width: 180,
        height: 100,
        color: Colors.green,
      ),
    ),
    const SizedBox(height: 12),
    UnscaledZone(
      mode: UnscaledZoneMode.full,
      child: Container(
        width: 180,
        height: 100,
        color: Colors.orange,
      ),
    ),
  ],
)
```

### 嵌套与重进适配态

`UnscaledZone` 的嵌套状态由 `AdaptScope` 显式传递：

- 如果祖先已经做过 `paint` 回退，内层不会重复反缩放
- 如果祖先已经做过 `layout` 回退，内层 `full` 只会补缺失层
- 如果中间再次嵌入 `DesignSizeWidget`，它只会把 `MediaQuery` 切回适配态，不会清掉祖先已经生效的 render 反缩放

这部分可以直接在示例工程的 `UnscaledZone` 专题页里观察。

## `AdaptedPlatformView`

`PlatformView` 在全局适配下，常见问题是：

- 尺寸和 Flutter 容器边界不一致
- 视觉大小失真
- 点击区域和视觉区域错位

`AdaptedPlatformView` 用于补偿这类差异，让原生视图在适配体系下重新对齐。

## `PhysicalPixelZone`

`PhysicalPixelZone` 用来处理“逻辑像素不够精确”的场景，例如：

- 1px 线条
- 精细网格
- 像素级绘制

它解决的是内部绘制语义问题，不会改变外层父布局流。

## 对外 API

```dart
import 'package:screen_adapt/screen_adapt.dart';
```

主要 API：

- `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`
- `ScreenAdaptType`
- `ScreenSizeUtils.instance`
- `DesignSize.of(context).setDesignSize(...)`
- `DesignSize.of(context).reset()`
- `DesignSizeWidget`
- `UnscaledZone`
- `UnscaledZoneMode`
- `AdaptedPlatformView`
- `PhysicalPixelZone`

## 示例工程

仓库内的 `example` 已覆盖当前主要能力。

入口：

- [example/lib/main.dart](example/lib/main.dart)
- [example/lib/home_page.dart](example/lib/home_page.dart)

专题页面：

- [example/lib/adaptation_gallery_page.dart](example/lib/adaptation_gallery_page.dart)
  全局适配、设计稿切换、字体和布局缩放
- [example/lib/unscaled_zone_demo_page.dart](example/lib/unscaled_zone_demo_page.dart)
  `UnscaledZone` 的 `context / paint / layout` 语义、嵌套、row sibling 影响、重进适配态
- [example/lib/demo3/pointer_test_page.dart](example/lib/demo3/pointer_test_page.dart)
  指针事件、拖拽轨迹、命中测试
- [example/lib/platform_view_demo.dart](example/lib/platform_view_demo.dart)
  `PlatformView` 视觉补偿
- [example/lib/physical_pixel_demo_page.dart](example/lib/physical_pixel_demo_page.dart)
  物理像素语义和 1px 绘制
- [example/lib/keyboard_media_query_page.dart](example/lib/keyboard_media_query_page.dart)
  键盘、`viewInsets`、`MediaQuery` 变化

示例说明见 [example/README.md](example/README.md)。

## 设计限制

- `contextFallback` 会保留原父布局槽位，所以相邻 widget 仍可能被“逻辑坑位”推开
- `full` 会一起回退布局占位，但它的行为仍受父约束体系影响
- `PhysicalPixelZone` 主要改变内部绘制语义，不会自动改变外层占位
- 当前实现仍主要围绕单 view 场景设计，多窗口 / 多 view 支持有限

## 进一步阅读

- [lib/doc/Usage.md](lib/doc/Usage.md)
- [lib/doc/Concept.md](lib/doc/Concept.md)
- [lib/doc/KnownIssues.md](lib/doc/KnownIssues.md)
- [lib/doc/Troubleshooting.md](lib/doc/Troubleshooting.md)
