# 构建与业务更新专项

小米 14 页面参数对齐后的最终三轮与差异诊断见 [发布前最终复核](performance-final-20261015.md)，复杂信息流及对齐前专项见 [锁定竖屏历史批次](performance-conclusion-portrait-20261015.md)。下文 vivo 单轮记录仍仅作为工具验收。

目标是检验 design_scale 支持的常量尺寸写法能减少哪些构建工作，以及相对于正常优化的 flutter_screenutil 是否仍有差异。结果不预设胜负，也不能推广为所有页面更快。

## 场景与分组

三个更新专项先执行 30 次预热，再测量 180 次更新。前两个共用一个八商品卡片页面；第三个使用 12 张本地混合图文卡片。每次更新等待渲染帧完成；以相同更新工作量比较，不以固定墙钟时间比较。较慢实现可能花更长时间，不能把相同更新数误称相同吞吐率。

| 场景 | 固定工作量 | 要回答的问题 |
| --- | --- | --- |
| 父级重建 parentRebuild | 每次切换顶部标记，商品内容不变 | 不变子树的复用能省掉多少构建工作 |
| 局部更新 localUpdate | 每次只更新一张卡片价格，轮询八张卡片 | 静态详情是否随价格重复构建，以及正常状态隔离后的成本 |
| 复杂父级更新 complexParentRebuild | 每次切换复杂信息流顶部标记，12 张图文卡片不变 | 多图、富文本、标签、阴影、裁剪和图表组成的静态子树被复用后，UI/整帧差异是否放大 |
| 复杂信息流（保留原场景） | 轮播、展开与滚动，沿用原脚本 | 新 item 首次构建及完整页面的实际开销，不作为 const 收益的直接证明 |

| 实现 | 适配方式与组件策略 |
| --- | --- |
| designConst | design_scale；父级返回 const 商品/复杂信息流区域；局部更新通过 ValueListenableBuilder.child 复用静态详情 |
| designDynamic | design_scale；父级创建新商品/复杂信息流区域；局部更新重新创建静态详情 |
| screenUtilOptimized | ScreenUtil；父级返回 const 封装组件，在内部换算尺寸；局部更新同样复用 child |
| screenUtilInline | ScreenUtil；父级创建新商品/复杂信息流区域，局部更新重新创建详情；运行时换算尺寸 |

screenUtilInline 表示不复用静态子树的动态尺寸写法，组件内部将 scaleWidth/scaleText 存入局部变量，未故意为每个尺寸重复查找倍率。四组均使用同样的 ValueNotifier 状态通知，没有给任何一组更细的状态管理粒度。designConst 与 screenUtilOptimized 的复用都是标准 Flutter 优化，不能把其收益声称为 design_scale 独有能力。

复杂父级更新使用 `benchmark/assets/feed.png` 的本地图片，12 张卡片循环包含富文本、多行换行、标签 Wrap、圆角裁剪、阴影、CustomPaint 图表和可变高度内容。测量前通过 `precacheImage` 预加载图片，避免把首次解码和父级重建混为一项；因此它回答的是“已缓存图片的复杂静态树被重复构建时有多大成本”，不回答首屏图片解码、网络加载或图片上传成本。优化组预期 `complexFeed=0、complexCard=0`，动态组为 `complexFeed=180、complexCard=2160`。

ScreenUtil 的 const 静态区域显式依赖 MediaQuery.size，窗口变化后仍可重新构建和换算，不将缓存过期尺寸当作优化。专项固定窗口和适配配置；尺寸变化、原生输入等沿用已有功能回归，不在此重复作为性能场景。当前动态变量封装以测量子树复用为主，并未穷举所有业务组件组织方式。

## 观测和有效性

- `grid/card/details/price` 是四个自定义组件边界的 build 次数，非全框架 build 总数，计数器本身也有少量开销。
- `uiP90Us/uiP99Us` 来源于 FrameTiming.buildDuration，涵盖 UI 帧上的构建、布局、绘制命令生成等工作，不是单独 build() 方法的耗时。
- `rasterP90Us`、`totalP90Us/totalP99Us` 及 `over16667Us` 独立记录，分位数不可相加。16.667ms 只是固定参考预算，不能等同严格高刷验收或系统实际掉帧率。
- 排除启动及预热阶段，等待 FrameTiming 批量回调后记录测量结果；采样不足明确失败。默认排名不启用 Timeline；诊断模式另采集 Dart/Embedder/GC 事件，但没有测量分配量与内存占用，不能据此声称内存优化。
- 每轮在独立应用进程启动。默认三轮，第二轮反转场景和实现顺序；保留各轮原始日志和计数，中位数不覆盖异常轮次。
- 自动断言工作量对应的 build 次数。规则父级优化组商品区域为 0 次重建，动态组区域 180 次、详情 1440 次；复杂父级优化组信息流和卡片边界为 0 次，动态组为 180 / 2160 次；局部更新各组价格均 180 次，优化组详情 0 次、动态组 180 次。违反断言立即失败，不能把工作量没执行当成性能收益。

