# 0.2 破坏性迁移

0.x 阶段使用次版本标识破坏性变更，本轮将版本从 0.1.0 调整为 0.2.0（待发布）。
未来进入 1.x 后，破坏性变更升级主版本。

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
| example 中的性能入口 | benchmark/lib/performance，脚本名称不变 |

设计尺寸为零、负数、NaN 或无穷大现在抛 ArgumentError，且不修改已有状态。
不要以 Size.zero 表示关闭适配，改用 setEnabled(false)。

归档保留在 [archive/extensions](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/archive/extensions/README.md)，包含扩展依赖的旧核心和混合测试上下文，
不是独立可运行包，也不能通过改 import 获得当前版本兼容承诺。
业务借用 Controller 不负责 dispose；创建独立 Controller 时由创建方 dispose。

包名现为 `design_scale`，依赖键与 import 均需同步修改：`package:design_scale/design_scale.dart`。GitHub 仓库地址保持不变；归档中的旧名称只代表历史版本。
