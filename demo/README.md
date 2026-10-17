# 功能与性能验证

在仓库的 `demo/` 目录执行，目标为 Android 设备或 iOS 模拟器：

```sh
flutter pub get
flutter run
flutter test
```

默认设计尺寸 375×667，使用 `min` 策略，字体随设计坐标缩放。
实验室默认关闭系统字号跟随（库本身默认开启），便于分别观察两种策略。
启用系统字号跟随：

```sh
flutter run -d <device-id> --dart-define=SUPPORT_SYSTEM_TEXT_SCALE=true
```

页面：窗口与横竖屏、字体与系统缩放、键盘与安全区、指针与手势。
设计稿切换为 320 / 375 / 768，保留启动时字体配置。

性能对照也在本工程中，ScreenUtil 仅作为验证工程依赖。性能场景通过独立 target 启动，入口及命令见 [性能实验](PERFORMANCE.md)。
局部反适配及原生视图示例已归档，Android 宿主不再注册测试 PlatformView。
设备回归步骤见 [TESTING.md](TESTING.md)。

本工程用于维护者功能回归与性能对照；面向使用者的业务示例见 [example](../example/README.md)。应用标识为 `dev.designscale.regression`，与使用示例分开安装。
