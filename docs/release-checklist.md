# 0.2.0 发布验收

验收日期：2026-10-11 至 2026-10-15。

2026-10-15 最终源码复核：三工程分析与 25+5+7 项测试通过；小米竖屏规则更新专项 24 组、4320 帧，新增复杂图文父级更新 12 组、2160 帧，计数及方向检查通过；Android profile/release 原生交互各 19 项通过，设置恢复成功。布局公平性修正、绘制隔离诊断与复杂场景差异见 [最终报告](performance-final-20261015.md)。核心测试文档为 [doc/testing.md](../doc/testing.md)；不将性能采集完成标为跨设备稳定通过。

本轮为发布准备，不执行上传、发布或推送。S1/S2 已实现并完成核心回归；扩展已归档。
S3 已完成本轮范围：工程分离、小米 14 Profile 性能复验、Android 五种屏幕配置及 iOS 26.5 三档模拟器原生交互。S4 的独立候选快照全量预检通过，pub dry-run 为 0 warnings；原工作区仍有未提交改动，本轮未提交、推送或发布。iOS 真机不纳入本轮，iOS 27 原生交互问题后续处理。

## 已执行

| 检查 | 结果 |
| --- | --- |
| Flutter / Dart | 3.35.7 / 3.9.2 |
| 核心测试 | 25 项通过，含真实 binding 指针注入和模拟设备指标变化 |
| 初始化修复回归（2026-10-12） | 25 项核心测试及静态分析通过；本地 flutter_tester 关闭断言后，首次/重复初始化、配置更新和已有其他 binding 冲突检查均通过。不是移动端 AOT 验证 |
| Android 初始化 AOT 真机回归（2026-10-12） | 设备 8e3b2e1c，型号 23127PN0CC，Android 16 / API 36 / arm64-v8a；profile 和 release 的 repeat / conflict 四项均取得 PASS。覆盖首次创建、重复调用保留 binding/Controller/指针回调、配置更新及渲染 DPR 对齐、普通 binding 冲突拒绝 |
| Android 自动交互回归（2026-10-13） | 同一 Android 16 真机 profile/release 各 19 项检查全部通过。覆盖 320/375/768 设计宽度、触点内部/边缘/外部、适配开关、拖动、横竖屏切换及键盘、系统字号跟随/忽略/补偿；两轮旋转和字号设置均恢复成功。范围不含人工视觉、高刷、多指、插件冲突或 iOS |
| iOS 模拟器核心回归（2026-10-13） | iPhone 17 Pro / iOS 26.5、iPhone 18 Pro / iOS 27.0，各 11 项核心及 1 项 binding 冲突检查通过，共 24 项，模式 debug。触点为 Dart 指针包注入；不作为原生交互或 AOT 真机验收 |
| example 测试 | 5 项通过，移除扩展测试后保留核心页面 |
| benchmark 测试 | 7 项通过，含纯计算微基准、混合信息流布局和复杂父级更新 build/几何验证；设备帧数据单独采集 |
| 根工程、example、benchmark 分别静态分析 | 均无问题 |
| example Android Profile 构建 | 通过，com.example.example |
| benchmark 默认 Android Profile 构建 | 通过，dev.screenadapt.benchmark |
| benchmark 四个列表/重建对照入口 Profile 构建 | 全部通过，保留原采样工作量 |
| 小米专项复验（2026-10-15） | 规则更新两场景 × 四写法 × 三轮，共 24 组、4320 帧；复杂图文父级更新 × 四写法 × 三轮，共 12 组、2160 帧；另有同负载绘制隔离诊断 12 组。计数及竖屏方向检查通过，旋转设置恢复成功。benchmark 7 项测试和静态分析通过。复杂页不是虚拟化长列表，性能边界见[最终报告](performance-final-20261015.md) |
| vivo 性能补测（2026-10-14） | V2361A / SM7550 / Android 16 / 1080×2400 / 60Hz；设计稿切换与拖动通过默认门槛，常规列表、快速滚动及复验、混合信息流、重建对照已采集。快速滚动与重建有明显 raster 波动，未定位，不标为稳定通过，见 [性能验证](performance-validation.md#2026-10-14-vivo-真机补测) |
| pub.dev 发布 dry-run | 最终独立干净候选退出码 0、0 warnings，约 68 KB；原工作区尚有未提交文件 |
| APK 16 KB ZIP 对齐 | 两工程 zipalign -c -P 16 4 通过；未把 ZIP 检查等同于本轮 ELF 段检查 |
| Android Gradle 配置 | 保留实际生效的 Groovy：AGP 8.6.1、Gradle 8.7、Kotlin 2.1.0；移走冲突的 Kotlin DSL 文件至 archive/build-config |
| 发布包内容 | dry-run 清单未包含 archive、benchmark、tool、docs 或局部扩展；核心仅保留 6 个 Dart 文件 |
| 脚本 | 已切换 benchmark 宿主；语法检查通过，小米 14 指针/设计稿切换、常规列表、快速列表、混合信息流及重建对照均已跑通 |

## 待完成的门槛

1. **本轮设备与性能验收完成**：小米 14 性能及 Android/iOS 阶梯配置已通过，见 [设备矩阵](device-matrix.md)。高刷严格帧预算、复杂多指和任意插件组合列为未验证边界，不作支持承诺。
2. **iOS 构建有可复现路径**：`zsh tool/build_ios_simulator.sh example` / `benchmark` 均通过 arm64 构建及架构检查，benchmark 安装启动通过。通用双架构命令的 lipo 校验问题仍记录为工具链限制；未修改 SDK 或伪称通用构建已修复。
3. **主仓库历史待整理提交**：不覆盖原暂存区。`tool/prepare_release_candidate.py` 按当前有效文件生成独立 Git 快照与 SHA-256 清单；已完成干净快照全量分析、25+5+7 项测试和 dry-run。原仓库未因此变干净；正式发布前仍需审阅提交或明确采用已验证候选快照。
4. **发布身份和决策待确认**：0.2.0、pub.dev 地址与仓库地址一致。按用户要求 LICENSE 已改为 `Copyright (c) 2026 lz001020`。改名前 screen_adapt 的公开 API 返回 HTTP 404，未发现已有包记录；不等于保证可注册，登录身份与最终包名校验由服务端确认。本轮没有上传或发布。

## 发布候选证据

候选目录：`build/release-candidate-20261013234600/source`；同级 `manifest.json` 为文件 SHA-256，`validation.log` 为完整预检。0 warnings、退出码 0；发布包仍只有核心 6 个 Dart 源文件，排除 benchmark、archive、docs、tool。后续追加的验收文档与预检脚本不属于发布包内容。

复现独立候选：先执行 `python3 tool/prepare_release_candidate.py`，再进入输出的 source 目录执行 `zsh tool/check_release.sh`。该快照无远程地址，仅作本地验收；原仓库索引不被修改。

## 可重复检查

```sh
zsh tool/check_release.sh
(cd example && flutter build apk --profile)
(cd benchmark && flutter build apk --profile)
zsh tool/build_ios_simulator.sh example
zsh tool/build_ios_simulator.sh benchmark
./tool/run_android_performance.sh <device-id>
./tool/compare_list_performance.sh <device-id>
./tool/compare_fast_list_performance.sh <device-id>
./tool/compare_rebuild_performance.sh <device-id>
```

`check_release.sh` 不提交或发布；dry-run 的非零结果会保留为失败，避免把带警告预检记录为通过。

## 关闭断言的初始化回归

Flutter 3.35 的 `debugBindingType()` 在关闭断言时始终为 null，不能用于判断是否需要创建 binding。
当前实现读取真实的 `WidgetsBinding.instance`，仅在尚未初始化时创建适配 binding。
下面的本地引擎检查在两个独立进程中执行，不依赖测试框架自动初始化 binding，也不使用 assert 判定结果。
它验证关闭断言的行为，不能代替 Android/iOS profile/release 的 AOT 运行验收。

```sh
# 在仓库根目录执行；将路径改为本机 Flutter SDK。
task_flutter_sdk=/path/to/flutter
(cd example && flutter build bundle --debug --no-pub \
  --target=../tool/binding_initialization_smoke.dart \
  --asset-dir=../build/binding_initialization_smoke)
"$task_flutter_sdk/bin/cache/artifacts/engine/darwin-x64/flutter_tester" \
  --disable-dart-asserts --disable-vm-service --enable-software-rendering \
  build/binding_initialization_smoke/kernel_blob.bin
SCREEN_ADAPT_BINDING_SMOKE_CASE=conflict \
  "$task_flutter_sdk/bin/cache/artifacts/engine/darwin-x64/flutter_tester" \
  --disable-dart-asserts --disable-vm-service --enable-software-rendering \
  build/binding_initialization_smoke/kernel_blob.bin
```

`darwin-x64` 是本轮 SDK 的本机引擎目录，其他 SDK/系统需使用对应的引擎目录。

## Android profile/release 初始化回归

```sh
zsh tool/run_binding_initialization_android.sh <device-id>
```

脚本使用 example 宿主，分别构建并安装 profile/release 下的 repeat/conflict 入口。
每次从新进程启动，通过唯一运行标识匹配设备日志中的 PASS/FAIL，不清空 logcat。
测试会替换设备上的 `com.example.example` 应用；结束后可重新构建安装正常 example。
本轮四项通过日志位于 `build/binding-initialization-20261012225642-20437/`（本地生成、不提交）。
本轮只验证初始化修复，不作为完整交互、性能或 iOS 验收结论。

## Android 自动交互回归

命令、前提及恢复正常示例的步骤见 [移动端回归](../example/TESTING.md#android-自动交互回归)。
2026-10-13 重试记录位于 `build/interaction-20261013003413-profile/` 与
`build/interaction-20261013004502-profile/`，结果均为失败，设备旋转和字号设置均已恢复。
此前 `build/interaction-20261012233749-profile/device.log` 留有竖屏键盘等逐项 PASS，但缺少整轮完成事件。
脚本已补充启动等待、前台检查、子进程超时及失败时保留部分检查记录。

再次重试：`build/interaction-20261013005738-profile/` 在键盘返回阶段超时。
随后为测试页加入返回保护，并改用完整 `dumpsys window` 输出检查前台。
`build/interaction-20261013010331-profile/` 在第 11 次点击时检测到测试应用失去前台并明确失败，尚未执行键盘返回；设置恢复成功。
上述失败重试保留原始结果，不计为成功；最新入口静态分析通过。

最终重试通过（2026-10-13，设备 8e3b2e1c，23127PN0CC，Android 16）：

| 模式 | 报告目录 | 结果 |
| --- | --- | --- |
| profile | `build/interaction-20261013012142-profile/` | 19 项检查全部通过；设备设置恢复成功 |
| release | `build/interaction-20261013012413-release/` | 19 项检查全部通过；设备设置恢复成功 |

每轮完成 36 个原生操作请求，以唯一运行标识的完成事件与 `report.json` 为依据。
本轮验收限于自动脚本覆盖范围，不替代人工视觉、高刷帧性能、多指、插件冲突或 iOS 检查。

## iOS 模拟器回归

报告目录：`build/ios-simulator-20261013201504/`，四个独立运行场景全部通过。

| 模拟器 | 系统 | 核心 / binding 冲突 |
| --- | --- | --- |
| iPhone 17 Pro，4E633A58-C659-4D39-9380-F2B5D090E89A | iOS 26.5 | 11 / 1 项通过 |
| iPhone 18 Pro，D908243A-377D-4522-80D6-5A30382EE3E1 | iOS 27.0 | 11 / 1 项通过 |

修复了 example 最低版本 13 与当前 Xcode 支持范围不兼容的问题，以及 iOS 27 在 Dart 启动前拒绝旧 Scene 生命周期的问题。
通用 `flutter build ios --simulator` 曾报双架构校验错误，针对具体模拟器的 `flutter run` 构建成功；本轮不声称通用双架构构建已修复。
此前失败记录保留在 `build/ios-simulator-20261013194606/`（测试入口策略预期不一致）和 `build/ios-simulator-20261013201048/`（iOS 27 Scene 生命周期崩溃）。
命令和范围见 [移动端回归](../example/TESTING.md#ios-模拟器核心回归)。原生交互状态见下节。

## iOS 模拟器原生交互

本轮按用户要求仅验收模拟器，不把真机作为本轮完成条件。XCUITest 自动执行原生点击、拖动、键盘输入和旋转，Flutter 端检查真实 binding 的坐标与布局。

| 系统 | 结果 |
| --- | --- |
| iOS 26.5 / iPhone 17 Pro | 最终脚本 17 项复验通过，报告 `build/ios-native-20261013221255/report.json` |
| iOS 27 / iPhone 18 Pro | 未通过：早期横屏触点变为零坐标；后续及重启复验在竖屏软键盘弹出超时，最新报告 `build/ios-native-20261013220415/report.json` |

失败证据保留，未放宽触点误差或跳过键盘断言。按用户决定，iOS 27 原因定位转后续处理，不阻塞本轮核心收敛，也不标记该系统已通过。运行方法见 [原生交互回归](../example/TESTING.md#ios-模拟器原生交互回归)。上述结论限 debug 模拟器交互，不包含系统字号修改和性能验收。

## 2026-10-14 包名调整

首次发布包名确定为 `design_scale`，公共入口为 `package:design_scale/design_scale.dart`，版本保持 0.2.0。版权为 lz001020，GitHub 仓库地址不变。同名包公开 API 查询返回 HTTP 404，最终注册由 pub.dev 确认。上面的 20261013234600 快照属于改名前证据，不能用于新包发布；改名后候选另行生成并验收。

改名后候选 `build/release-candidate-20261014000055/source` 已完成全部分析与 25+5+2 项测试，pub dry-run 退出码 0、0 warnings，包名 design_scale、版本 0.2.0、压缩包约 59 KB。同级 `manifest.json` 和 `validation.log` 保留文件哈希与完整证据。未正式发布。

## 随包使用文档

精选使用文档位于 `doc/`：usage、concepts、migration-0.2、troubleshooting、known-issues。README 已链接包内文档；指向内部架构、归档和发布清单的链接使用 GitHub 地址。内部 `docs/` 仍排除。pub 要求单数 doc，最初 docs 方案的警告已解决。最新候选为 `build/release-candidate-20261014011414/source`，同级 validation.log 记录 dry-run 退出码 0、0 warnings。此轮只调整文档与打包，未重复执行行为测试。

## 2026-10-15 最终测试与文档收敛

完整预检候选 `build/release-candidate-20261015010015/source`：三工程分析通过，核心 25、example 5、benchmark 5 项测试通过，pub dry-run 0 warnings。其 Dart 源码与最终设备回归源码一致；Android profile/release 各 19 项通过，报告见 [最终复核](performance-final-20261015.md)。

按用户要求，设备测试全部结束后再完成文档优化。最终文档候选 `build/release-candidate-20261015010833/source` 相对完整预检仅变更 Markdown，未重复行为测试；同级 `packaging.log` 记录 pub dry-run 退出码 0、0 warnings、约 66 KB。`doc/testing.md` 随包，`docs/`、benchmark、tool、archive 与用户 `img.png` 排除。原仓库未提交、推送或发布。本段属于不随包的验收记录，追加于候选生成后。

## 开源发布审阅补齐（2026-10-15）

补齐发布前本地安装、运行示例、贡献指南与 Issue/PR 模板；公开 API 注释说明默认策略、状态更新和 Controller 所有权。修正自定义 binding 的静态方法示例，并排除 build 生成快照参与分析。CHANGELOG 同步生产日志清理；text.txt 与贡献模板不进入 pub 包，原文件保留。

完整预检候选 `build/release-candidate-20261015014806/source`：三工程静态分析通过，25+5+5 项现有测试通过，pub dry-run 0 warnings。最后两处文档措辞修订形成 `build/release-candidate-20261015093537/source`，仅 Markdown 变化；同级 packaging.log 记录退出码 0、0 warnings、约 68 KB，发布清单排除内部资料。本轮无新增运行时逻辑，不重复设备验证；未提交或发布。本段为候选生成后追加的内部验收记录。

2026-10-15 复杂图文专项后发布包复核：最终清单候选 `build/release-candidate-20261015213458/source`；pub dry-run 退出码 0、0 warnings、约 69 KB，`doc/testing.md` 随包，benchmark、tool、archive 与本地 `text.txt` 未进入包。此候选之后仅追加本段内部验收记录；未提交、上传或发布。
