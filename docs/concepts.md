# `screen_adapt` 设计与原理

如果你还不清楚整套文档怎么分工，先看 [文档导航](../../docs/README.md)。

本文档解释的是：

- 这个方案为什么不依赖 `.w / .h`
- 它在 Flutter 渲染链路里改了什么
- `UnscaledZone` 为什么要拆成 `context / paint / layout`

## 1. 方案定位

`screen_adapt` 的核心不是“业务层尺寸换算”，而是“全局逻辑坐标系重映射”。

常见适配方案会在业务代码里大量写：

- `.w`
- `.h`
- `.sp`
- `MediaQuery.of(context).size.width * ratio`

这种方案的问题是：

- 侵入业务层
- 代码噪音大
- `const` 优化经常失效
- 局部特殊区域要反向推导回原始尺寸

`screen_adapt` 选择把问题上移到 binding 层处理：

- 先改逻辑尺寸和 `devicePixelRatio`
- 再让后续布局、绘制、命中测试都工作在新的逻辑坐标系里

结果是：

- 大多数业务组件直接写设计稿尺寸即可
- 只有少数特殊区域才需要额外补偿

## 2. 全局适配链路

### 2.1 `DesignSizeWidgetsFlutterBinding`

入口在：

- [lib/src/core/bindings.dart](../../lib/src/core/bindings.dart)

它的职责是尽早接管 Flutter 的 view 配置流程。

核心点：

- 在 `runApp()` 前初始化
- 改写 `createViewConfigurationFor()`
- 同步修正指针事件转换

### 2.2 `createViewConfigurationFor()`

这是全局适配真正生效的关键位置。

它决定：

- Flutter 看到的逻辑尺寸
- Flutter 使用的 `devicePixelRatio`

当前方案的做法是：

1. 读取设备物理尺寸
2. 根据设计稿尺寸和 `ScreenAdaptType` 计算 `scale`
3. 生成新的 `devicePixelRatio`
4. 反推出新的逻辑尺寸
5. 把新的 `ViewConfiguration` 交给 Flutter

这样一来，Flutter 后续的 layout / paint 都直接基于“适配后的逻辑世界”运行。

## 3. `ScreenSizeUtils`

入口在：

- [lib/src/core/screen_metrics.dart](../../lib/src/core/screen_metrics.dart)

它是整个方案的中心状态管理器，负责：

- 保存设计稿尺寸
- 保存适配模式
- 保存原始 `MediaQueryData`
- 保存适配后的 `MediaQueryData`
- 计算全局 `scale`

这里的两个数据要区分：

- `originData`
  设备原始指标
- `data`
  适配后的指标

后面 `UnscaledZone`、`DesignSizeWidget`、指针补偿都会依赖这两个状态。

## 4. 指针事件为什么要补偿

全局适配之后，Flutter 的渲染坐标系已经变了，但引擎给到的原始触摸数据仍然来自物理像素世界。

如果不补偿，会出现：

- 点击偏移
- 拖拽轨迹和视觉位置不一致
- 命中测试错误

所以 binding 层还要同步接管指针数据转换，让事件坐标也使用适配后的 `devicePixelRatio`。

这部分能力可以在示例页里直接验证：

- [example/lib/pages/input/pointer_events_page.dart](../../example/lib/pages/input/pointer_events_page.dart)

## 5. 为什么 `UnscaledZone` 不能只靠一个 `Transform.scale`

这是当前实现里最容易被误解的点。

如果只做一个 `Transform.scale`，你只能改：

- 视觉大小

但你改不了：

- 子树内部拿到的 `MediaQuery`
- 命中测试坐标
- 父布局看到的占位
- intrinsic size / baseline / dry layout

所以局部反适配至少要拆成三件事：

- `context`
  恢复原始 `MediaQuery`
- `paint`
  恢复绘制和命中测试坐标
- `layout`
  恢复对子组件和父组件都一致的占位语义

## 6. `UnscaledZone` 当前架构

入口在：

- [lib/src/widgets/unscaled_zone.dart](../../lib/src/widgets/unscaled_zone.dart)

当前实现不是一个“大而全”的 render 容器，而是分层拼装。

### 6.1 `context`

通过 `MediaQuery` 恢复原始上下文。

