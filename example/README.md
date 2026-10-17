# 咖啡下单示例

一个本地交互页面，展示如何用 design_scale 按设计稿尺寸编写业务 UI。

```sh
cd example
flutter pub get
flutter run -d <device-id>
```

在 Android 设备或 iOS 模拟器运行。选择温度、调整数量、填写备注并确认订单；不调用网络或支付服务。

阅读 [lib/main.dart](lib/main.dart)：

- 在 `runApp` 前初始化 binding，设计稿为 375×812，使用 width 策略并跟随系统字号。
- 间距、圆角、字号直接使用设计稿数值，无需逐项换算。
- 静态商品组件使用 `const`，订单状态只由普通 StatefulWidget 管理。
- 用 `SafeArea`、可滚动表单和 Scaffold 的键盘避让处理可用空间。

全局缩放不等于响应式布局；横屏和短屏通过滚动访问内容，本示例不演示平板多栏布局。
Widget 测试验证订单交互；真实 binding、旋转和原生输入回归位于 [demo](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/demo/README.md)，性能对照位于 [demo 性能入口](https://github.com/lz001020/flutter-sceen-adapt/blob/HEAD/demo/PERFORMANCE.md)。这些维护者工程不随 pub 包发布。
