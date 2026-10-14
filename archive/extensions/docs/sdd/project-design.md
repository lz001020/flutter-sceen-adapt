# 项目总体设计（精简版）

状态：当前重构的目标结构。产品范围、优先级和后续阶段以[项目路线图](../roadmap.md)为准；本文只描述代码结构与公共 API 设计。[迁移规格](architecture-refactor.md)记录本轮重构需求与验收，[当前架构](../architecture.md)描述已落地现状。

## 1. 只守住三个边界

1. 计算不读设备：公式与字体转换可脱离 binding 测试。
2. 状态只有一个来源：Controller 产生快照，渲染、输入和 Scope 使用同一结果。
3. 局部组件只读上下文：不使用全局残留状态兜底。

面向 Android / iOS 单窗口，不扩展 Web、桌面、多 view。不要求兼容 v1；旧入口只在迁移期暂留，不建立长期兼容层。文件按实际职责拆分，不为预想的扩展创建类和空目录。

## 2. 目标结构与类职责

```text
lib/
├── screen_adapt.dart
└── src/
    ├── core/
    │   ├── adapt_config.dart
    │   ├── adapt_metrics.dart
    │   └── adapt_controller.dart
    ├── binding/
    │   └── adapt_binding.dart
    ├── scope/
    │   └── adapt_scope.dart
    └── widgets/
        ├── unscaled_zone.dart
        ├── physical_pixel_zone.dart
        ├── adapted_platform_view.dart
        └── legacy_screenutil_scope.dart
test/                  # 保留平铺，按职责命名测试文件
example/               # 使用示例与功能测试实验室
benchmark/             # 独立性能实验，先复用现有代码
tool/                  # 少量检查、设备和性能脚本
docs/                  # 使用、当前架构、验证和 SDD
.github/workflows/     # 发布收尾阶段按需补检查
```

| 文件 | 类/类型 | 职责 |
| --- | --- | --- |
| adapt_config.dart | AdaptConfig、ScreenAdaptType | 不可变设计尺寸、策略和字体配置；值比较与 copyWith |
| adapt_metrics.dart | AdaptMetrics、AdaptCalculator | 只读原始/适配快照和纯计算；内部字体 scaler 同文件 |
| adapt_controller.dart | AdaptController | **公共**适配状态源，输入去重、配置更新、启停和通知；不读取设备、不调用 binding |
| adapt_binding.dart | DesignSizeWidgetsFlutterBinding、DesignSizeBindingMixin | 设备读取、Controller 所有权、ViewConfiguration、指针转换与队列 |
| adapt_scope.dart | DesignSizeWidget、DesignSizeWidgetState、DesignSize、AdaptScope、AdaptScopeState | 根订阅、MediaQuery、业务配置入口及子树反适配标记；合并现有两个 scope 文件 |
| unscaled_zone.dart | UnscaledZone、UnscaledZoneMode、现有私有 RenderObject | context/paint/layout 分层补偿与命中映射，渲染实现仍放同文件 |
| physical_pixel_zone.dart | PhysicalPixelZone | 局部物理像素语义；无界约束安全降级 |
| adapted_platform_view.dart | AdaptedPlatformView | 原生组件布局/视觉补偿，不管理插件生命周期 |
| legacy_screenutil_scope.dart | LegacyScreenUtilScope、LegacyChildWrapper | 隔离业务中的 ScreenUtil 子树；库本身不依赖 ScreenUtil |

取消独立 platform、rendering、compatibility 目录；不新增 DeviceMetricsReader、DeviceMetricsRead、AdaptPointerDispatcher、DesignSizeHandle。只有代码确实增长或出现第二个使用方时再考虑抽取。

## 3. 依赖与生命周期

```text
binding（设备/输入） → Controller → Calculator → Metrics
                         │
                         ├→ binding：渲染配置与指针 DPR
                         └→ scope：MediaQuery → 局部组件
```

目标由 binding 创建并持有单窗口 Controller，根 Scope 通过内部参数接收同一实例；Scope dispose 时退订，不销毁借用的 Controller。业务可从 Scope 获取同一个 Controller，也可在纯 Dart/Widget 测试中自行创建和释放 Controller。局部 RenderObject 只接收参数与 child，不读取 Controller。

这仍是单窗口设计，不宣称多实例支持。当前代码仍依赖 ScreenSizeUtils，迁移时将设备读取并入 binding、将配置调用改到现有 Scope 后再清理，不仅移动文件。

## 4. 公共 API：公开 Controller，不增加 Facade

`AdaptController` 是唯一运行时状态 API。公开它是为了让状态、配置和通知拥有一个真实来源，不再返回 Widget State，也不再增加 Handle、Facade 或兼容包装。推荐入口为 `package:screen_adapt/screen_adapt.dart`：

```dart
void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    type: ScreenAdaptType.width,
    scaleText: true,
    supportSystemTextScale: true,
  );
  runApp(const MyApp());
}

// build 中读取会建立依赖；返回的是同一个 AdaptController。
final AdaptController adapt = AdaptController.of(context);
final AdaptConfig config = adapt.config;
final AdaptMetrics? metrics = adapt.metrics; // 无设备快照时可空

// 例如按钮回调：
adapt.setDesignSize(const Size(320, 568));
adapt.setEnabled(false); // 保留配置，恢复原始坐标
adapt.setEnabled(true);  // 使用保留配置重新启用

// 不建立依赖的读取场景，例如回调、服务或测试。
final AdaptController? maybe = AdaptController.maybeOf(context);
final AdaptController? current = AdaptController.read(context);
```

