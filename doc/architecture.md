# 当前架构

产品范围：Android / iOS，单窗口，全局设计稿坐标适配。

```text
lib/design_scale.dart       显式公共导出
lib/src/core/
  adapt_config.dart        配置、策略、配置校验
  adapt_metrics.dart       不可变快照与纯计算
  adapt_controller.dart    配置、启停、设备输入去重、订阅
lib/src/binding/
  adapt_binding.dart       持有 Controller，读取设备、渲染配置与指针派发
lib/src/scope/
  adapt_scope.dart         内部根组件，借用 Controller 并发布 MediaQuery
```

设备/字体变化 → binding → Controller → Calculator → Metrics。
配置变化 → Controller → binding 更新 ViewConfiguration，同时根 Scope 更新 MediaQuery。
输入包使用同一个 Controller 快照中的 DPR 转换，避免渲染与输入读取不同全局状态。

Controller 不读取 FlutterView。内部设备输入函数位于 src，主入口不导出，也不是实例公共方法。
根 Scope 使用 InheritedNotifier 订阅；替换和移除时由框架退订，不释放借用 Controller。
binding 生命周期与应用一致。独立测试自行构造和释放 Controller。

example 展示咖啡下单业务用例；demo 承载窗口、字体、键盘和指针回归，以及独立入口的性能实验。两类验证共用原生宿主、应用标识和构建输出；性能入口不经过功能回归首页。
