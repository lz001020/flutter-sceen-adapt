# 性能验证

性能实验现位于独立 benchmark 工程，脚本已切换宿主。下文 2026-09-14 数据属于迁移前历史记录；当前版本已于 2026-10-13 完成小米 14 Profile 复验，结果如下。


## 2026-10-13 当前版本复验

设备：小米 14（23127PN0CC / Android 16 / 1200×2670），显示模式 120Hz；Flutter 3.35.7，Profile 模式。仅支持同机、同场景比较，模拟器用于配置和交互兼容性，不代表低、中、高端真机性能。梯度模拟器兼容性矩阵已通过，见 [设备矩阵](device-matrix.md)。

| 场景 | screen_adapt total p90 | flutter_screenutil total p90 | 范围 |
| --- | ---: | ---: | --- |
| 常规固定行列表 | 4.253ms | 4.382ms | 各 1 轮，帧数 1205 / 1329，不据此判断胜负 |
| 快速滚动 | 5.582ms | 5.567ms | 各 3 轮中位数，帧数均 394，基本相当 |
| 混合信息流 | 5.083ms | 5.744ms | 各 3 轮中位数，帧数均 815 |
| const / inline 高频重建 | 6.055ms | 6.632ms | 各 1 轮；比较两种子树构建策略，不代表库的普遍优劣 |

设计稿切换与指针场景通过默认门槛：726 帧，p90 4.462ms，p99 7.017ms，超过 16.667ms 为 2 帧。此门槛是 60Hz 预算，不等同于已通过严格 120Hz 验收。纯计算微基准 10000 次共 7296μs，只作本地计算参考。

### 新增混合信息流

共享 1000 项数据与页面结构：顶部横向轮播、图文/商品/图表/评论四类变高卡片、富文本换行、Wrap 标签、图片裁剪、阴影及 AnimatedSize 展开动画。两入口分别使用全局坐标适配和 ScreenUtil 尺寸换算。

```sh
zsh tool/compare_mixed_feed_performance.sh 8e3b2e1c
```

每轮执行 2 次横向滚动、5 次展开/收起、50 次纵向滚动（每次 120ms、视口高度的 80%），共 3 轮，交替运行顺序。程序滚动用于统一工作量，不替代原生手势回归。图片是同一张本地固定素材，排除网络差异；不覆盖大量不同图片解码、缓存淘汰、视频或插件。

| 三轮中位数 | screen_adapt | flutter_screenutil |
| --- | ---: | ---: |
| 帧数 | 815 | 815 |
| build p90 | 1.491ms | 1.657ms |
| raster p90 | 2.499ms | 2.845ms |
| total p90 | 5.083ms | 5.744ms |
| total p99 | 9.703ms | 10.753ms |
| >16.667ms 帧数 | 2 | 2 |

各轮 total p90：screen_adapt 为 5.716 / 5.083 / 4.827ms；ScreenUtil 为 5.744 / 5.811 / 4.807ms。中位数差约 11.5%，但首轮和第三轮十分接近，存在轮次波动，不能推导稳定或普遍领先。两者在此设备、此场景均表现良好；帧数相当也不保证每一帧呈现内容完全相同。

原始报告快照：`build/s3-performance-20261013/`；新场景汇总：`mixed-feed-summary.json`（本地产物，不进入发布包）。布局测试覆盖 320/375/768 宽度下四类卡片与展开行为。

## 自动化微基准

运行：

```bash
cd benchmark
flutter test -r expanded test/metrics_benchmark_test.dart
```

