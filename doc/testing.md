# 核心测试与验证

本页回答三个问题：核心适配是否正确、使用者如何复验、性能结论能推广到哪里。当前只维护 Android/iOS 单窗口全局适配；局部反适配等扩展已归档，不参与当前验收。

## 核心承诺与证据

| 核心承诺 | 自动验证内容 | 仓库测试入口 |
| --- | --- | --- |
| 尺寸计算正确 | 宽度/高度/min 模式、横屏、字体策略、非法指标 | `test/adapt_calculator_test.dart`、`test/adapt_controller_test.dart` |
| 状态更新一致 | 配置与设备指标形成一致快照；关闭后保持原始坐标、通知次数与依赖重建 | `test/adapt_controller_test.dart` |
| 渲染与输入一致 | 实际 binding 的渲染 DPR、根布局、物理尺寸、安全区、指针坐标 | `test/binding_runtime_test.dart`、`test/binding_metrics_test.dart`、`test/binding_controller_test.dart` |
| 初始化可预测 | 首次创建、重复复用、旧入口、已有其他 binding 时明确拒绝 | `test/legacy_binding_init_test.dart`、`test/binding_conflict_test.dart`；Android AOT 初始化脚本 |
| 指针接管边界明确 | 初始化前回调保留；初始化后被插件覆盖会绕过适配 | `test/binding_callback_chain_test.dart`、`test/binding_callback_overwrite_test.dart` |
| 公共接口稳定 | 仅暴露当前核心 API；缺少上下文时报告明确错误 | `test/public_api_test.dart` |
| 系统交互正确 | 原生点击、拖动、键盘、旋转；Android 另测系统字号 | Android ADB 与 iOS XCUITest 驱动 |

测试文件是验证入口，不是对任意插件或设备的兼容承诺。特别是“被插件覆盖后绕过适配”属于已知限制的回归测试，通过表示行为已明确，不能解释成插件兼容通过。

## 从源码复验

