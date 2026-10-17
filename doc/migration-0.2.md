# 0.2 破坏性迁移

从旧版升级到 0.2.0 时，按下表替换入口与状态操作。

| 旧方式 | 当前方式 |
| --- | --- |
| bindings.dart、screen_metrics.dart 等分入口 | 只导入 design_scale.dart |
| ScreenSizeUtils.instance | build 中 AdaptController.of(context)，回调中 read(context) |
| 直接写 designSize / adaptType / 字体字段 | setDesignSize 或 configure(config.copyWith(...)) |
| reset() | setEnabled(false)；恢复用 setEnabled(true) |
| MediaQueryData.design() / 手动 DesignSizeWidget | 删除手动包装，binding 自动发布适配 MediaQuery |
| 任意 scale / originData / data 写入 | 不再支持，设备输入由 binding 负责 |
| UnscaledZone、AdaptedPlatformView、PhysicalPixelZone | 已归档，退出当前 API 和发布包 |
| LegacyScreenUtilScope 与 legacy 路由工具 | 已归档，旧页面需自行迁移或保留在旧版本 |
| example 中的性能入口 | demo/lib/performance，脚本名称不变 |

设计尺寸为零、负数、NaN 或无穷大现在抛 ArgumentError，且不修改已有状态。
不要以 Size.zero 表示关闭适配，改用 setEnabled(false)。

归档保留在 [archive/extensions](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/archive/extensions/README.md)，包含扩展依赖的旧核心和混合测试上下文，
供查阅旧实现，不是可直接接入当前版本的独立包。

包名现为 `design_scale`，依赖键与 import 均需同步修改：`package:design_scale/design_scale.dart`。GitHub 仓库地址保持不变；归档中的旧名称只代表历史版本。
