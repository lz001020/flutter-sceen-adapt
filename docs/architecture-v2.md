# screen_adapt 架构重构方案 v2

面向 README Roadmap **阶段 4：向多形态设备策略化演进**。

本文档描述下一代架构的目标、拆分方式、迁移节奏和尚未确定的问题，作为后续拆分 issue / 分支的依据。

---

## 1. 现状盘点

当前架构的核心模块关系：

```
DesignSizeWidgetsFlutterBinding
  └── ScreenSizeUtils.instance (单例，存 designSize / adaptType / scale)
        └── DesignSizeWidget 直接读这个单例拿 MediaQueryData
              └── UnscaledZone 通过 AdaptScope 往下传适配态
```

阶段 4 推进时会碰到的几条硬约束：

| 问题 | 现状 | 阶段 4 为什么挡路 |
|---|---|---|
| 适配策略硬编码在单例里 | `ScreenSizeUtils.instance` 持有 `designSize`/`adaptType`/`scale`，`adaptType` 是 enum `width/height/min` 三选一 | 大屏需要"小屏按 width，大屏切到 layout-grid" —— 三选一的 enum 没有扩展点 |
| 逻辑全集中在 binding | `lib/src/core/bindings.dart` 同时管 DPR 计算、view configuration、pointer 转换、metrics 变化、根 widget 包装 | 多 view / 多窗口下，"哪个 view 用哪个策略"是 per-view 决策，不是全局单例 |
| `scale` 是个标量 | 整个适配假设"等比缩放" | 大屏的居中窗口、安全区偏移、双栏布局不是缩放问题，是 layout 重映射问题 |
| library 层文件混乱 | `lib/` 根下 8 个 re-export 文件与 `lib/src/` 并存 | 公共 API 边界不清晰，下次大改容易破坏外部依赖 |
| `originData` 双向依赖 | metrics 单例缓存 `MediaQueryData`，widget 读单例，更新靠 `handleMetricsChanged` | 多 view 下这条单例链断裂 |
| 没有 per-view 维度 | DPR 适配在 `_getAdaptedDevicePixelRatio` 里只针对 `implicitView` | 桌面/平板的多窗口、嵌入式 view 都进不来 |

---

## 2. 目标架构

自下而上四层：

```
┌─────────────────────────────────────────────────────┐
│  4. Widgets 层                                       │
│     DesignSizeWidget / UnscaledZone / 等             │
│     （消费者，不再直接读 ScreenSizeUtils.instance）   │
└─────────────────────────────────────────────────────┘
                       ↑ 通过 InheritedWidget 读
┌─────────────────────────────────────────────────────┐
│  3. Runtime 层                                       │
│     ScreenAdaptRuntime (per-view)                   │
│       - currentStrategy                              │
│       - originMetrics → adaptedMetrics              │
│       - 缓存 + 失效通知                              │
│     ScreenAdaptRegistry                              │
│       - viewId → Runtime 的映射                      │
└─────────────────────────────────────────────────────┘
                       ↑ 由 Binding 喂数据
┌─────────────────────────────────────────────────────┐
│  2. Strategy 层（核心扩展点）                          │
│     abstract class AdaptStrategy {                   │
│       AdaptResult resolve(AdaptInput input);         │
│     }                                                │
│     内置实现：                                       │
│       - DesignSizeStrategy (width/height/min)        │
│       - DualPaneStrategy   (折叠/展开态)              │
│       - CenteredWindowStrategy (大屏居中)            │
│       - PassthroughStrategy (不适配)                 │
│     可由用户自定义                                    │
└─────────────────────────────────────────────────────┘
                       ↑ Binding 驱动
┌─────────────────────────────────────────────────────┐
│  1. Binding 层                                       │
│     DesignSizeBindingMixin（已落地）                  │
│       - 只负责钩 Flutter 引擎事件，不做策略决策        │
└─────────────────────────────────────────────────────┘
```

---

## 3. 关键设计点

### 3.1 Strategy 抽象（最核心）

```dart
class AdaptInput {
  final ui.FlutterView view;
  final MediaQueryData originMediaQuery;
  final BoxConstraints physicalConstraints;
}

class AdaptResult {
  final double devicePixelRatio;     // 写回 ViewConfiguration
  final BoxConstraints logicalConstraints;
  final MediaQueryData adaptedMediaQuery;
  final Matrix4? pointerTransform;   // 指针坐标修正，多窗口/居中场景有偏移
}

abstract class AdaptStrategy {
  AdaptResult resolve(AdaptInput input);
  bool shouldRebuild(AdaptInput old, AdaptInput now) => true;
}
```

把现在 `lib/src/core/bindings.dart` 里的 `createViewConfigurationFor` 和 `ScreenSizeUtils.setup` 拆出来，全塞进 `DesignSizeStrategy.resolve`。

**收益**：阶段 4 的大屏适配 = 写一个新的 `Strategy`，不动 binding 不动 widget。

### 3.2 per-view Runtime

```dart
class ScreenAdaptRuntime extends ChangeNotifier {
  ScreenAdaptRuntime(this.viewId, this._strategy);
  final int viewId;
  AdaptStrategy _strategy;
  AdaptResult? _last;

  AdaptResult resolve(AdaptInput input) {
    final r = _strategy.resolve(input);
    _last = r;
    return r;
  }

  void setStrategy(AdaptStrategy s) {
    _strategy = s;
    notifyListeners();
  }
}

class ScreenAdaptRegistry {
  static final _runtimes = <int, ScreenAdaptRuntime>{};
  static ScreenAdaptRuntime of(int viewId) =>
      _runtimes.putIfAbsent(viewId, () => /* ... */);
}
```

