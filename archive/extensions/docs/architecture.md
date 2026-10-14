# screen_adapt 当前架构

本文描述当前代码，而非未来路线图。目标为 Android / iOS 移动端单窗口；验证覆盖见 [已知问题](known-issues.md) 和 [测试说明](../example/TESTING.md)。不承诺 Web、多窗口或全部原生组件兼容。

## 核心决策

将尺寸适配从业务数值换算移到 binding 的逻辑坐标映射。业务组件可以直接使用设计稿尺寸和常量表达式；布局、绘制和输入必须使用同一份缩放结果，不能只调整 MediaQuery 或 paint。

宽度适配示例，原始逻辑宽度 W、设计宽度 D、设备 DPR 为 r：

```text
scale = W / D
adaptedDpr = r × scale
adaptedLogicalSize = physicalSize / adaptedDpr
pointerPosition = physicalPointerPosition / adaptedDpr
```

高度/min、横屏与字体策略由计算器统一处理。const 收益发生在父级重建且子树实例可复用时，不能跳过首次 mount，也不消除 layout/raster 工作。

## 模块职责

| 层 | 实现 | 职责与边界 |
| --- | --- | --- |
| 配置与结果 | AdaptConfig / AdaptMetrics | 不可变配置和原始/适配指标快照 |
| 计算 | AdaptCalculator | 纯计算；不读 FlutterView、不依赖单例 |
| 状态 | AdaptController | 输入去重、合并配置与设备变化、通知订阅者；不调用 binding |
| 设备与兼容 | ScreenSizeUtils | 读取设备、选择平台策略，保留旧入口并转交 Controller |
| 渲染与输入 | DesignSizeBindingMixin | 更新 RenderView，使用适配 DPR 转换指针包 |
| 上下文 | DesignSizeWidget / AdaptController / AdaptScope | 订阅快照，发布 MediaQuery、配置和局部反适配状态 |
| 局部退出 | UnscaledZone 等 | 基于 Scope 恢复上下文、绘制和布局语义 |

源码：[核心模块](../lib/src/core/)、[局部组件](../lib/src/widgets/)。

## 数据流

```text
设备变化 → binding.handleMetricsChanged → ScreenSizeUtils.setup
                                                     ↓
配置切换 → AdaptController.setDesignSize ─────→ AdaptController
                                                     ↓
                                             AdaptCalculator
                                                     ↓
                                               AdaptMetrics
                                ┌────────────────────┼────────────────┐
                                ↓                    ↓                ↓
                         ViewConfiguration      指针转换读取     Scope/MediaQuery
                                                                      ↓
                                                               局部反适配组件
```

- 启动：runApp 前配置并创建自定义 binding，不能替换已经初始化的其他 binding。
- 设备变化：先刷新 Controller，再调用框架指标处理；期间抑制监听器重复更新 RenderView。
- 配置变化：直接更新 Controller，由监听器更新渲染配置和 Scope，不伪造设备事件。
- 去重：相同输入不重复计算/通知；兼容入口将配置与设备变化合并发布最终快照。
- reset：恢复原始坐标，设备变化后仍保持未适配，直到重新设置设计稿。
- 无效指标：瞬时无效输入保留上一份有效结果；无 view 时清空，Scope 使用祖先 MediaQuery。

渲染、输入与 Scope 消费同一 Controller 快照。当前仍有单窗口单例与兼容字段，并非已完成多实例隔离的全新公共 API。旧字段临时覆盖不直接驱动这些链路，正常更新应使用配置方法。

## 局部反适配

| 模式 | context | paint / hit test | layout |
| --- | --- | --- | --- |
| contextFallback | 原始 MediaQuery | 反缩放与触点映射 | 保留父级槽位 |
| full | 原始 MediaQuery | 反缩放与触点映射 | 同步转换约束、尺寸和布局查询 |

AdaptScope 记录 paintUnscaled/layoutUnscaled，嵌套组件仅补齐缺失部分；没有 Scope 时不借用全局残留状态。context 超出父槽位的绘制区域不保证命中，full 也不能突破父约束。

AdaptedPlatformView 提供视觉与尺寸补偿，不代表所有 WebView/地图插件都已验收。PhysicalPixelZone 需要有限约束，无界时原样返回。

## 验证证据与边界

- 计算层：策略、字体、横屏和指标换算。
- 状态层：去重、原子通知、reset、无效指标及 Scope 订阅。
- binding 层：宿主测试引擎注入物理指针包，验证切换后的点击与布局；不等于系统触屏测试。
- 局部组件：中心/边缘/外部命中、嵌套、无 Scope 降级和约束行为。
- 设备层：真实触控、软键盘、原生视图与高刷行为另行验收。

2026-09-19 本地验证：库 38 项、example 6 项通过，静态分析无问题。vivo V2361A 当前 Profile 应用启动成功，用户反馈指针手动测试通过；未完成全场景设备回归。

待关注：指针回调被插件覆盖、高刷重采样、横屏键盘遮挡及手动嵌套 DesignSizeWidget 的语义。性能跑分不能代替正确性验收。

## 面试讲解主线

先讲逻辑坐标重映射的取舍，再讲 DPR、输入与 MediaQuery 一致性；接着解释纯计算器/Controller/设备层分离如何避免重复通知，最后展示局部反适配分层和验证证据。性能数据及简历措辞见 [性能 Demo 设计](performance-demo-design.md)。
