# 测试与验证

核心测试检查尺寸计算、状态更新和渲染输入的一致性；设备回归检查系统交互；性能实验比较相同负载下的帧成本。

## 从源码运行

克隆 [GitHub 仓库](https://github.com/lz001020/flutter-sceen-adapt)，在根目录执行：

```sh
flutter pub get
flutter analyze
flutter test
(cd example && flutter pub get && flutter analyze && flutter test)
(cd demo && flutter pub get && flutter analyze && flutter test)
```

`example` 是咖啡下单用例，`demo` 统一承载交互回归与独立入口的性能对照。pub 包包含核心测试与 example；demo 及设备脚本需使用完整仓库。

## 核心覆盖

| 验证内容 | 测试入口（`test/` 下） |
| --- | --- |
| 策略、字体、非法指标与配置更新 | `adapt_calculator_test.dart`、`adapt_controller_test.dart` |
| 渲染 DPR、根布局、安全区与指针坐标 | `binding_runtime_test.dart`、`binding_metrics_test.dart`、`binding_controller_test.dart` |
| 初始化复用及 binding 冲突 | `legacy_binding_init_test.dart`、`binding_conflict_test.dart` |
| 指针回调的链接与覆盖行为 | `binding_callback_chain_test.dart`、`binding_callback_overwrite_test.dart` |
| 公共接口与上下文查询 | `public_api_test.dart` |

真实 binding 测试放在独立文件中，避免单例相互污染。回调覆盖测试确认的是[已知限制](known-issues.md)，接入相关插件时仍需检查实际行为。

## 设备与性能复验

以下入口均位于 GitHub 仓库：

| 任务 | 入口 |
| --- | --- |
| Android profile/release 初始化 | `zsh tool/run_binding_initialization_android.sh <device-id>` |
| Android 点击、拖动、键盘、旋转与系统字号 | `python3 tool/run_android_interaction_regression.py <device-id> --mode profile`，再执行 release |
| iOS 模拟器核心指标注入 | `python3 tool/run_ios_simulator_regression.py <simulator-uuid>` |
| iOS 模拟器原生点击、键盘与旋转 | `python3 tool/run_ios_native_regression.py <simulator-uuid>` |

运行条件、通过标准、设备设置恢复和失败处理见[移动端回归](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/demo/TESTING.md)，不要在同一设备同时运行两套测试。Widget 测试中的模拟指标与指针无法覆盖系统键盘和原生触摸。

性能对照的场景、数据与复现命令见[性能验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/performance-validation.md)。

## 设备覆盖

模拟器按屏幕尺寸与 DPR 覆盖布局和交互，不代表真机性能档位。Android 使用同一 AVD 顺序切换配置，iOS 使用三台 iOS 26.5 模拟器。


| 平台 / 档位 | 配置 | 覆盖目的 |
| --- | --- | --- |
| Android 小屏 | 720×1600 / 320dpi / DPR 2 / 360dp 宽 | 紧凑布局与低像素密度 |
| Android 常规屏 | 1080×2400 / 420dpi / DPR 2.625 / 约 411dp 宽 | 非整数 DPR 与常见逻辑宽度 |
| Android 大屏 | 1440×3200 / 480dpi / DPR 3 / 480dp 宽 | 大逻辑宽度与高像素数 |
| Android 密度补充 | 1080×2400 / 480dpi、1440×3200 / 640dpi | 同为 360dp 宽，覆盖 DPR 3 / 4 |
| iOS 紧凑档 | iPhone 17e / iOS 26.5 | 较小手机屏幕与不同安全区 |
| iOS 常规档 | iPhone 17 Pro / iOS 26.5 | 常规旗舰屏幕 |
| iOS 大屏档 | iPhone 17 Pro Max / iOS 26.5 | 大屏布局与横屏键盘 |

Android 环境为现有 Pixel_10 AVD / API 37 / arm64 / 16KB 系统镜像，模拟器实际提升至 4GB RAM，并使用软件 GLES。因此只判定交互和指标映射正确性，不比较模拟器帧性能，也未覆盖多个 Android 系统版本。所有档位都检查设计宽度 320/375/768、启停、指针内外边缘、拖动、键盘和旋转；Android 另查系统字号，iOS 原生脚本不含系统字号修改。

2026-10-13 至 2026-10-15 的迁移前宿主记录：Android 五种配置共 95 项通过，iOS 三档共 51 项通过。Android 411dp 首次横屏键盘采样失败，增加跨帧稳定等待后复验通过，保留原断言和超时。小米 14 的 profile/release 原生交互各 19 项通过；iOS 27 原生交互仍有未解决问题，见[已知限制](known-issues.md)。迁移后状态见[发布检查](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/release-checklist.md)。

Android 复验前记录现有 `wm size` 和 `wm density`，再设置目标分辨率和密度并运行上表脚本。结束后恢复原值；只有原先没有 override 时才使用 `wm size reset` 与 `wm density reset`。

## CI 与发布检查

[CI](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/.github/workflows/ci.yml)配置为在 Flutter 3.22.3、3.35.7 上执行核心、example 和 demo 的分析与测试；格式检查和 pub dry-run 使用 Flutter 3.35.7。设备交互和性能回归由维护者单独运行。

完整发布预检使用 `zsh tool/check_release.sh`，只执行 dry-run，不上传。实际完成的检查、SDK 版本和设备证据统一见[发布检查](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/release-checklist.md)。
