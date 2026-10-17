# 已知限制

- 只承诺 Android / iOS 单窗口核心链路，Web、桌面、多 view 不在范围内。
- binding 接管 onPointerDataPacket；初始化前的回调会链式调用，初始化后插件直接覆盖会绕过适配。已有两项回归测试确认此行为，接入插件时必须检查初始化顺序。
- 90/120Hz 真机上的重采样、复杂多指和快速拖动仍需设备验证。
- 不承诺比 ScreenUtil 普遍更快。小米竖屏专项曾观察到父级更新耗时差异，vivo 快速滚动出现过未定位的 raster 长帧；采样完成不代表跨设备稳定性能通过。最新证据见 [性能验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/performance-validation.md)。
- 横屏会交换设备宽高参与缩放；设计稿本身为横屏时需验证业务预期。
- 不提供任意 PlatformView / WebView / 地图兼容承诺；补偿扩展已归档。
- Android profile/release 自动交互与 iOS 26.5 模拟器原生交互已通过，见 [发布清单](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/docs/release-checklist.md)。
- iOS 27 原生交互问题后续处理，不阻塞本轮核心收敛：出现过横屏零坐标及软键盘未弹出，原因尚未确认，暂不声明该系统原生交互验收通过。失败日志和报告保留。
- 当前 Xcode 的 lipo 对多架构 verify_arch 命令报输入文件数量错误，导致 Flutter 3.35.7 通用模拟器构建失败。在 GitHub 仓库中使用 `zsh tool/build_ios_simulator.sh example` 或 `benchmark` 构建本机架构；两工程 arm64 构建已通过，通用双架构问题仍属于工具链限制。

旧版本局部反适配的占位、命中和父约束记录只保存在归档，不是当前 API 限制。