解决的问题：

- 子树里看到的 `size`
- `padding / viewPadding / viewInsets`
- `devicePixelRatio`
- 以及其他 `MediaQueryData` 字段

### 6.2 `paint`

通过 `_PaintUnscale` 恢复绘制和命中测试坐标。

解决的问题：

- 子树视觉尺寸回到原始语义
- hit test 位置和视觉位置一致

### 6.3 `layout`

通过 `_LayoutUnscale` 恢复布局占位语义。

解决的问题：

- 父布局拿到的 size 回到原始语义
- intrinsic size 正确
- dry layout 正确
- baseline 正确

## 7. 两种模式的差异

### `contextFallback`

拼装：

- `context`
- `paint`

不拼：

- `layout`

结果：

- 子树看起来变回原始尺寸
- 但父布局仍按适配态大小给它占位

适合：

- 只想让局部区域恢复原尺寸
- 但不想打乱父布局节奏

### `full`

拼装：

- `context`
- `paint`
- `layout`

结果：

- 子树看起来回到原始尺寸
- 父布局中的占位也一起回退

适合：

- 相邻 widget 也要跟着真实尺寸变化
- 这块区域要彻底退出适配体系

## 8. 为什么要有 `AdaptScope`

如果没有显式状态传递，嵌套的 `UnscaledZone` 很容易重复做反缩放：

- 祖先已经做过一次 `paint`
- 内层再做一次，就会视觉缩错
- 祖先已经做过一次 `layout`
- 内层再做一次，就会占位继续缩错

当前方案通过：

- [lib/src/core/adapt_scope.dart](../../lib/src/core/adapt_scope.dart)

显式往下传递当前子树状态：

- 是否已经 `paintUnscaled`
- 是否已经 `layoutUnscaled`

这样内层只会补缺失层，不会重复反缩放。

## 9. `DesignSizeWidget` 的作用

入口在：

- [lib/src/widgets/design_size_scope.dart](../../lib/src/widgets/design_size_scope.dart)

它做的不是“重新初始化一套全局适配”，而是：

- 局部重建适配态 `MediaQuery`
- 让子树重新进入适配语义

但它不会清掉祖先已经生效的 render 反缩放。

这就是为什么：

- 外层 `UnscaledZone`
- 中间 `DesignSizeWidget`
- 内层再次 `UnscaledZone`

仍然需要依赖 `AdaptScope` 来判断哪些层已经做过，哪些层需要补。

## 10. 其他能力

### `AdaptedPlatformView`

原生视图不运行在 Flutter 的这套逻辑坐标映射里，所以需要额外补偿。

入口在：

- [lib/src/widgets/adapted_platform_view.dart](../../lib/src/widgets/adapted_platform_view.dart)

### `PhysicalPixelZone`

它解决的是物理像素语义问题，不是全局适配问题。

入口在：

- [lib/src/widgets/physical_pixel_zone.dart](../../lib/src/widgets/physical_pixel_zone.dart)

适合：

- 1px 线条
- 细网格
- 像素级绘制

## 11. 从实现到 demo 的映射

- 全局适配： [example/lib/pages/adaptation/adaptation_gallery_page.dart](../../example/lib/pages/adaptation/adaptation_gallery_page.dart)
- `UnscaledZone` 两种模式、嵌套、row sibling 影响、重进适配态：
  [example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart](../../example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart)
- 指针坐标修正：
  [example/lib/pages/input/pointer_events_page.dart](../../example/lib/pages/input/pointer_events_page.dart)
- 原生视图补偿：
  [example/lib/pages/platform_view/platform_view_demo_page.dart](../../example/lib/pages/platform_view/platform_view_demo_page.dart)
- 物理像素语义：
  [example/lib/pages/graphics/physical_pixel_demo_page.dart](../../example/lib/pages/graphics/physical_pixel_demo_page.dart)
- 键盘与 `MediaQuery/viewInsets`：
  [example/lib/pages/input/keyboard_media_query_page.dart](../../example/lib/pages/input/keyboard_media_query_page.dart)

## 12. 一句话总结

`screen_adapt` 的核心不是“把每个数值乘一个比例”，而是“先重建一套全局逻辑坐标系，再为少数特殊区域提供局部退出机制”。
