# `screen_adapt` 已知问题与设计限制

其他文档见 [文档导航](README.md)。

本文档只记录两类内容：

- 当前实现仍需关注的风险
- 明确属于设计约束、不是 bug 的行为

## 支持边界

### Flutter Web、桌面端和多窗口

当前版本只验证 Android / iOS 移动端单窗口应用：

- Flutter Web 暂不支持，不能直接导入或复用当前实现
- 桌面端不在当前产品范围内，窗口 resize 语义不提供兼容承诺
- 多窗口 / 多 view 不在当前产品范围内，`ScreenSizeUtils` 仍按主 view 的全局单例设计

如果未来需要支持这些平台，应先单独定义各平台的设计稿、窗口和输入坐标语义，再扩展实现。

## 仍待处理

### 1. `onPointerDataPacket` 接管方式存在冲突风险

当前方案会直接接管 `PlatformDispatcher.instance.onPointerDataPacket`。

影响：

- 如果其他插件也覆盖这个回调，后设置的一方会覆盖前者

建议：

- 缓存原始回调
- 改成链式调用

### 2. 高刷设备上的指针重采样仍需真机验证

当前方案在 binding 层处理指针包，有可能绕开 Flutter 某些内部重采样路径。

影响：

- 90Hz / 120Hz 设备上的拖拽顺滑度需要继续验证

### 3. `handleMetricsChanged()` 存在重复计算

当前某些路径里会多次调用 `ScreenSizeUtils.setup()`。

影响：

- 通常不致错，但存在不必要的重复计算

### 4. 横屏设计稿仍建议真机验证

当前实现会根据横竖屏对宽高参与计算的方式做调整，但“设备横屏”和“设计稿本身横屏”的组合场景仍建议单独验证。

### 5. 手动嵌套 `DesignSizeWidget` 仍可能引入双重缩放

当前实现已经尽量降低嵌套冲突，但如果用户在已经启用 binding 的应用里再次手动套用 `DesignSizeWidget`，仍有可能在已适配的 `MediaQueryData` 基础上再次执行 `.design()`。

建议：

- 增加 assert 或 debug warning

## 设计约束

### 1. `contextFallback` 会保留父布局槽位

这不是 bug，而是模式定义。

表现：

- 子树看起来变小
- 相邻 widget 仍然可能被原逻辑占位推开

如果你不想保留这块占位，应改用 `UnscaledZoneMode.full`。

### 2. `full` 仍受父约束体系影响

`full` 会回退布局占位，但不会绕过 Flutter 正常的父约束机制。

表现：

- 如果父组件本身给了严格约束，`full` 也必须在这套约束内工作

### 3. `PhysicalPixelZone` 主要改变内部绘制语义

它不负责改变外层布局流。

表现：

- 内部能拿到物理像素语义
- 父布局看到的仍是原有逻辑槽位

如果要让外层占位也一起变化，需要额外约束组件配合。

## 已修复但值得保留背景

### 1. `originData` 空安全问题

此前 `originData` 的声明和使用语义不一致，当前已改为可空并安全降级。

### 2. `UnscaledZone` 默认模式语义不完整

此前默认模式更像“只回退上下文”，现在已经明确拆成：

- `contextFallback = context + paint`
- `full = context + layout + paint`

### 3. `PlatformDispatcher.instance.views.first` 无防御访问

当前已补充空视图防御，避免 fallback 场景直接抛异常。

## 建议的阅读顺序

- 如何接入： [usage.md](usage.md)
- 为什么这样设计： [concepts.md](concepts.md)
- 遇到问题怎么排查： [troubleshooting.md](troubleshooting.md)
