# `screen_adapt` 方案核心设计与技术原理解析

`screen_adapt` 是一个为 Flutter 设计的、侵入性低且高性能的屏幕适配方案。其核心思想是**在 Flutter 渲染引擎层面进行全局的、一次性的缩放**，使得开发者在上层 UI 开发中，可以直接使用设计稿的尺寸单位（dp）进行布局，而无需在每个组件上进行手动计算或调用扩展方法。

本方案旨在平衡易用性、性能和灵活性，其设计涉及了对 Flutter 框架底层机制的深度定制。

---

## 1. 核心技术：定制 `WidgetsFlutterBinding`

Flutter 的 `WidgetsFlutterBinding` 是连接 Flutter 引擎与 Dart 代码的桥梁。通过自定义该绑定，我们可以在 Flutter 应用的生命周期早期介入，修改其默认行为。

### `DesignSizeWidgetsFlutterBinding`

本方案的核心是 `DesignSizeWidgetsFlutterBinding`。它继承自 `WidgetsFlutterBinding`，并重写了几个关键方法，以实现全局屏幕适配。

#### 1.1. 视图配置修改: `createViewConfigurationFor()`

- **原理**: 这是 Flutter 渲染流水线中的一个关键环节，负责确定渲染视图的逻辑尺寸和设备像素比 (`devicePixelRatio`)。Flutter 引擎根据这里的配置来决定如何将物理像素映射到逻辑像素 (dp)。
- **实现**: 我们重写此方法，不再使用设备原始的 `devicePixelRatio`。而是：
    1.  获取设备的物理尺寸 (`physicalConstraints`)。
    2.  根据用户设定的适配模式 (`ScreenAdaptType`) 和设计稿尺寸 (`designSize`)，计算出一个全局缩放比例 `scale`。
    3.  生成一个**新的 `devicePixelRatio`** (`originDevicePixelRatio * scale`)。
    4.  计算出**新的逻辑约束 `logicalConstraints`** (`physicalConstraints / newDevicePixelRatio`)。
    5.  将这个全新的 `ViewConfiguration` 返回给引擎。
- **效果**: 这一步操作直接在引擎层面“欺骗”了 Flutter，让它认为当前设备的逻辑尺寸就是我们期望的适配尺寸（通常等于设计稿尺寸）。之后的所有布局和绘制都将基于这个新的逻辑坐标系，从而实现了全局的、无感的适配。

#### 1.2. 手势事件修正

- **原理**: 当 `devicePixelRatio` 被修改后，来自引擎的指针事件（如点击、拖动）的坐标仍然是基于物理像素的。如果不进行转换，这些事件在新的逻辑坐标系下会发生定位错误。
- **实现**: 我们通过 Hook `PlatformDispatcher.instance.onPointerDataPacket`，在 `PointerEventConverter` 扩展指针数据时，强制使用我们适配后的 `devicePixelRatio`。
- **效果**: 确保在全局缩放的环境下，所有手势交互依然精准无误。

## 2. 适配逻辑管理: `ScreenSizeUtils`

这是一个单例类，作为整个方案的中央数据和逻辑管理器。

- **职责**:
    -   存储设计稿尺寸 (`designSize`) 和适配模式 (`adaptType`)。
    -   存储设备的原始 `MediaQueryData` (`originData`) 和适配后的 `MediaQueryData` (`data`)。
    -   **计算核心缩放比例 `scale`**: 这是适配逻辑的核心。`setup()` 方法会根据 `adaptType`（宽度、高度或最小值）以及设备的当前朝向，计算出 `scale` 值。
- **`MediaQueryDataExtension.design()`**: 提供一个便利的扩展方法，可将任意 `MediaQueryData` 实例根据 `scale` 值转换为适配后的版本。

## 3. 局部反适配: `UnscaledZone`

全局适配虽然强大，但在某些场景下我们需要局部禁用它（例如：显示一个第三方库的 UI、绘制像素级精确的图形）。`UnscaledZone` 就是为此而生。

- **职责**: 在其子树中创建一个“隔离区”，恢复到设备原始的、未经缩放的尺寸体系。
- **实现原理**:
    1.  **注入原始 `MediaQuery`**: `UnscaledZone` 首先通过 `MediaQuery` Widget，将其子树的 `MediaQueryData` 强制恢复为 `ScreenSizeUtils.instance.originData`。这解决了尺寸、边距等信息的问题。
    2.  **修正布局约束**: 全局适配不仅影响 `MediaQuery`，还影响了父级传递给子级的布局约束 (`BoxConstraints`)。`UnscaledZone` 使用 `LayoutBuilder` 获取被缩放过的约束，然后将其乘以 `1.0 / scale`（反向缩放因子），最后通过 `ConstrainedBox` 将修正后的、原始的约束传递给子级。
    3.  **嵌套问题处理**: 通过内置一个 `_UnscaledZoneMarker` (`InheritedWidget`)，`UnscaledZone` 可以检测到其祖先节点是否已存在另一个 `UnscaledZone`。如果存在，当前 `UnscaledZone` 将自动跳过所有逻辑，避免双重反向缩放导致的布局错误。

## 4. 易用性与灵活性

- **一行代码激活**: 通过在 `main()` 函数中调用 `DesignSizeWidgetsFlutterBinding.ensureInitialized(...)`，用户可以轻松激活并配置整个方案。
- **多种适配模式**: `ScreenAdaptType` 枚举提供了按宽度、高度或最小边的适配能力，满足不同场景的需求。
- **清晰的结构**: 项目被拆分为 `core` (核心逻辑) 和 `widgets` (UI组件)，职责分明，易于维护和扩展。

---

**总结**: `screen_adapt` 方案通过在 Flutter 框架的底层进行精巧的定制，实现了高性能的全局屏幕适配，同时通过 `UnscaledZone` 等设计提供了必要的灵活性，最终为开发者带来“所见即所得”的顺滑开发体验。
