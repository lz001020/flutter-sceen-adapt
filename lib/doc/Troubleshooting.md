# 屏幕适配方案潜在问题与解决方案

本方案通过在 `WidgetsFlutterBinding` 层修改 `devicePixelRatio` (DPR) 来实现全局缩放。这种方案具有极低侵入性的优点，但也因为在底层“欺骗”了引擎，会带来一些特定的边缘问题。

---

## 1. 手势点击坐标偏移 (Pointer Event Misalignment)

### 问题描述
Flutter 引擎发送的原始触摸数据是物理像素坐标。在将物理像素转换为逻辑坐标时（`PointerEventConverter.expand`），默认使用的是系统原始 DPR。由于我们修改了渲染层的逻辑尺寸，如果不同步修改手势系统的 DPR 转换逻辑，会导致点击位置发生偏移。

### 解决方案
在 `DesignSizeWidgetsFlutterBinding` 中 Hook `onPointerDataPacket`，确保转换时使用适配后的 `devicePixelRatio`。
*   **实现**: 重写 `_devicePixelRatioForView` 或 `_handlePointerDataPacket`，针对主视图返回 `ScreenSizeUtils.instance.data.devicePixelRatio`。

---

## 2. 原生组件嵌入 (Platform Views)

### 问题描述
`WebView`, `AndroidView`, `UiKitView` (如地图、视频播放器、原生广告) 是由原生系统直接渲染的。原生系统并不知晓 Flutter 内部修改了 DPR。
*   **表现**: 原生组件的大小可能显示不全（过大或过小），位置可能发生偏移，或者组件内部的点击事件完全失效。

### 解决方案
对于此类组件，需要局部“反适配”。
*   **方法**: 使用 `UnscaledZone` 包裹原生组件。
*   **注意**: 传递给原生组件的 `width` 和 `height` 需要手动乘以缩放比例 `scale`，以确保在物理屏幕上占据正确的位置。

---

## 3. 软键盘弹出与 `viewInsets`

### 问题描述
软键盘的高度由原生系统决定并以物理像素反馈。虽然方案中已经对 `viewInsets` 进行了缩放处理，但在某些极端场景下：
*   **表现**: 键盘顶起的高度不足或过多；在嵌套滚动或复杂的 `ResizeToAvoidBottomInset` 逻辑中，UI 可能无法完美避开键盘。

### 解决方案
*   **检查**: 确保 `ScreenSizeUtils` 中的 `design()` 扩展正确处理了 `viewInsets / scale`。
*   **适配**: 如果在某个页面键盘处理极其异常，可使用 `UnscaledZone` 暂时恢复到原始坐标系处理输入逻辑。

---

## 4. 屏幕旋转与分屏 (Metrics Changed)

### 问题描述
当设备发生物理旋转（竖屏切横屏）或在平板上进入分屏模式时，物理尺寸会瞬间改变。如果适配参数没有及时同步更新，整个 UI 会拉伸变形。

### 解决方案
*   **监听**: 在 `DesignSizeWidgetsFlutterBinding` 中重写 `handleMetricsChanged`。
*   **同步**: 在该方法中重新触发 `ScreenSizeUtils.instance.setup()`，并循环调用 `renderView.configuration = createViewConfigurationFor(renderView)` 强制刷新渲染树配置。
*   **UI 刷新**: 确保顶层的 `DesignSizeWidget` 能够响应指标变化并触发 `setState` 重新注入 `MediaQuery`。

---

## 5. 字体缩放策略 (Text Scaling)

### 问题描述
系统设置中的“大字体”模式会与全局缩放系数 `scale` 产生叠加效应。
*   **表现**: 开启系统大字体后，适配后的 UI 里的文字可能会溢出组件边界（Overflow）。

### 解决方案
*   **策略一 (锁定)**: 在覆盖 `MediaQueryData` 时，强制设置 `textScaler: TextScaler.noScaling`，使应用忽略系统字体大小设置，完全遵循设计稿。
*   **策略二 (兼容)**: 在 `ScreenSizeUtils` 计算 `scale` 时，将 `textScaleFactor` 纳入考量，或者在设计 UI 时留出足够的伸缩空间。

---

## 6. 系统弹窗与 Overlay (System Dialogs)

### 问题描述
部分第三方 Toast 库或直接调用原生 Dialog 的插件，可能不会继承应用内的 `MediaQuery` 状态。
*   **表现**: 弹窗字体极其微小或巨大，背景遮罩无法全屏。

### 解决方案
*   **标准**: 优先使用 Flutter 原生的 `showDialog` 或 `Overlay` 机制。
*   **注入**: 确保所有的适配逻辑在 `MaterialApp` 之上完成注入。如果必须使用第三方 Overlay 库，检查其是否支持自定义 `MediaQuery` 或 `context`。

---

## 7. 物理像素对齐 (Pixel Snapping)

### 问题描述
由于 `scale` 通常是浮点数（如 1.12345），适配后的逻辑像素乘以适配后的 DPR 可能不再是整数物理像素。
*   **表现**: 极细的边线（1px）可能在某些位置变模糊，或者产生微小的“子像素”缝隙。

### 解决方案
*   **绘制**: 绘制极细线条时，尽量使用逻辑像素并开启抗锯齿。
*   **组件**: 某些对对齐极其敏感的 UI，可以使用 `PhysicalPixelZone` 组件（如果已实现）来确保子树在物理像素边界上对齐。