pub 包包含核心库、核心测试、示例与精选使用文档。下列设备脚本、benchmark 和测试证据需要克隆 [GitHub 仓库](https://github.com/lz001020/flutter-sceen-adapt)。在仓库根目录运行：

```sh
flutter pub get
flutter analyze
flutter test
(cd example && flutter pub get && flutter analyze && flutter test)
(cd benchmark && flutter pub get && flutter analyze && flutter test)
```

最低支持版本为 Flutter 3.22.0 / Dart 3.4.0。核心库、example 和 benchmark 已使用
Flutter 3.22.3 / Dart 3.4.4 验证；真机回归使用的 SDK 单独记录，自动测试不代表所有设备和插件组合均兼容。

仓库的 [CI 配置](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/.github/workflows/ci.yml)在 push 和 Pull Request 时，对 Flutter 3.22.3、3.35.7 分别执行三个工程的分析与测试。格式检查和 pub dry-run 使用 Flutter 3.35.7 / Dart 3.9.2；本地完整预检使用同一版本。CI 不包含设备交互与性能回归。

真实 binding 测试放在独立测试文件中，避免全局 binding 单例互相污染。Widget 测试中的模拟指标和指针不能替代系统键盘与原生触摸。发布前完整预检使用 `zsh tool/check_release.sh`；它包含 pub dry-run，不执行上传。

设备回归按成本分层执行：

| 层级 | 目的与命令 | 通过标准 |
| --- | --- | --- |
| Android AOT 初始化 | `zsh tool/run_binding_initialization_android.sh <device-id>` | profile/release 的 repeat/conflict 场景均收到对应 PASS |
| Android 原生交互 | `python3 tool/run_android_interaction_regression.py <device-id> --mode profile`，再执行 release | 本轮唯一标识对应的 19 项检查与完成事件齐全，设备设置恢复成功 |
| iOS 模拟器核心 | `python3 tool/run_ios_simulator_regression.py <simulator-uuid>` | 核心 11 项及冲突 1 项通过；限 debug 注入验证 |
| iOS 模拟器原生交互 | `python3 tool/run_ios_native_regression.py <simulator-uuid>` | XCUITest 原生操作对应 17 项检查通过；保留 report、日志与 xcresult |

运行条件、应用替换、设备恢复和失败处理详见仓库 [移动端回归](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/example/TESTING.md)。不要同时在同一设备运行两套测试。

## 性能验证回答什么

性能实验独立于功能正确性：功能通过不表示更快，build 次数减少不表示整帧耗时一定下降。

| 对照场景 | 所验证的机制 | 不能据此宣称 |
| --- | --- | --- |
| 父级更新、商品内容不变 | const/子树复用是否跳过静态区域；与合理优化的 ScreenUtil 对照 | const 收益为本库独有 |
| 单卡价格更新 | 状态隔离与静态详情复用；同样更新次数下的帧工作 | 通知次数少就一定整帧更快 |
| 复杂图文父级更新 | 12 张本地图文卡片在已缓存图片下的静态子树复用 | 首次图片解码、网络、功耗或所有复杂页面性能 |
| 复杂信息流 | 新 item、混合布局、动画与滚动的完整帧成本 | 所有页面与设备性能相同 |
| 绘制隔离诊断 | 两边同时加 RepaintBoundary，检查静态区域重绘贡献 | 诊断结果能代替默认页面的性能排名 |

两库使用相同内容、状态通知与优化粒度，核对非单位倍率下物理布局、字体样式和边框。默认 Profile、三轮、第二轮反转顺序；固定竖屏，逐组记录有效显示方向，更新专项排除预热。计数不符、帧数不足或方向不符均失败，不能删除异常组后宣布通过。

帧报告分别记录 UI、raster、total 的 p90/p99 和固定 16.667ms 参考预算超时帧。UI 是 FrameTiming.buildDuration，包含布局与绘制工作，并非纯 build() 时间；各项分位数不可相加。三轮中位数不是统计显著性证明，固定预算不是严格 90/120Hz 验收。带 Timeline 的诊断批次单独保留，不混入默认性能排名。

复现方法与原始指标见仓库 [专项设计](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/update-performance-design.md)和 [性能验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-validation.md)。当前可证明常量尺寸表达与静态子树复用机制；尚未测量开发工时、业务转化率、内存或功耗收益。

## 当前验证边界

截至 2026-10-15 的最终回归：

| 验收 | 实测结果 |
| --- | --- |
| 根工程 / example / benchmark | 本轮 benchmark 7 项测试通过；发布源码候选记录的根工程 / example 为 25 / 5 项 |
| 小米 14 更新专项 | 规则两场景 × 四写法 × 三轮为 4320 帧；复杂图文另三轮 × 四写法为 2160 帧，工作量与方向检查通过 |
| 小米 14 原生交互 | 最终源码 profile / release 各 19 项通过，设备设置恢复成功 |
| 默认绘制路径性能对照 | 父级 total p90 中位数 5.130 / 4.963ms，局部 5.057 / 4.943ms（design_scale / ScreenUtil）；接近，前者仍略高 |
| 复杂图文默认对照 | 父级 total p90 中位数 4.262 / 4.467ms（design_scale / ScreenUtil）；逐轮方向变化，不构成稳定领先结论 |

完整逐轮数据与诊断见 [发布前最终复核](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-final-20261015.md)。以上检查通过不代表性能等价或跨设备性能稳定。

- Android 小米 14 原生交互的 profile/release 已有通过记录；iOS 26.5 模拟器原生交互已有通过记录。
- iOS 27 原生交互未通过，按本轮范围安排后续定位。模拟器结果不能代替 iOS 真机性能或 AOT 验收。
- vivo 快速滚动存在尚未定位的 raster 长帧波动，不标为跨设备性能稳定通过。
- 复杂多指、高刷严格帧预算、任意插件组合、PlatformView、多窗口、Web 与桌面不在当前验证范围。

每次发布以仓库 [发布清单](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/release-checklist.md)的日期、源码快照与报告为准。失败保留完整证据；修改测试负载后重新形成独立批次，旧批次不覆盖。

## 参考与采用方式

- [Flutter 官方测试概览](https://docs.flutter.dev/testing/overview)：采用单元、Widget、设备集成分层；原生交互另用平台驱动。官方页面版本随时间更新，本仓库实测 SDK 以发布记录为准。
- [flutter_screenutil README](https://github.com/OpenFlutter/flutter_screenutil/blob/master/README.md)：参考其窗口变化重建规则与测试稳定等待说明；本库另验证真实 binding，不直接套用其初始化方式或测试结论。

参考资料查阅日期：2026-10-15。本文采用其文档组织思路，所有通过状态均来自本仓库实测。
