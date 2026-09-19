# `screen_adapt` 设计与原理

本文档和当前实现以 Android / iOS 移动端单窗口为目标。Flutter Web、桌面端以及多窗口 / 多 view 不属于当前支持范围。

其他文档见 [文档导航](README.md)。

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

## 3. 指标计算与状态

入口在：

- [lib/src/core/screen_metrics.dart](../../lib/src/core/screen_metrics.dart)

指标链路分成两层：

- `AdaptConfig`：不可变的设计尺寸、适配模式和字体策略
- `AdaptCalculator`：不读取 binding 或全局单例的纯计算器
- `AdaptMetrics`：一次计算产生的原始指标、适配指标和 scale
- `AdaptController`：持有配置与指标，去重设备输入，调用计算器并通知订阅者；不读取 view，也不调用 binding
- `ScreenSizeUtils`：保留现有 API 的设备适配层，读取 view 后交给 Controller

`ScreenSizeUtils` 通过 Controller 暴露：

- 保存设计稿尺寸
- 保存适配模式
- 保存原始 `MediaQueryData`
- 保存适配后的 `MediaQueryData`
- 保存最新的不可变 `AdaptMetrics`

这里的两个数据要区分：

- `originData`
  设备原始指标
- `data`
  适配后的指标

后面 `UnscaledZone`、`DesignSizeWidget`、指针补偿都会依赖这两个状态。缩放公式和 `MediaQueryData` 转换可以脱离 Flutter binding 单独测试；后续状态管理重构也不需要再次改动计算规则。

设备变化由 binding 调用 `setup()` 读取一次指标，再交给 Controller。运行时配置变化直接更新 Controller，由它通知 binding 更新 RenderView、通知根 Scope 重建 MediaQuery。`createViewConfigurationFor()` 只读取结果，根 Scope 不再模拟设备指标回调。

渲染配置、指针坐标转换和根 Scope 都读取 Controller 的同一份 `AdaptMetrics`。旧兼容字段上的临时覆盖不会直接改变这些链路。尚无有效指标时，根 Scope 使用祖先 `MediaQuery` 并保持 scale 为 1；配置变化仍通知依赖 `DesignSize.of(context).config` 的组件。

兼容入口 `ScreenSizeUtils.setDesignSize()` 将配置与本次读取的设备指标一同交给 Controller，只发布最终结果，避免先用旧设备指标计算一次再通知第二次。`reset()` 基于当前快照恢复原始坐标，不额外读取设备。瞬时无效设备指标不会覆盖上一份有效结果；配置仍可通过 `configure()` 单独更新。

`DesignSize.of(context).setDesignSize(...)` 保留字体和适配策略。`reset()` 显式关闭适配，之后旋转或键盘变化仍使用原始指标，直到再次设置设计稿。旧的 `ScreenSizeUtils` 字段入口暂时保留；直接写入 `scale/originData/data` 仅用于兼容，正常更新应使用配置方法，设备刷新时会清除这些覆盖值。

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

- 原始与适配后的 `MediaQueryData`
- 当前 `scale`
- 是否已经 `paintUnscaled`
- 是否已经 `layoutUnscaled`

这样局部组件不需要读取全局单例，内层也只会补缺失层，不会重复反缩放。没有 `AdaptScope` 时，`UnscaledZone`、`LegacyScreenUtilScope` 和 `AdaptedPlatformView` 都原样返回，不会使用其他页面残留的窗口状态。

## 9. `DesignSizeWidget` 的作用

入口在：

- [lib/src/widgets/design_size_scope.dart](../../lib/src/widgets/design_size_scope.dart)

它做的不是“重新初始化一套全局适配”，而是：

- 局部重建适配态 `MediaQuery`
- 让子树重新进入适配语义
- 通过 `DesignSize.of(context).metrics` 向业务暴露当前不可变指标快照

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

- 全局适配： [example/lib/main.dart](../example/lib/main.dart)
- `UnscaledZone` 两种模式、嵌套、row sibling 影响、重进适配态：
  [example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart](../../example/lib/pages/unscaled_zone/unscaled_zone_demo_page.dart)
- 指针坐标修正：
  [example/lib/pages/input/pointer_events_page.dart](../../example/lib/pages/input/pointer_events_page.dart)
其他能力请直接参考 [usage.md](usage.md) 中对应 API 小节。

## 12. 一句话总结

`screen_adapt` 的核心不是“把每个数值乘一个比例”，而是“先重建一套全局逻辑坐标系，再为少数特殊区域提供局部退出机制”。
