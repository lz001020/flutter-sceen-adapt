# 移动端回归

核心承诺、测试分层及性能结论边界见 [核心测试与验证](../doc/testing.md)。本页提供设备操作细节；逐轮结果由 [发布清单](../doc/release-checklist.md)记录。

先运行 flutter analyze 和 flutter test，再在 Android/iOS 目标设备执行：

| 场景 | 操作与观察 |
| --- | --- |
| 设计稿 | 320/375/768 切换，布局、DPR 与点击靶点一致 |
| 指针 | 点击三个靶点内部及边缘、外部不应计数；拖动后重置 |
| 窗口 | 横竖屏来回旋转、切换设计稿，指标有限且恢复稳定 |
| 字体 | 系统字号 1.0/放大，分别开启/关闭系统跟随；检查逻辑字号和文字裁切 |
| 键盘 | 底部输入框打开/关闭键盘，旋转后恢复，确保 viewInsets 和可见范围正确 |
| 高刷 | 90/120Hz 真机连续拖动、多指，记录异常和帧数据 |
| 插件 | 检查插件是否覆盖 onPointerDataPacket，复测输入 |

应用日志使用 [demo:window]、[demo:text]、[demo:keyboard]、[demo:pointer]。
Widget 测试不能替代实际软键盘、原生输入或高刷设备回归。
本轮连接设备及验收状态见 [发布清单](../doc/release-checklist.md)。

## Android 自动交互回归

在仓库根目录运行（需要 Flutter、Python 3、ADB）：

```sh
python3 tool/run_android_interaction_regression.py <device-id> --mode profile
python3 tool/run_android_interaction_regression.py <device-id> --mode release
```

手机应保持解锁，并允许 USB 调试及原生输入注入。每轮测试期间不要手动操作或切换应用。
脚本会替换 `dev.designscale.regression`，通过独立入口保留真实适配 binding，使用 ADB 点击、拖动、输入、返回、旋转和修改系统字号。
覆盖 320/375/768 设计宽度、点击内部/边缘/外部、适配开关、拖动、横竖屏键盘与 viewInsets、字号跟随及补偿。
该入口不依赖会预先创建测试 binding 的 integration_test。

每轮报告保存在 `build/interaction-<时间>-<模式>/`，包含构建日志、设备日志和 `report.json`。
仅收到本轮唯一标识对应的完成事件才判定成功；失败报告保留已通过的检查。
正常结束、异常及 Ctrl+C 均尝试恢复原有旋转和字号设置，并校验读取值。
强制杀死主机进程或设备断开可能阻止恢复，应依据报告中的 `original_settings` 手动恢复。
前台检查会在切换应用时终止测试。

测试后恢复功能实验室：

```sh
(cd demo && flutter build apk --release --no-pub --target=lib/main.dart)
adb -s <device-id> install -r demo/build/app/outputs/flutter-apk/app-release.apk
adb -s <device-id> shell am start -W -n dev.designscale.regression/.MainActivity
```

自动回归不替代文字裁切等视觉检查，也不覆盖高刷帧性能、多指、插件冲突或 iOS。

## iOS 模拟器核心回归

启动目标模拟器后，在仓库根目录执行：

```sh
python3 tool/run_ios_simulator_regression.py <simulator-uuid> [<another-uuid>]
```

需要 Xcode、已安装的模拟器运行时、Flutter 和 Python 3。脚本依次运行每台模拟器的核心及 binding 冲突场景，使用真实适配 binding，保存唯一运行标识匹配的日志和报告至 `build/ios-simulator-<时间>/`。
每台核心 11 项检查，冲突 1 项；覆盖初始化复用、320/375/768 宽度、渲染 DPR、物理尺寸及顶部安全区对齐、注入触点内外边界、适配开关、字体忽略及补偿。
指针包由 Dart 注入，不等同于原生触屏自动化；本脚本未验收旋转、软键盘、系统字号变化或插件。
模拟器使用 debug，不作为关闭断言的 profile/release AOT 真机验收或性能结论。

脚本安装的是测试入口；结束后用正常入口恢复：

```sh
(cd demo && flutter run -d <simulator-uuid> --debug --no-pub --no-resident --target=lib/main.dart)
```

当前 Xcode 要求宿主最低 iOS 15；示例已更新最低版本并启用 `FlutterSceneDelegate`，修复 iOS 27 对旧生命周期入口的启动拒绝。此配置属于示例宿主，不变更 Dart 包的平台 API。

## iOS 模拟器原生交互回归

在仓库根目录运行：

```sh
python3 tool/run_ios_native_regression.py <模拟器 UUID> [更多 UUID]
```

使用 XCUITest 原生坐标点击、拖动、系统键盘输入和设备旋转，Flutter 端使用真实适配 binding 验证逻辑坐标、命中计数、布局和键盘 inset。每台目标为 17 项检查，覆盖三种设计宽度、适配开关、边界点击、拖动、横竖屏键盘及旋转恢复。不覆盖系统字号设置变化；模拟器仅运行 debug。

报告、日志和 `.xcresult` 保存到 `build/ios-native-<时间>/`。失败后恢复竖屏并终止测试应用。测试期间不要手动操作模拟器；软键盘必须可用。测试会安装专用入口，结束后可在 demo 目录运行 `flutter run -d <UUID> --debug --no-resident --target=lib/main.dart` 恢复功能实验室。

2026-10-13 实测：iOS 26.5 的 17 项全部通过，最终脚本再次通过（`build/ios-native-20261013221255/`）；iOS 27 尚未通过。早期运行在横屏触点检查得到 `(0, 0)`；后续运行及重启后的复验在竖屏软键盘弹出检查超时，录像显示输入框已聚焦但软键盘未显示（`build/ios-native-20261013220415/`）。原因尚未确认，不能判定两台均验收完成。

## 阶梯模拟器和可重复构建

配置选择、证据和验收边界见 [设备矩阵](../doc/testing.md)。
在仓库根目录运行 `zsh tool/build_ios_simulator.sh demo`，可以生成适配本机架构的 Debug 模拟器应用，并验证 Runner 架构；不代表 iOS 真机或通用双架构构建验收。
