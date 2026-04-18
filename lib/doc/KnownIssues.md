# `screen_adapt` 已知问题与优化建议

本文档记录方案在研发过程中识别出的潜在问题与优化方向，按优先级分级列出。

---

## 高优先级（潜在崩溃 / 功能失效）

### 1. Flutter Web 平台崩溃

**位置**: `core/screen_size_utils.dart:73`

**问题**: `dart:io` 的 `Platform` 类在 Flutter Web 上不可用，调用时直接抛出异常。

```dart
// 当前代码 —— Web 上崩溃
if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
```

**建议**: 改用 `kIsWeb` + `defaultTargetPlatform`：

```dart
import 'package:flutter/foundation.dart';

final bool _isDesktop = !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
     defaultTargetPlatform == TargetPlatform.macOS ||
     defaultTargetPlatform == TargetPlatform.windows);
```

---

### 2. `originData` 的 `LateInitializationError`

**位置**: `widgets/unscaled_zone.dart:70`，`core/screen_size_utils.dart:32`

**问题**: `originData` 声明为 `late MediaQueryData`（非可空），但 `UnscaledZone` 里对它做了 null 检查：

```dart
if (originalMediaQueryData == null || ...) // 永远不成立的死代码
```

如果 `UnscaledZone` 在 `setup()` 被调用之前渲染（如热重载极早期），访问 `originData` 会抛出 `LateInitializationError`，而不是走到安全分支。

**建议**: 将 `originData` 改为可空类型 `MediaQueryData?`，或在 `_internal()` 构造中通过 `PlatformDispatcher` 提前初始化。

---

### 3. `views.first` 假设 views 非空

**位置**: `core/screen_size_utils.dart:95`

**问题**: 在单元测试 / 无头环境下，`PlatformDispatcher.instance.views` 可能为空，`.first` 直接抛出 `StateError`。

```dart
final view = PlatformDispatcher.instance.views.first; // 可能崩溃
```

**建议**: 加防御性检查：

```dart
final views = PlatformDispatcher.instance.views;
if (views.isEmpty) return;
final view = views.first;
```

---

## 中优先级（行为异常 / 需确认的设计决策）

### 4. `onPointerDataPacket` 被完全替换，存在插件冲突风险

**位置**: `core/bindings.dart:91`

**问题**: 使用直接赋值替换回调，而非链式调用。若第三方插件（输入法、无障碍服务等）也设置了同一回调，后设置的一方会覆盖前者，导致其中一方的手势处理完全失效。

```dart
PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
```

**建议**: 保存并链式调用原始回调：

```dart
final _originalOnPointerDataPacket = PlatformDispatcher.instance.onPointerDataPacket;

void _handlePointerDataPacket(ui.PointerDataPacket packet) {
  // ... 自定义逻辑 ...
  _originalOnPointerDataPacket?.call(packet);
}
```

---

### 5. 高刷屏（90Hz/120Hz）的指针重采样被绕过

**位置**: `core/bindings.dart:88-92`

**问题**: Flutter 的 `GestureBinding` 提供 `resamplingEnabled` 机制，在高刷新率设备上对触摸事件做插值以平滑滑动。当前方案在 `initInstances` 中完全替换了 `onPointerDataPacket`，绕过了这条路径：

```dart
// Flutter GestureBinding 内部（被绕过的路径）
if (resamplingEnabled) {
  _resampler.addOrDispatch(event);
  _resampler.sample(samplingOffset, _samplingClock);
  return;
}
```

**影响**: 在 120Hz Android 手机上，滚动/拖动的流畅度可能低于原生水平。

**建议**: 在真机（120Hz 设备）上实测滚动帧率，与未使用本方案的对照组对比，确认是否有肉眼可见的差异后再决定是否修复。

---

### 6. `_getAdaptedDevicePixelRatio` 在手势热路径上存在冗余查找

**位置**: `core/bindings.dart:120-132`

**问题**: 手机只有一个 view，但每次指针事件都执行两次 dispatcher 查找：