## 复现

```sh
cd benchmark
flutter test test/update_benchmark_test.dart
flutter analyze
cd ..
python3 tool/run_portrait_performance.py <adb-device>
# 只跑复杂图文父级更新；三轮、四种写法
python3 tool/run_portrait_performance.py <adb-device> --updates-only \
  --rounds 3 --scenarios complexParentRebuild
```

单轮 `--rounds 1` 仅用于真机工具验收，不形成稳定性能结论。输出位于 `build/update-benchmark-<时间>/`：report.json 保存配置、每轮指标与中位数；每个组合独立保存构建日志、设备日志，另保存首尾显示与温控快照。报告不进入发布包。运行会替换 benchmark APK、清空设备 logcat；不改分辨率、密度、字号或刷新率设置。`run_portrait_performance.py` 临时关闭自动旋转并固定竖屏，逐组检查有效显示方向，结束或失败时恢复原旋转设置；它同时执行三轮复杂信息流并保存方向快照。

分析应先看正确的 build 计数是否减少，再看 UI 耗时是否下降，最后看总帧和长尾是否改善。复杂场景中如果两种库都出现优化组领先各自动态组，结论是静态子树复用在高工作量页面上更容易被测出来；如果两库优化组仍接近，不能改成普遍速度优势。design_scale 的价值还需要结合常量尺寸表达及业务接入成本说明。

## 公平性与诊断

两边明确使用相同字体样式（字体族、字号、行高、字距、字重、颜色），标题高度与边框随同一倍率换算。Widget 测试在非单位倍率下核对标题、卡片文字与价格的物理矩形（误差不超过 1 个物理像素），同时核对边框宽度。这能排除已知布局差异，不能证明字形栅格化逐像素完全相同。

```sh
# 原始绘制路径的诊断，仅跑父级优化组；不用于默认性能排名
python3 tool/run_portrait_performance.py <adb-device> --updates-only --diagnostics
# 两库同时隔离静态商品区，检验重绘贡献；不会改变默认工作负载
python3 tool/run_portrait_performance.py <adb-device> --updates-only --diagnostics --isolate-paint
python3 tool/summarize_update_timeline.py build/update-benchmark-<时间>
```

诊断批次保存 180 帧原始 FrameTiming 与 VM Timeline，并单列 vsync 等待、UI 结束至 raster 开始的间隔及 BUILD/LAYOUT/PAINT 等阶段。阶段可能嵌套，不能相加为 CPU 时间；截取测量窗口时边界上的 GPU 事件数量可能少于帧数。诊断附加开销、GC 事件和线程调度均不能直接当作适配库算法成本。

## 与历史记录的关系

原 `compare_rebuild_performance.sh` 保留为历史 const/inline 压力测试，不混入新专项的汇总，也不直接用于公平优化对照。常规列表、快速滚动和复杂信息流原始数据保留，尤其保留 vivo 已复现的 raster 长帧波动。新的专项不能抹去这些未定位问题，也不能用其结果替代完整复杂页面测试。

## 首轮工具验收（2026-10-14 至 2026-10-15）

vivo V2361A 的 8 个组合均完成，全部每组 180 帧且 build 计数断言通过；报告 `build/update-benchmark-20261014235749/report.json`。benchmark 全部 4 项测试通过，静态分析无问题。以下仅为单轮工具验收，不能作为稳定性能排名或简历中的普遍优势数字。

| 场景 / 实现 | 静态详情 build 次数 | 价格 build 次数 | UI p90 |
| --- | ---: | ---: | ---: |
| 父级 / designConst | 0 | 0 | 3.973ms |
| 父级 / designDynamic | 1440 | 1440 | 5.849ms |
| 父级 / screenUtilOptimized | 0 | 0 | 4.181ms |
| 父级 / screenUtilInline | 1440 | 1440 | 6.096ms |
| 局部 / designConst | 0 | 180 | 4.225ms |
| 局部 / designDynamic | 180 | 180 | 4.290ms |
| 局部 / screenUtilOptimized | 0 | 180 | 4.275ms |
| 局部 / screenUtilInline | 180 | 180 | 4.196ms |

父级场景确认两库合理优化后均可跳过不变商品子树；局部更新确认静态详情复用有效，但本轮未显示明确帧耗时收益。局部更新的通知与隔离机制在各组相同，其收益不能归功于某一种适配库。后续正式结论仍需默认三轮或更多轮次复验、核对异常帧，并结合复杂信息流基线分析。
