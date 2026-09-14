# 性能验证

## 自动化微基准

运行：

```bash
flutter test -r expanded test/performance_test.dart
```

测试会重复执行 `MediaQueryData.design()` 10000 次，输出总耗时和单次平均耗时。该测试只检查结果是否有限并记录基线，不设置固定毫秒阈值，避免不同 CPU、模拟器和 CI 机器产生误报。

## 真机帧性能

Android 可执行一条命令完成 Profile 构建、安装、启动、30 次真实 swipe、设计尺寸轮换和报告采集：

```bash
./tool/run_android_performance.sh emulator-5554
```

重复测试且 Profile APK 未变化时，可以跳过构建：

```bash
PERF_SKIP_BUILD=1 ./tool/run_android_performance.sh emulator-5554
```

报告生成在：

- `build/performance/<device-id>_flutter_frames.txt`
- `build/performance/<device-id>_android_gfxinfo.txt`

隐藏路由 `/performance_demo` 会在每次手势结束后轮换 320、375、768 设计尺寸，并每 60 帧输出一次 Flutter `FrameTiming` 的 p50、p90、p99 和超过 16.667ms 的帧数。
如果首次启动弹窗阻止手势，或未采集到足够帧数，脚本会以非零状态退出，不生成“通过”结论。

默认通过条件是累计 p90 不超过 16.667ms，且超过 16.667ms 的帧数不超过 5%。阈值可用于不同刷新率或 CI 基线：

```bash
PERF_MAX_P90_US=8333 PERF_MAX_JANK_PERCENT=3 \
  ./tool/run_android_performance.sh emulator-5554
```

某些 Android 版本的 `gfxinfo` 不统计 Flutter `SurfaceView`，会显示总帧数为 0 和无意义的 4950ms 分位数。脚本会自动忽略该结果，以应用内 `FrameTiming` 为准。

需要进一步定位长帧时，再使用 Flutter DevTools 的 Performance 面板观察：

- UI / Raster 帧耗时是否持续低于设备刷新周期
- 是否出现连续丢帧或 Raster 峰值
- 旋转、键盘弹出和设计稿切换时是否出现异常长帧

脚本内部等价执行以下 Android 图形统计命令：

```bash
adb -s emulator-5554 shell dumpsys gfxinfo com.example.example reset
adb -s emulator-5554 shell dumpsys gfxinfo com.example.example
```

重点记录 `Janky frames`、`50th/90th/95th/99th percentile` 和总帧数。每次比较前先 reset，并在相同设备、分辨率、刷新率和操作路径下采样。

## 当前范围

- 微基准覆盖 MediaQuery 指标适配的热路径
- 尚未对 90/120Hz 真机、复杂列表和多指高频输入建立固定基线
- 性能数据只能在相同设备和 Profile 模式下横向比较，不能用 Debug 模式结论代表发布性能

## 复杂列表对比

在同一台设备上自动构建并比较 `screen_adapt` 与 `flutter_screenutil`：

```bash
./tool/compare_list_performance.sh 8e3b2e1c
```

两个独立入口分别使用自定义 Binding 和标准 Binding，避免两套适配逻辑互相影响。两边统一按设计稿宽度缩放，渲染相同的 1000 项复杂列表；每项包含固定高度布局、图标、两段文本、三个状态标签、边框与圆角。脚本分别执行 30 次纵向滑动，输出累计帧数、p90、p99 和超过 16.667ms 的帧数。

报告保存在 `build/performance/<device-id>_<engine>_complex_list.txt`。对比必须使用同一设备、刷新率、温度和 Profile 模式；单次差异不能作为稳定结论，建议至少运行三轮并取中位数。

## const 高频重建对比

复杂列表滚动主要包含新 item 的首次构建、布局和绘制，无法充分体现 const 子树在父级重建时的短路优势。使用以下命令运行逐帧重建压力测试：

```bash
./tool/compare_rebuild_performance.sh 8e3b2e1c
```

两边使用相同的 1000 项复杂列表。测试持续 12 秒：

- `screen_adapt` 返回同一个 const 列表子树，尺寸直接使用设计稿常量
- `flutter_screenutil` 模拟业务内联 `.w/.sp`，父级重建时重新创建动态尺寸子树
- 分别记录 build、raster 和 total 的 p90

2026-09-14 在真机 `23127PN0CC` 上的首轮结果：

| 实现 | 帧数 | build p90 | raster p90 | total p90 |
| --- | ---: | ---: | ---: | ---: |
| screen_adapt const | 1324 | 0.903ms | 2.845ms | 5.361ms |
| flutter_screenutil inline | 1332 | 3.288ms | 3.390ms | 7.979ms |

该轮中 screen_adapt 的 build p90 约低 72.5%。这个结果说明全局逻辑坐标适配允许更深地使用原生 const 表达式；它不表示 ScreenUtil 组件绝对不能 const。将 `.w/.sp` 封装进 const `StatelessWidget` 后，外层组件也能利用相同实例短路，应作为另一种优化后的实现单独比较。
