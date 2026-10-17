# 性能验证

当前入口：[核心测试与验证](../doc/testing.md)说明承诺、分层与通过标准；[发布前最终复核](performance-final-20261015.md)提供页面对齐、Timeline 诊断及最新三轮数据。规则优化组 total p90 中位数：父级 5.130 / 4.963ms，局部 5.057 / 4.943ms（design_scale / ScreenUtil）。新增复杂图文父级更新中为 4.262 / 4.467ms；复杂度放大了静态子树复用差异，但两库优化组仍接近，不能宣称本库普遍领先。残余差异尚未完全归因，vivo 异常仍未关闭。

方向核查补充：2026-10-15 首批首尾有效显示方向从 rotation 0 变为 rotation 1，未逐组记录方向。本批耗时不作为性能回退或稳定库间差异的正式判据，需固定方向后复验；详见正式报告开头的补充说明。

修正页面布局参数前的 [小米 14 锁定竖屏复验](performance-conclusion-portrait-20261015.md)保留为历史批次：共 24 组更新专项和 6 组复杂信息流。信息流 total p90 中位数基本相同；该批局部优化组 design_scale 较低，父级优化组 ScreenUtil 较低。更新专项应优先参考上述最新批次，不能混合不同批次排名。

性能实验现位于独立 benchmark 工程，脚本已切换宿主。下文 2026-09-14 数据属于迁移前历史记录；当前版本已于 2026-10-13 完成小米 14 Profile 复验，2026-10-14 补测 vivo，结果如下。日志中的 `screen_adapt` 是 design_scale 的历史采样标签。

新增的公平构建对照见 [构建与业务更新专项](update-performance-design.md)：父级重建及局部价格更新，各包含 design_scale const/动态和 ScreenUtil 优化/动态四组。历史 const/inline 重建报告保留，不作为新四组对照的结论。

## 2026-10-14 vivo 真机补测

设备上报 vivo V2361A / SM7550 / Android 16。物理分辨率 1260×2800，测试沿用已有 1080×2400 override，480dpi（DPR 3）；运行期间显示采样为 60Hz。Flutter 3.35.7 / Dart 3.9.2，Profile，源码提交 `8f796cf`。未修改设备分辨率、密度或刷新率设置。与小米 14 使用同一套脚本和场景，但显示配置不同，不能直接按帧耗时评定两台设备的性能档位。

| 场景 | design_scale total p90 | flutter_screenutil total p90 | 证据与限制 |
| --- | ---: | ---: | --- |
| 常规固定行列表 | 5.879ms | 6.082ms | 各 1 轮，603 / 603 帧，>16.667ms 为 2 / 3 帧 |
| 快速滚动首次 | 11.016ms | 12.818ms | 各 3 轮中位数；第三轮两者均严重波动，不能标为稳定通过 |
| 快速滚动复验 | 12.473ms | 11.947ms | 各 3 轮中位数；design_scale 第三轮再次出现严重波动 |
| 混合信息流 | 11.036ms | 11.253ms | 各 3 轮中位数，433 / 431 帧，差异约 1.9%，表现接近 |
| const / inline 高频重建 | 9.436ms | 26.900ms | 各 1 轮，600 / 602 帧；后者 raster 明显增大，不据此归因为适配算法 |

设计稿切换与 30 次原生拖动通过脚本默认门槛：422 帧，total p90 5.830ms、p99 9.523ms，>16.667ms 为 1 帧。列表对照只记录指标，没有自动通过门槛；脚本退出成功不代表所有场景均通过性能验收。

### 快速滚动的重复波动

| 批次 / 实现 | 三轮 total p90（ms） | 三轮 >16.667ms 帧数 |
| --- | --- | --- |
| 首次 design_scale | 9.442 / 11.016 / 26.629 | 3 / 3 / 188 |
| 首次 ScreenUtil | 11.290 / 12.818 / 26.713 | 4 / 7 / 184 |
| 复验 design_scale | 11.364 / 12.473 / 26.466 | 5 / 3 / 187 |
| 复验 ScreenUtil | 10.311 / 11.947 / 12.352 | 3 / 5 / 4 |

首次第三轮 raster p90 为 18.537 / 18.316ms，复验 design_scale 第三轮为 17.985ms。重建场景 ScreenUtil raster p90 18.789ms，>16.667ms 为 594/602 帧。长帧确实存在，不能用三轮中位数掩盖。两批快速滚动中位数的优劣方向发生变化，目前不支持稳定性能领先结论。

间歇采样的 Thermal Status 为 0，复验实时 HAL 电池约 30.6°C、GPU 约 37°C，显示 modeId 4（60Hz）。HAL 还返回了较早的 cached temperatures，应与实时值区分。采样未与每个长帧同步，不能排除或证实调度、驱动、温控等原因；需要进一步用 DevTools/系统 trace 定位。此处只记录观测，不把问题归为核心缺陷或系统缺陷。

混合信息流各轮 total p90：design_scale 为 11.036 / 11.092 / 10.839ms，ScreenUtil 为 11.181 / 11.253 / 11.521ms；各轮长帧为 4/6/7 与 5/4/8。中位数 p99 为 17.965 / 17.112ms，仍有长尾，不等同于零丢帧。

原始报告、逐轮 JSON、构建日志及设备状态位于 `build/s3-performance-vivo-20261014/`，汇总为 `summary.json`，首次快速结果保留在目录根部，复验原始报告在 `fast-retry/`。本地产物不进入发布包。复现命令：

```sh
./tool/run_android_performance.sh 10CEAR1BG8000H9
./tool/compare_list_performance.sh 10CEAR1BG8000H9
./tool/compare_fast_list_performance.sh 10CEAR1BG8000H9
zsh tool/compare_mixed_feed_performance.sh 10CEAR1BG8000H9
./tool/compare_rebuild_performance.sh 10CEAR1BG8000H9
```


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
- 已有小米 14 与 vivo V2361A 列表测量；vivo 快速滚动和重建存在未定位的 raster 波动。严格高刷门槛、多指高频输入和受控跨设备性能基线尚未建立
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
