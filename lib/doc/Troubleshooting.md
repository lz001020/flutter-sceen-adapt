# `screen_adapt` 排查指南

本文档按“现象 -> 优先检查项”的方式组织。

## 1. 页面整体尺寸不对

优先检查：

- `main()` 里是否先调用了 `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`
- 设计稿尺寸是否写对
- `ScreenAdaptType` 是否符合当前页面预期

建议：

- 先打开示例工程的运行时设计稿切换，对照当前目标设计稿验证一遍

参考：

- [example/lib/adaptation_gallery_page.dart](../../example/lib/adaptation_gallery_page.dart)

## 2. 点击位置偏移 / 拖拽轨迹不对

优先检查：

- 是否正确使用了 binding 初始化，而不是只套了 `DesignSizeWidget`
- 是否有插件或自定义逻辑覆盖了 `onPointerDataPacket`

建议：

- 先用示例页验证当前机器上的点击和拖拽行为

参考：

- [example/lib/demo3/pointer_test_page.dart](../../example/lib/demo3/pointer_test_page.dart)

## 3. 某块区域看起来不该被适配

优先判断：

- 你只是想让它自己恢复原尺寸？
- 还是连占位也一起恢复？

选择：

- 只恢复自己：`UnscaledZone.contextFallback`
- 连占位一起恢复：`UnscaledZone.full`

参考：

- [example/lib/unscaled_zone_demo_page.dart](../../example/lib/unscaled_zone_demo_page.dart)

## 4. `contextFallback` 看起来变小了，但相邻 widget 还是被推开

这是模式定义，不是 bug。

原因：

- `contextFallback` 只回退 `context + paint`
- 它不会回退父布局里的占位

如果你希望相邻 widget 跟着真实尺寸变化，请改用：

- `UnscaledZoneMode.full`

## 5. `full` 似乎没有生效

优先检查：

- 父组件是不是给了严格约束
- 你看的到底是“逻辑占位”还是“最终绘制”
- demo 本身有没有额外 padding / overlay 干扰判断

建议：

- 用示例页里的 `Mode Comparison` 和 `Row Sibling Impact` 交叉验证

## 6. 嵌套 `UnscaledZone` 后尺寸继续缩错

优先检查：

- 是否是旧实现或旧 demo 的认知残留
- 当前子树里是否已经有祖先生效的 `paint` / `layout` 回退

当前实现通过 `AdaptScope` 显式传递状态，正常情况下：

- 祖先已经做过 `paint`，内层不会重复做
- 祖先已经做过 `layout`，内层只补缺失层

如果仍然缩错，建议先在示例页复现：

- [example/lib/unscaled_zone_demo_page.dart](../../example/lib/unscaled_zone_demo_page.dart)

## 7. 中间套了 `DesignSizeWidget` 后行为不符合预期

要先分清：

- `DesignSizeWidget` 负责恢复适配态 `MediaQuery`
- 它不会清掉祖先已经生效的 render 反缩放

所以外层如果已经进入 `UnscaledZone`，中间再套 `DesignSizeWidget`，内层行为必须结合 `AdaptScope` 一起理解。

建议：

- 直接看 `DesignSizeWidget Re-entry` 相关 demo

## 8. `PlatformView` 尺寸或点击不对

优先检查：

- 是否直接使用了 `AndroidView / UiKitView / WebView`
- 是否应该改成 `AdaptedPlatformView`

参考：

- [example/lib/platform_view_demo.dart](../../example/lib/platform_view_demo.dart)

## 9. 键盘弹出后输入区被遮挡

优先检查：

- 当前页面是否正确消费了 `viewInsets`
- `MediaQuery` 是否被意外放在过低层级
- 列表 / 输入区是否能随内容一起滚动

参考：

- [example/lib/keyboard_media_query_page.dart](../../example/lib/keyboard_media_query_page.dart)

## 10. 1px 线条发虚

优先检查：

- 这是普通逻辑像素绘制，还是物理像素语义场景

如果是后者，优先考虑：

- `PhysicalPixelZone`

参考：

- [example/lib/physical_pixel_demo_page.dart](../../example/lib/physical_pixel_demo_page.dart)

## 11. 还不知道该看哪个 demo

按问题类型选：

- 全局适配不对：`Adaptation Gallery`
- 局部反适配不对：`UnscaledZone`
- 点击 / 拖拽不对：`Pointer Events`
- 原生视图不对：`PlatformView`
- 像素线条不对：`PhysicalPixelZone`
- 键盘 / inset 不对：`Keyboard & Insets`
