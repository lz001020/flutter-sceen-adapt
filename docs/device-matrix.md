# 模拟器阶梯配置与验收

本轮采用屏幕配置梯度，不把模拟器型号、CPU 数量或内存设置当作低中高端真机性能。真机性能证据仅来自小米 14。同一 Android AVD 顺序覆盖多档 wm size / density；iOS 使用已有的三个设备，统一 iOS 26.5。iOS 27 后续处理。

## 配置依据

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

## 证据

- Android 360dp 三种 DPR 配置各 19 项通过：`build/interaction-20261013232355-profile/`、`build/interaction-20261013232826-profile/`、`build/interaction-20261013233204-profile/`。
- iPhone 17e 原生交互 17 项通过：`build/ios-native-20261013232355/report.json`。
- iPhone 17 Pro Max、17 Pro 原生交互各 17 项通过：`build/ios-native-20261013232922/report.json`。
- Android 411dp 首次横屏键盘采样失败保留于 `build/interaction-20261013233946-profile/`。回归脚本增加跨渲染帧的稳定等待后重新验证；原断言和超时仍保留。
- 汇总写入 `build/device-matrix-20261013.json`；本地产物不进入发布包。

复现：先用 `adb -s <emulator> shell wm size <宽>x<高>`、`wm density <dpi>` 设置，再执行 `python3 tool/run_android_interaction_regression.py <emulator> --mode profile`。结束用 `wm size reset` 和 `wm density reset` 恢复默认配置（本轮开始无 override）。iOS 执行 `python3 tool/run_ios_native_regression.py <UUID> ...`。

## 本轮结论的边界

核心自动检查与原生单指交互按矩阵验收；严格 90/120Hz 帧预算、复杂多指、任意第三方插件组合、iOS 真机不在本轮完成承诺中。已有 callback 链接/覆盖和 foreign binding 冲突回归，不等于所有插件兼容。PlatformView 补偿扩展已归档。

补测结果：411dp 与 480dp 配置各 19 项通过，报告分别为 `build/interaction-20261013234303-profile/`、`build/interaction-20261013234525-profile/`。共享脚本修改后 iPhone 17 Pro 再次 17 项通过（`build/ios-native-20261013234527/`）。Android 分辨率和密度已恢复 1080×2424 / 420dpi。最终 Android 五种配置共 95 项通过，iOS 三档共 51 项通过，另有修复后的 iOS 17 项复验。
