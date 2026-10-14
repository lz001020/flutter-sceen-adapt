# 架构重构验收

范围：S1/S2 核心收敛 → 扩展归档 → S3 独立性能工程 → S4 发布检查。

| 要求 | 当前证据 |
| --- | --- |
| 计算独立 | adapt_calculator_test 覆盖策略、横屏和字体，无 binding/全局状态 |
| 设备读取归 binding | binding_metrics_test 覆盖旋转、inset、字体、无效 DPR、无 view 与恢复 |
| 输入/渲染同快照 | binding_runtime_test 注入物理触点验证内外边界及启停 |
| Scope 生命周期 | adapt_controller_test 验证替换、退订、借用状态不销毁和 read 不订阅 |
| API 收敛 | public_api_test 验证主入口、旧入口移除、设备实例方法移除和无 Scope 错误 |
| 无重复状态通知 | 重复输入、配置、启停去重；scale=1 的启停仍通知 |
| 扩展移除 | archive/extensions 留历史快照，运行库无 widgets 和局部状态 |
| 性能分离 | benchmark 独立 pubspec/宿主，example 无 ScreenUtil 依赖 |

命令：dart format lib test example/lib example/test benchmark/lib benchmark/test；
三个工程分别 flutter analyze / flutter test；两个应用 Android Profile 构建；flutter pub publish --dry-run。
最终结果及环境阻塞详见 [发布清单](../release-checklist.md)。