```dart
final view = platformDispatcher.view(id: viewId);       // map 查找
if (viewId == platformDispatcher.implicitView?.viewId)  // 再次访问
```

手势密集时（快速滑动、绘图），此开销会在每个事件上重复。

**建议**: 在绑定初始化时缓存 `implicitViewId`：

```dart
late final int? _implicitViewId = platformDispatcher.implicitView?.viewId;

double? _getAdaptedDevicePixelRatio(int viewId) {
  if (viewId == _implicitViewId) {
    return ScreenSizeUtils.instance.data.devicePixelRatio;
  }
  return platformDispatcher.view(id: viewId)?.devicePixelRatio;
}
```

---

### 7. 桌面端 resize 后 scale 冻结

**位置**: `core/screen_size_utils.dart:98-101`

**问题**: 桌面窗口 resize 后，`originData` 会更新为新窗口尺寸，但 `scale` 永远停留在启动时的计算值，不会重新适配：

```dart
if (_isDesktop && scale != defaultScale) {
  data = originData.design(); // 使用旧 scale，不重新计算
  return;
}
```

**需确认**: 这是有意为之（桌面端固定 scale，窗口自由拉伸）还是 bug？若是有意设计，建议在代码注释和文档中明确说明。

---

### 8. `double?` 回调签名与 Flutter 版本的兼容性

**位置**: `core/bindings.dart:120`

**问题**: 传给 `PointerEventConverter.expand` 的回调返回 `double?`，但不同 Flutter 版本对该参数签名的可空性要求不一致，升级 Flutter 时可能悄悄编译失败。

```dart
double? _getAdaptedDevicePixelRatio(int viewId) // 返回 double?
```

**建议**: 在 `pubspec.yaml` 中锁定 `flutter` SDK 下限版本，并在 CI 中覆盖 stable/beta 频道的回归测试。

---

### 9. `handleMetricsChanged` 中 `setup()` 被调用两次

**位置**: `core/bindings.dart:151-158`

**问题**: 每次屏幕旋转/分屏变化时，`setup()` 被重复计算：

```dart
ScreenSizeUtils.instance.setup();            // 第一次
renderView.configuration = createViewConfigurationFor(renderView); // 内部再调用一次
```

**建议**: 在 `createViewConfigurationFor` 中移除对 `setup()` 的调用，改在 `handleMetricsChanged` 里统一调用一次后再刷新配置。

---

## 低优先级（边界场景）

### 10. 多视图 / 多窗口场景不支持

`ScreenSizeUtils` 是全局单例，绑定的是 `views.first`。在 iPad 多窗口或桌面多窗口场景下，每个窗口有独立的 `FlutterView`，当前架构无法为不同窗口维护独立的适配状态。

---

### 11. 横屏设计稿的适配逻辑错误

**位置**: `core/screen_size_utils.dart:107-110`

代码在检测到设备横屏时会翻转 `currentWidth/currentHeight`，但没有检查 `designSize` 本身是横屏还是竖屏。若用户传入横屏设计稿（`width > height`），翻转逻辑会反向计算，产生错误的 scale。

---

### 12. 用户手动嵌套 `DesignSizeWidget` 可能导致双重缩放

若用户同时使用 binding（已在 `wrapWithDefaultView` 中插入 `DesignSizeWidget`）并手动在 widget 树顶层再套一个，内层 `build()` 会在已适配的 `MediaQueryData` 上再次调用 `.design()`，导致双重缩放。

**建议**: 在 `DesignSizeWidget.build()` 中加 assert 或日志提示：若检测到祖先已有 `DesignSize`，且当前非 `UnscaledZone` 内部，则 warning。

---

### 13. `PhysicalPixelZone` 只影响绘制，不影响布局

**位置**: `component/physical_pixel_zone.dart:44`

`Transform.scale` 是纯绘制层变换，不影响 layout 阶段。内部 widget 实际占用的布局空间不变，视觉上被压缩后会留有空白，相邻 widget 不会重新排布。

**建议**: 在文档和组件注释中明确说明此行为，提示用户若需要布局也跟随收缩，应同时使用 `SizedBox` 限制尺寸。