保留的行为契约：

- 初始化先于 runApp，已有其他 binding 时明确报错；高级组合继续使用现有 mixin configure 入口。
- setDesignSize 保留其他配置并启用适配；setEnabled(false) 恢复原始坐标但保留配置，setEnabled(true) 重新启用，重复调用不重复通知。
- config/metrics/enabled 只读；`of` 建立依赖，`maybeOf` 建立可空依赖，`read` 不建立依赖；没有 Scope 时 `of` 抛明确错误，另外两个返回 null。
- 瞬时无效设备尺寸/DPR 保留上次有效结果，无 view 时清空；不能因整理目录改变这些行为。
- 局部组件的模式、父约束和边界命中语义保持不变。

目标显式导出：AdaptConfig、ScreenAdaptType、AdaptMetrics、AdaptController、两个 binding 类型、四类局部组件与关联模式/回调类型。根 Scope 是 binding 自动挂载的内部实现，不作为业务初始化 API；Controller 通过 `AdaptController.of/maybeOf/read` 获取。

Calculator、AdaptScope/State、私有 RenderObject 不属于目标公共 API。Controller 的设备输入、任意 scale 覆盖、Controller 所有权和销毁能力不属于公共业务 API；binding 使用库内私有入口更新设备快照。收紧当前传递导出、移除 ScreenSizeUtils 和旧文件入口是独立的破坏性清理步骤，须同步更新所有调用方、CHANGELOG 与迁移说明，不混进纯搬迁提交。

### AdaptController 公共契约

| API | 语义 |
| --- | --- |
| `config` | 当前不可变配置，只读 |
| `metrics` | 当前 `AdaptMetrics?`，设备尚未有效时为空，只读 |
| `enabled` | 是否使用设计稿适配；不能用 `scale == 1` 推断 |
| `configure(config)` | 校验并原子替换配置，同时启用适配；相同配置幂等 |
| `setDesignSize(size)` | 只替换设计尺寸，保留适配策略和字体配置，并启用 |
| `setEnabled(value)` | 只切换适配开关，保留配置；相同值幂等 |
| `of(context)` | 建立依赖，返回当前 Scope 的 Controller |
| `maybeOf(context)` | 建立可空依赖 |
| `read(context)` | 不建立依赖，未找到 Scope 时返回 null，供回调和一次性读取使用 |
| `addListener/removeListener` | 状态快照改变时通知；Controller 的 dispose 由创建方负责 |

`updateDeviceMetrics` 及设备输入相关参数标记为库内实现细节，不在主入口导出为业务能力。Controller 不提供 `instance` 单例；应用只能使用 binding 创建的上下文实例，测试可以显式构造。

## 5. example、benchmark 与文档

example 保留现有测试页与共用 Shell/Diagnostics，不先增加 showcase 分层或服务层。

benchmark 作为独立 Flutter 应用，`publish_to: none`，先搬迁现有入口和脚本支持三个实验：

| 实验 | 目的 |
| --- | --- |
| 指标计算 | 计算耗时、重复输入去重与通知正确性 |
| 列表滚动 | 同工作量下的 build/raster/total 帧指标 |
| 父级重建 | 设计常量与 ScreenUtil 内联写法对比，后续补优化后的 const 对照 |

不同 binding 仍采用独立入口/进程，ScreenUtil 对照依赖只放 benchmark。先复用已有列表、采样和报告代码；确有重复时抽小函数，不预建 Runner、Scenario、Encoder 等通用框架。独立工程使用自己的宿主、应用标识和构建输出路径。

[性能 Demo 设计](../performance-demo-design.md) 中的公平性、采样完整性和证据要求仍有效；其中统一实验框架、展示首页与统一报告是后续可选方向，不是本轮交付前提。历史成绩不冒充新版本结论。

test、tool、docs 暂不全面拆子目录。保留现有自动测试，按需补 API 导入与状态所有权测试。文档只维护当前架构、使用、已知问题、性能记录及本规格，避免重复描述同一套状态。

## 6. 迁移阶段与完成标准

| 阶段 | 工作 | 验收 | 状态 |
| --- | --- | --- | --- |
| S0 | binding/scope 初步迁移 | 分析、库38项、example6项通过 | 已完成，含临时 shim |
| S1 | 拆出配置文件，合并 Scope；设备读取与 Controller 所有权收归 binding | 公式、状态通知、初始化、reset、输入/布局测试不回归 | 待做 |
| S2 | 清理 ScreenSizeUtils、临时 shim 与非目标导出 | 更新全部调用方，公共入口测试、CHANGELOG/迁移说明齐全 | 待做 |
| S3 | 独立 benchmark，移除 example 的对照依赖 | 两工程分析/测试/构建通过，脚本可运行，工作量未改变 | 待做 |
| S4 | 发布收尾与文档同步 | 发布清单和 dry-run、必要设备回归、Android 配置验证 | 待做 |

按“规格 → 测试 → 实现 → 验收”小步推进。每阶段按风险拆提交；不以全部搬完目录作为完成标准。库不依赖 example/benchmark；不删除用户资料，不自动发布或推送。
