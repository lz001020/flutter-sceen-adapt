# 性能验证

## 自动化微基准

运行：

```bash
flutter test -r expanded test/performance_test.dart
```

测试会重复执行 `MediaQueryData.design()` 10000 次，输出总耗时和单次平均耗时。该测试只检查结果是否有限并记录基线，不设置固定毫秒阈值，避免不同 CPU、模拟器和 CI 机器产生误报。

## 真机帧性能

使用 Profile 模式运行示例：

```bash
flutter run --profile -d emulator-5554
```

在示例中连续进入指针页面并拖动 10 秒，然后使用 Flutter DevTools 的 Performance 面板观察：

- UI / Raster 帧耗时是否持续低于设备刷新周期
- 是否出现连续丢帧或 Raster 峰值
- 旋转、键盘弹出和设计稿切换时是否出现异常长帧

也可以导出 Android 图形统计：

```bash
adb -s emulator-5554 shell dumpsys gfxinfo com.example.example reset
adb -s emulator-5554 shell dumpsys gfxinfo com.example.example
```

重点记录 `Janky frames`、`50th/90th/95th/99th percentile` 和总帧数。每次比较前先 reset，并在相同设备、分辨率、刷新率和操作路径下采样。

## 当前范围

- 微基准覆盖 MediaQuery 指标适配的热路径
- 尚未对 90/120Hz 真机、复杂列表和多指高频输入建立固定基线
- 性能数据只能在相同设备和 Profile 模式下横向比较，不能用 Debug 模式结论代表发布性能
