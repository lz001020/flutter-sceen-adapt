# 已知限制

## 接入注意

- 支持 Android / iOS 单窗口应用；Web、桌面和多窗口尚未验证。
- binding 接管 `onPointerDataPacket`。初始化前的回调会链式调用；插件若在初始化后直接覆盖该回调，会绕过适配。接入此类插件时需要检查初始化顺序及触点位置。
- PlatformView（如 WebView、地图）需要单独验证布局和触点兼容性。
- 横屏会交换设备宽高参与缩放；横向设计稿接入前需确认布局符合预期，计算方式见[使用指南](usage.md)。

## 待验证与已知异常

- 90/120Hz 严格帧预算、复杂多指与快速拖动的重采样仍需专项设备验证。
- iOS 27 模拟器原生交互曾出现横屏零坐标、软键盘未弹出，原因未确认，安排后续处理。iOS 26.5 模拟器已有通过记录。
- vivo 快速滚动曾出现重复的 raster 长帧波动，尚未定位。设备配置、逐轮数据与当前性能判断见[性能验证](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/performance-validation.md)。

验证版本与日期统一见[发布检查](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/doc/release-checklist.md)。遇到问题可按[排错指南](troubleshooting.md)收集复现信息。
