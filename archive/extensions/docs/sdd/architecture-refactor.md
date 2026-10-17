# 架构重构 SDD

状态：进行中
范围：公共库结构收敛与现有 benchmark 分离；不重写性能框架、不迁移无关资源工具。
目标：以少量文件守住计算、状态、框架接入与局部上下文边界。

产品总体规划见[项目路线图](../roadmap.md)；本文的 S0–S4 只表示当前代码重构的执行顺序和验收门槛，不代表产品会优先扩展局部反适配或其他平台。结构设计见[精简项目设计](project-design.md)。Controller 现确定为公共 API；此前的 Reader、Dispatcher、Handle 和独立渲染层规划已取消。

## 需求

### R1：核心计算独立

缩放策略、字体策略和 MediaQuery 转换必须能在不创建 Flutter binding、不读取 `FlutterView`、不访问全局单例的情况下测试。

### R2：框架接入独立

binding 只负责读取设备、更新 `ViewConfiguration`、接收输入包并把结果交给 Controller；不得复制缩放公式。

### R3：上下文传播独立

scope 只负责订阅不可变指标、发布 MediaQuery 和局部反适配状态；局部组件不从全局单例读取窗口状态。

### R4：公共 API 以 Controller 为中心

`lib/screen_adapt.dart` 是唯一推荐入口。`AdaptController` 是公开运行时状态 API，提供配置、快照、启停和订阅；设备注入、binding 所有权和内部快照更新不作为业务 API。内部目录不承诺稳定 API。

### R5：每阶段可回滚

目录迁移可临时保留旧 import 的导出 shim，或在同一变更中更新全部调用方；不因迁移而新增长期兼容 API。每个阶段完成后 `flutter analyze`、库测试和 example 测试都必须通过。

shim 仅在过渡期保留，最终公共 API 阶段移除并更新迁移说明；它不是 v1 长期兼容承诺。新增 benchmark 工程后同样必须通过分析与测试。

## 目标结构

```text
lib/src/
├── core/           # config；metrics + calculator；controller
├── binding/        # 一个文件：设备读取、渲染配置与指针转换
├── scope/          # 一个文件：根组件、业务入口和局部状态
└── widgets/        # 局部组件；RenderObject 留在对应组件文件
```

## 阶段与验收

| 需求 | 验收证据 |
| --- | --- |
| R1 | 纯计算测试覆盖策略、字体与横屏，不创建自定义 binding |
| R2 | 无 view、无效 DPR、旋转/inset 及物理指针注入回归；渲染/输入使用同一快照 |
| R3 | Scope 订阅/退订、无 Scope 降级、嵌套和边界命中测试 |
| R4 | 主入口 API smoke test、非目标导出清理、全部调用方与迁移说明更新 |
| R5 | 每阶段分析与库/example 测试通过，新增 benchmark 后同样验证 |

UnscaledZone 不拆 RenderObject 文件，但保留 layout/paint/hit test/intrinsic/baseline 的验收要求。benchmark 分离只复用现有三个实验，不要求统一实验框架。发布阶段另执行 `flutter pub publish --dry-run` 并核对打包内容。

## 非目标

- 本轮不兼容 v1 行为，不新增旧 API。
- 不在目录迁移阶段改变缩放公式或 hit test 语义。
- 不把性能历史数据改写成当前版本结论。
- 不删除 `.ai/pic/` 或用户未提交文件。

## 每阶段检查

```bash
dart format lib test example/lib
flutter analyze
flutter test
(cd example && flutter test)
```

提交必须使用 `<type>(<scope>): 中文描述`，目录迁移和行为修复分开提交。
