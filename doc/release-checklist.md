# 0.2.0 发布检查

0.2.0 已于 2026-10-18 发布到 [pub.dev](https://pub.dev/packages/design_scale/versions/0.2.0)，对应源码提交 `b09e2f3`。以下记录发布条件和已完成的验证。

## 发布条件

- [x] 审阅并提交待发布源码，确认包名、版本、版权、SDK 约束和仓库地址。
- [x] 对最终源码执行 `zsh tool/check_release.sh`，分析、测试、格式检查和 pub dry-run 均通过。
- [x] 核对发布文件清单，排除 `demo/`、`tool/`、`archive/`、`doc/` 中的维护与性能资料及本地产物。
- [x] 按变更范围完成相关设备回归，明确已知限制；宿主迁移后复跑相应入口。
- [x] 确认 pub.dev 登录身份、包名可注册及发布决定。

如需隔离未提交状态，可执行 `python3 tool/prepare_release_candidate.py`，在输出的 source 目录运行检查；快照附 SHA-256 清单，不改主仓库索引。正式发布应以审阅后的最终源码为准。

## 最新验收状态：2026-10-18

| 项目 | 已有结果与待办 |
| --- | --- |
| 工程结构 | example 为咖啡下单用例；demo 统一承载交互与性能入口，应用标识 `dev.designscale.regression` |
| 分析与测试 | 提交前全量预检在 Flutter 3.35.7 分析与格式检查通过，核心 25 项、example 2 项、demo 12 项测试通过；新 example 在 Flutter 3.22.3 分析与 2 项测试通过。合并后的 demo 已有 Flutter 3.22.3 分析和 12 项测试通过记录 |
| 构建 | example Android Debug 与 Profile 构建通过；合并后 demo Android Profile 性能入口及 iOS arm64 模拟器性能入口构建通过 |
| 发布包 | 文档目录统一为 `doc/`；提交后在干净工作区执行 pub dry-run，结果为 0 warnings，最终压缩约 57 KB，已上传 pub.dev；测试文档仅保留在仓库 |
| Android 原生交互 | 小米 14 / Android 16：Profile 与 Release 最新轮次各 19 项通过，旋转与字号设置已恢复 |
| example 真机用例 | 小米 14 Profile：冰饮与数量选择、原生键盘备注输入、订单金额与内容、返回菜单、横屏可见及运行日志检查，共 7 项通过；设备旋转设置已恢复 |
| 性能入口冒烟 | 小米 14 竖屏 Profile：设计稿切换与 30 次原生拖动通过；783 帧，帧耗时 P90 3.052 ms，超过 16.667 ms 的帧 2 帧（0.26%），满足本脚本阈值；不作为库间性能对比 |
| 发布结果 | pub.dev 已确认发布 `design_scale 0.2.0` |

历史设备覆盖见[测试指南](testing.md#设备覆盖)，关键性能数据及未解决的 vivo 波动见[性能验证](performance-validation.md)。迁移前设备结果不能代替合并后宿主验收；iOS 27 等已知问题见[已知限制](known-issues.md)。

操作步骤见[测试指南](testing.md)、[移动端回归](../demo/TESTING.md)和[性能复现](performance-validation.md#复现)。

本轮设备验证证据：

- 性能入口：`build/performance-smoke-20261017223310/report.json` 与同目录 `run.log`。
- example：`build/example-smoke-20261017223206/report.json`。
- Profile：`build/interaction-20261017220534-profile/report.json`。
- Release 通过轮次：`build/interaction-20261017222840-release/report.json`。
- Release 早期超时轮次：用户确认测试期间手动操作造成干扰，不计入有效验收，也不作为发布阻塞项；原始记录保留在 `build/interaction-20261017222429-release/report.json` 等本地报告中，以后续 19 项通过轮次作为验收依据。

完整性能对比沿用现有报告，本轮仅验证合并后入口。发布账号授权与上传已完成。