测试会重复执行 内部纯计算 `AdaptCalculator.adaptMediaQuery()` 10000 次，输出总耗时和单次平均耗时。该测试只检查结果是否有限并记录基线，不设置固定毫秒阈值，避免不同 CPU、模拟器和 CI 机器产生误报。

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
adb -s emulator-5554 shell dumpsys gfxinfo dev.screenadapt.benchmark reset
adb -s emulator-5554 shell dumpsys gfxinfo dev.screenadapt.benchmark
```

重点记录 `Janky frames`、`50th/90th/95th/99th percentile` 和总帧数。每次比较前先 reset，并在相同设备、分辨率、刷新率和操作路径下采样。

## 当前范围

- 微基准覆盖 MediaQuery 指标适配的热路径
- 已有小米 14 列表场景测量；严格高刷门槛、多指高频输入和跨设备性能基线尚未建立
- 性能数据只能在相同设备和 Profile 模式下横向比较，不能用 Debug 模式结论代表发布性能

## 复杂列表对比

在同一台设备上自动构建并比较 `screen_adapt` 与 `flutter_screenutil`：

```bash
./tool/compare_list_performance.sh 8e3b2e1c
```

两个独立入口分别使用自定义 Binding 和标准 Binding，避免两套适配逻辑互相影响。两边统一按设计稿宽度缩放，渲染相同的 1000 项复杂列表；每项包含固定高度布局、图标、两段文本、三个状态标签、边框与圆角。脚本分别执行 30 次纵向滑动，输出累计帧数、p90、p99 和超过 16.667ms 的帧数。

报告保存在 `build/performance/<device-id>_<engine>_complex_list.txt`。对比必须使用同一设备、刷新率、温度和 Profile 模式；单次差异不能作为稳定结论，建议至少运行三轮并取中位数。

### 快速滚动

普通对照使用 30 次 250ms ADB 滑动。快速列表对照由应用内部执行 50 次 60ms 线性滚动，每次移动视口高度的 80%，避免 ADB 手势调度造成两种实现的工作量不一致：

```bash
./tool/compare_fast_list_performance.sh 8e3b2e1c
```

脚本默认执行三轮并交叉运行顺序：第 1、3 轮先运行 `screen_adapt`，第 2 轮先运行 `flutter_screenutil`，最后输出各指标的中位数。每轮报告保存在 `build/performance/<device-id>_<engine>_fast_complex_list_round<N>.txt`。快速滚动与 const 高频重建回答的是不同问题，两者结果应分别记录。

2026-09-14 在真机 `23127PN0CC`（Android 16、1200x2670）上的三轮中位数：

| 实现 | 帧数 | build p90 | raster p90 | total p90 | p99 | >16.667ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| screen_adapt | 393 | 2.173ms | 2.740ms | 5.706ms | 10.610ms | 2 |
| flutter_screenutil | 393 | 2.165ms | 2.663ms | 5.990ms | 10.454ms | 2 |

两边帧数中位数一致，工作量可以直接比较。该组数据中 `screen_adapt` 的 total p90 约低 4.7%，build p90、raster p90、p99 和卡顿帧处于同一量级。快速滚动主要触发新 item 的首次 mount/build，const 无法跳过首次构建，所以不应期待出现高频重建测试中的 const 优势。该结论仅代表当前设备和测试场景，不等同于所有页面上的总体性能结论。

## const 高频重建对比

复杂列表滚动主要包含新 item 的首次构建、布局和绘制，无法充分体现 const 子树在父级重建时的短路优势。使用以下命令运行逐帧重建压力测试：

```bash
./tool/compare_rebuild_performance.sh 8e3b2e1c
```

两边使用相同的 1000 项复杂列表。测试持续 12 秒：

- `screen_adapt` 返回同一个 const 列表子树，尺寸直接使用设计稿常量
- `flutter_screenutil` 模拟业务内联 `.w/.sp`，父级重建时重新创建动态尺寸子树
- 页面顶部的红色标记持续左右移动，用于肉眼确认逐帧重建正在运行
- 分别记录 build、raster 和 total 的 p90

2026-09-14 在真机 `23127PN0CC` 上的首轮结果：

| 实现 | 帧数 | build p90 | raster p90 | total p90 |
| --- | ---: | ---: | ---: | ---: |
| screen_adapt const | 1324 | 0.903ms | 2.845ms | 5.361ms |
| flutter_screenutil inline | 1332 | 3.288ms | 3.390ms | 7.979ms |

该轮中 screen_adapt 的 build p90 约低 72.5%。这个结果说明全局逻辑坐标适配允许更深地使用原生 const 表达式；它不表示 ScreenUtil 组件绝对不能 const。将 `.w/.sp` 封装进 const `StatelessWidget` 后，外层组件也能利用相同实例短路，应作为另一种优化后的实现单独比较。