替代当前 `ScreenSizeUtils.instance` 单例。`ScreenSizeUtils` 保留为 v1 兼容门面（内部读 `implicitView` 的 runtime），不删，挂 `@Deprecated`。

### 3.3 Binding 瘦身

`DesignSizeBindingMixin` 现在做了 5 件事。重构后只做 2 件：

- 钩 `onPointerDataPacket` → 委托给 `ScreenAdaptRegistry.of(viewId).resolve(...).pointerTransform`
- 在 `createViewConfigurationFor` 里把 `renderView.flutterView` 喂给 registry，拿结果回写

策略实例化、设计稿存储、metrics 缓存 —— 全搬走。

### 3.4 Widget 层解耦

`DesignSizeWidget` 现在依赖 `ScreenSizeUtils.instance.data`。新版改成：

```dart
class DesignSizeWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final runtime = ScreenAdaptRegistry.of(View.of(context).viewId);
    return ListenableBuilder(
      listenable: runtime,
      builder: (_, __) => MediaQuery(
        data: runtime.last.adaptedMediaQuery,
        child: child,
      ),
    );
  }
}
```

每个 view 独立适配，多窗口下天然可工作。

### 3.5 目录结构

```
lib/
  screen_adapt.dart                   // 唯一公共入口，re-export
  src/
    binding/
      design_size_binding.dart        // mixin + 便捷类
    strategy/
      adapt_strategy.dart             // 抽象 + AdaptInput/Result
      design_size_strategy.dart       // 当前能力的策略化实现
      dual_pane_strategy.dart         // 阶段 4 新增
      passthrough_strategy.dart
    runtime/
      adapt_runtime.dart              // per-view 状态
      adapt_registry.dart             // viewId 注册表
    widgets/
      design_size_widget.dart
      unscaled_zone.dart              // 内部 AdaptScope 不变
      adapted_platform_view.dart
      physical_pixel_zone.dart
      legacy_screenutil_scope.dart
    compat/
      screen_size_utils.dart          // 旧 ScreenSizeUtils 门面，@Deprecated
```

`lib/` 根下 8 个旧 re-export 文件（`lib/bindings.dart` 等）：保留一个版本周期标记 `@Deprecated('use package:screen_adapt/screen_adapt.dart')`，下个大版本删。

---

## 4. 分批落地节奏

避免一次性大爆炸。

| 批次 | 内容 | 风险 |
|---|---|---|
| **R1 抽象骨架** | 引入 `AdaptStrategy` / `AdaptInput` / `AdaptResult` / `ScreenAdaptRuntime` / `Registry`；`DesignSizeStrategy` 包住现有逻辑；binding 改成调 strategy 但行为不变 | 低，纯重构，行为等价 |
| **R2 widget 切换数据源** | `DesignSizeWidget` 从读 `ScreenSizeUtils.instance` 改为读 `Registry`；`ScreenSizeUtils` 变薄壳 | 中，触及全部 widget |
| **R3 per-view** | binding 按 viewId 分发；多 view 路径走通；指针 transform 支持非缩放偏移 | 中，要补 example |
| **R4 阶段 4 新策略** | 实现 `DualPaneStrategy` / `CenteredWindowStrategy`，加 example 专题页 | 业务工作量 |
| **R5 目录与公共 API 收敛** | 清理 `lib/` 根下旧 re-export，发主版本 | 破坏性变更，发 v2 |

每批落地后的验收基线：example 工程全部专题页行为不变、benchmark 页数值不回退。

---

## 5. 尚未确定的问题

写在前面，避免后面踩坑：

1. **多 view 的 DPR 同步**
   Flutter `RenderView` per-view 配置在哪一帧生效，跟 `createViewConfigurationFor` 的调用时机是否对齐 —— 需要先用一个最小 demo 验证后再定 API。

2. **`UnscaledZone` 和 strategy 的耦合**
   `UnscaledZone` 现在假设父级是单一 scale；如果将来 strategy 输出的不是均匀缩放（比如 layout 重排），`paintUnscaled` 的语义要重新定义。这块可能不是简单"换底盘"能解决的。

3. **`AdaptResult.pointerTransform`**
   纯缩放场景下退化为 DPR 除法（和现在一样）；非缩放策略下变成完整 Matrix4。性能上得测一下，benchmark 页要加 matrix 路径的对照组。

4. **`flutter_screenutil` 兼容层**
   `LegacyScreenUtilScope` 当前基于单 scale 假设；如果策略不是缩放型，兼容层定义不清楚。阶段 4 的新策略进来之前，先把兼容层的"只对缩放型策略生效"这条约束显式化。

---

## 6. 非目标

明确不在本次重构范围内：

- 不重写 `UnscaledZone` 的三层拆分（context/paint/layout 的实现已稳定）
- 不改变 `AdaptedPlatformView` / `PhysicalPixelZone` 的对外 API
- 不移除 `ScreenSizeUtils`，只做兼容降级
- 不引入新的状态管理库（保持 `ChangeNotifier` + `InheritedWidget`）
