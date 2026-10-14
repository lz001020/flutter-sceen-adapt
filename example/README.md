# 核心功能实验室

```sh
flutter pub get
flutter run
flutter test
```

页面：窗口与横竖屏、字体与系统缩放、键盘与安全区、指针与手势。
设计稿切换为 320 / 375 / 768，保留启动时字体配置。

example 只依赖核心包；ScreenUtil 对照和性能路由已迁入 ../benchmark。
局部反适配及原生视图示例已归档，Android 宿主不再注册测试 PlatformView。
设备回归步骤见 [TESTING.md](TESTING.md)。
