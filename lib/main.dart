// import 'dart:async';
// import 'dart:collection';
// import 'dart:io';
// import 'dart:ui' as ui;
// import 'dart:ui';
//
// import 'package:flutter/gestures.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
//
// // ==========================================================
// // 1. 核心适配工具类 (ScreenSizeUtils)
// // ==========================================================
// /// 屏幕尺寸工具类，管理设计稿尺寸、原生尺寸、适配后的尺寸和缩放比例。
// class ScreenSizeUtils {
//   /// 设计稿尺寸 (例如: 375x667)
//   late Size designSize;
//
//   /// 原始尺寸 (设备原生逻辑像素)
//   late MediaQueryData originData;
//
//   /// 适配后的尺寸
//   late MediaQueryData data;
//
//   static const defaultScale = 1.0;
//
//   double scale = defaultScale;
//
//   bool _isDesktop = false;
//
//   // 全局适配开关状态，默认开启
//   bool _isScalingEnabled = true;
//
//   bool get isScalingEnabled => _isScalingEnabled;
//
//   // 单例实现
//   factory ScreenSizeUtils() => instance;
//   static final ScreenSizeUtils instance = _getInstance();
//   static ScreenSizeUtils? _instance;
//
//   static ScreenSizeUtils _getInstance() =>
//       _instance ??= ScreenSizeUtils._internal();
//
//   ScreenSizeUtils._internal();
//
//   /// 初始化设计稿尺寸，并在初始化时调用 setup
//   setDesignSize(Size size) {
//     designSize = size;
//     if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
//       _isDesktop = true;
//     }
//     setup();
//   }
//
//   /// 【公共方法】切换全局适配状态
//   void setScalingEnabled(bool enable) {
//     _isScalingEnabled = enable;
//     // 状态更新后，外部需要触发 WidgetsBinding.instance.handleMetricsChanged()
//     // 才能使 DesignSizeWidgetsFlutterBinding 重新调用 setup()
//   }
//
//   /// 计算缩放比例和适配后的数据
//   setup() {
//     // 获取主视图 (View)
//     final view = PlatformDispatcher.instance.views.first;
//     originData = MediaQueryData.fromView(view);
//
//     // 如果禁用适配，则直接设置 scale 为 defaultScale (1.0)
//     if (!_isScalingEnabled) {
//       scale = defaultScale;
//       data = originData.design();
//       return;
//     }
//
//     // 桌面端特殊处理 (通常不进行强制缩放，除非有特定需求)
//     if (_isDesktop && scale != defaultScale) {
//       data = originData.design();
//       return;
//     }
//
//     // 根据屏幕方向和设计稿尺寸计算缩放比例
//     // 逻辑：以短边对短边，长边对长边的方式计算
//     if (view.physicalSize.width > view.physicalSize.height && !_isDesktop) {
//       // 横屏，以高度为基准适配设计稿宽度 (假设设计稿是竖屏的宽度)
//       scale = originData.size.height / designSize.width;
//     } else {
//       // 竖屏，以宽度为基准适配设计稿宽度
//       scale = originData.size.width / designSize.width;
//     }
//     data = originData.design();
//   }
// }
//
// // ==========================================================
// // 2. 适配后的 MediaQueryData 扩展
// // ==========================================================
//
// extension MediaQueryDataExtension on MediaQueryData {
//   /// 根据当前缩放比例，计算适配后的 MediaQueryData
//   MediaQueryData design() {
//     final scale = ScreenSizeUtils.instance.scale;
//     // 适配后的尺寸：逻辑尺寸缩小，DPR放大，padding/inset也缩小
//     return copyWith(
//       size: size / scale,
//       devicePixelRatio: devicePixelRatio * scale,
//       viewInsets: viewInsets / scale,
//       viewPadding: viewPadding / scale,
//       padding: padding / scale,
//     );
//   }
// }
//
// // ==========================================================
// // 3. 状态管理 Mixin (StateAble)
// // ==========================================================
//
// mixin StateAble<T extends StatefulWidget> on State<T> {
//   @override
//   void setState(VoidCallback fn) {
//     if (!mounted || !context.mounted) {
//       // 防止在 Widget 已卸载时调用 setState
//       return;
//     }
//     super.setState(fn);
//   }
// }
//
// // ==========================================================
// // 4. 适配状态的 InheritedWidget (DesignSize)
// // ==========================================================
//
// class DesignSizeWidget extends StatefulWidget {
//   final Widget child;
//
//   const DesignSizeWidget({super.key, required this.child});
//
//   @override
//   State<StatefulWidget> createState() => DesignSizeWidgetState();
// }
//
// class DesignSizeWidgetState extends State<DesignSizeWidget> with StateAble {
//
//   void _handleMetricsChanged() {
//     // 触发 Flutter 引擎的 Metrics 变更通知
//     // 这将强制 DesignSizeWidgetsFlutterBinding.createViewConfigurationFor 被重新调用
//     WidgetsBinding.instance.handleMetricsChanged();
//     // 触发本 Widget 重绘，更新下发的 MediaQuery
//     setState(() {});
//   }
//
//   /// 【暴露给外部调用】切换适配开关的方法
//   void setScalingEnabled(bool enabled) {
//     ScreenSizeUtils.instance.setScalingEnabled(enabled);
//     _handleMetricsChanged();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // 确保注入适配后的 MediaQueryData
//     final mediaQueryData = MediaQuery.of(context).design();
//     return MediaQuery(
//       data: mediaQueryData,
//       child: DesignSize(
//         data: this,
//         child: widget.child,
//       ),
//     );
//   }
// }
//
// class DesignSize extends InheritedWidget {
//   final DesignSizeWidgetState data;
//
//   const DesignSize({super.key, required this.data, required super.child});
//
//   static DesignSizeWidgetState? maybeOf(BuildContext context) {
//     return context.dependOnInheritedWidgetOfExactType<DesignSize>()?.data;
//   }
//
//   static DesignSizeWidgetState of(BuildContext context) {
//     final DesignSizeWidgetState? result = maybeOf(context);
//     assert(result != null, 'No DesignSizeWidgetState found in context');
//     return result!;
//   }
//
//   @override
//   bool updateShouldNotify(DesignSize oldWidget) => data != oldWidget.data;
// }
//
// // ==========================================================
// // 5. 自定义 Flutter Binding (DesignSizeWidgetsFlutterBinding)
// // ==========================================================
//
// class DesignSizeWidgetsFlutterBinding extends WidgetsFlutterBinding {
//   final Size designSize;
//
//   DesignSizeWidgetsFlutterBinding(this.designSize);
//
//   static WidgetsBinding ensureInitialized(Size size) {
//     ScreenSizeUtils.instance.setDesignSize(size);
//     DesignSizeWidgetsFlutterBinding(size);
//     return WidgetsBinding.instance;
//   }
//
//   /// 步骤1：实现自己的屏幕适配逻辑，修改 ViewConfiguration 以影响全局渲染
//   @override
//   ViewConfiguration createViewConfigurationFor(RenderView renderView) {
//     var view = renderView.flutterView;
//
//     // 每次创建 ViewConfiguration 时(例如窗口大小改变、旋转、手动触发)，重新计算适配数据
//     ScreenSizeUtils.instance.setup();
//
//     final BoxConstraints physicalConstraints =
//     BoxConstraints.fromViewConstraints(view.physicalConstraints);
//     final double devicePixelRatio =
//         ScreenSizeUtils.instance.data.devicePixelRatio;
//
//     return ViewConfiguration(
//       physicalConstraints: physicalConstraints,
//       logicalConstraints: physicalConstraints / devicePixelRatio,
//       devicePixelRatio: devicePixelRatio, // 关键：欺骗引擎使用新的 DPR
//     );
//   }
//
//   /// 步骤2：替换 rootWidget 中的 MediaQuery，确保顶层 widget 拿到适配后的数据
//   @override
//   Widget wrapWithDefaultView(Widget rootWidget) {
//     final view = platformDispatcher.views.first;
//
//     final mediaQueryData = ScreenSizeUtils.instance.data;
//     rootWidget =  MediaQuery(
//       data: mediaQueryData,
//       child: rootWidget,
//     );
//     // 注入 DesignSizeWidget，用于后续状态管理和开关控制
//     return View(view: view, child: DesignSizeWidget(child: rootWidget));
//   }
//
//   /// 步骤3：替换 hooks GestureBinding，处理手势坐标的缩放
//   @override
//   void initInstances() {
//     super.initInstances();
//     // 拦截手势数据包
//     PlatformDispatcher.instance.onPointerDataPacket = _handlePointerDataPacket;
//   }
//
//   @override
//   void unlocked() {
//     super.unlocked();
//     _flushPointerEventQueue();
//   }
//
//   final Queue<PointerEvent> _pendingPointerEvents = Queue<PointerEvent>();
//
//   _handlePointerDataPacket(ui.PointerDataPacket packet) {
//     try {
//       // 这里的 _devicePixelRatioForView 会返回适配后的 DPR，实现手势坐标的修正
//       _pendingPointerEvents.addAll(
//           PointerEventConverter.expand(packet.data, _devicePixelRatioForView));
//       if (!locked) {
//         _flushPointerEventQueue();
//       }
//     } catch (error, stack) {
//       FlutterError.reportError(FlutterErrorDetails(
//         exception: error,
//         stack: stack,
//         library: 'gestures library',
//         context: ErrorDescription('while handling a pointer data packet'),
//       ));
//     }
//   }
//
//   double? _devicePixelRatioForView(int viewId) {
//     if (viewId == 0) {
//       return ScreenSizeUtils.instance.data.devicePixelRatio;
//     }
//     return platformDispatcher.view(id: viewId)?.devicePixelRatio;
//   }
//
//   @override
//   cancelPointer(int pointer) {
//     if (_pendingPointerEvents.isEmpty && !locked) {
//       scheduleMicrotask(_flushPointerEventQueue);
//     }
//     _pendingPointerEvents.addFirst(PointerCancelEvent(pointer: pointer));
//   }
//
//   _flushPointerEventQueue() {
//     assert(!locked);
//
//     while (_pendingPointerEvents.isNotEmpty) {
//       handlePointerEvent(_pendingPointerEvents.removeFirst());
//     }
//   }
// }
//
// // ==========================================================
// // 6. 局部回退组件 (UnscaledZone)
// // ==========================================================
//
// /// 核心修正：局部回退到原生尺寸的隔离区
// ///
// /// 通过 LayoutBuilder 和 ConstrainedBox 修正布局约束，并注入原始 MediaQueryData。
// class UnscaledZoneV1 extends StatelessWidget {
//   const UnscaledZoneV1({
//     super.key,
//     required this.child,
//   });
//
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     final originalMediaQueryData = ScreenSizeUtils.instance.originData;
//     final scale = ScreenSizeUtils.instance.scale;
//
//     // 如果当前没有全局缩放（即处于原生模式），或者原始数据不可用，则无需回退
//     if (originalMediaQueryData == null || scale == ScreenSizeUtils.defaultScale) {
//       return child;
//     }
//
//     // 1. 注入原始的 MediaQueryData (逻辑层回退)
//     return MediaQuery(
//       data: originalMediaQueryData,
//       child: LayoutBuilder(
//         builder: (context, constraints) {
//           // 2. 修正布局约束 (渲染层回退)
//           // 计算缩小的比例 (1/scale)，以抵消 ViewConfiguration 带来的全局放大效果。
//           final double inverseScale = 1.0 / scale;
//
//           final BoxConstraints correctedConstraints = constraints.copyWith(
//             minWidth: constraints.minWidth * inverseScale,
//             maxWidth: constraints.maxWidth * inverseScale,
//             minHeight: constraints.minHeight * inverseScale,
//             maxHeight: constraints.maxHeight * inverseScale,
//           );
//
//           // 3. 使用 ConstrainedBox 传递修正后的约束给子 Widget
//           return ConstrainedBox(
//             constraints: correctedConstraints,
//             child: child,
//           );
//         },
//       ),
//     );
//   }
// }
//
// // ==========================================================
// // 6. 局部回退组件 (UnscaledZone) - 最终完善版
// // ==========================================================
//
// /// 一个Widget，其子节点将完全不受全局屏幕适配的影响。
// ///
// /// 在这个Widget内部:
// /// 1. `MediaQuery.of(context)` 返回的是设备原始的、未经修改的数据。
// /// 2. 所有的尺寸单位（如 Container的width）都将按照设备原生的逻辑像素进行渲染。
// /// 3. 字体大小也不会被缩放。
// class UnscaledZone extends StatelessWidget {
//   const UnscaledZone({
//     super.key,
//     required this.child,
//   });
//
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     // 获取原始的设备信息和当前的缩放比例
//     final originalMediaQueryData = ScreenSizeUtils.instance.originData;
//     final scale = ScreenSizeUtils.instance.scale;
//
//     // 如果当前没有进行全局缩放，则无需任何操作，直接返回child
//     if (scale == ScreenSizeUtils.defaultScale) {
//       return child;
//     }
//
//     // 计算反向缩放比例，用于抵消全局缩放
//     final double inverseScale = 1.0 / scale;
//
//     return MediaQuery(
//       // 步骤 1: 注入原始的 MediaQueryData (逻辑层回退)
//       // 这样，在UnscaledZone内部调用MediaQuery.of(context)就能获取到真实设备数据
//       data: originalMediaQueryData,
//       child: Transform.scale(
//         // 步骤 2: 进行反向缩放 (渲染层回退)
//         // 引擎会将child的尺寸放大scale倍，我们在这里将其缩小inverseScale倍，
//         // 两者相乘 (scale * inverseScale) 等于 1，从而抵消了视觉上的缩放。
//         scale: inverseScale,
//         // 步骤 3: 保证对齐方式
//         // 必须设置为左上角对齐，否则Transform.scale会默认居中对齐，导致布局位置偏移。
//         alignment: Alignment.topLeft,
//         child: child,
//       ),
//     );
//   }
// }
//
// // ==========================================================
// // 7. 演示 App 结构 (main, MyApp, HomeScreen)
// // ==========================================================
//
// void main() {
//   // 显式创建自定义 Binding 实例并设置设计稿尺寸 (375x667)
//   DesignSizeWidgetsFlutterBinding.ensureInitialized(const Size(375, 667));
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: '屏幕适配与回退演示',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const HomeScreen(),
//     );
//   }
// }
//
// /// 演示首页，包含适配开关和对比区域
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});
//
//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }
//
// class _HomeScreenState extends State<HomeScreen> {
//   // 用于驱动 Switch 控件的 UI 状态
//   late bool _isScalingEnabled;
//
//   @override
//   void initState() {
//     super.initState();
//     _isScalingEnabled = ScreenSizeUtils.instance.isScalingEnabled;
//   }
//
//   // 用于在屏幕上展示原生和适配后的尺寸信息
//   String _getScreenInfo(BuildContext context, bool isAdapted) {
//     final mq = MediaQuery.of(context);
//     final scale = ScreenSizeUtils.instance.scale;
//     final type = isAdapted ? '适配后' : '原生';
//     final size = mq.size;
//
//     return '$type尺寸: ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}\n'
//         'DPR: ${mq.devicePixelRatio.toStringAsFixed(2)} | Scale: ${scale.toStringAsFixed(3)}x';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     // 获取当前屏幕的适配后的宽度
//     final adaptedWidth = MediaQuery.of(context).size.width;
//     final adaptedHeight = MediaQuery.of(context).size.height/5;
//
//     return Scaffold(
//       appBar: AppBar(title: const Text('Binding 适配演示 (完整版)')),
//       body: Center(
//         child: SingleChildScrollView( // 防止小屏溢出
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: <Widget>[
//               // 【适配开关 UI】
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 color: Colors.grey.shade100,
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Text(
//                       '原生',
//                       style: TextStyle(
//                         fontWeight: !_isScalingEnabled ? FontWeight.bold : FontWeight.normal,
//                         color: !_isScalingEnabled ? Colors.blue : Colors.black,
//                       ),
//                     ),
//                     Switch(
//                       value: _isScalingEnabled,
//                       activeColor: Colors.blue,
//                       onChanged: (newValue) {
//                         setState(() {
//                           _isScalingEnabled = newValue;
//                         });
//
//                         // 调用 DesignSize 的方法来更新全局状态
//                         DesignSize.of(context).setScalingEnabled(newValue);
//                       },
//                     ),
//                     Text(
//                       '适配 (375)',
//                       style: TextStyle(
//                         fontWeight: _isScalingEnabled ? FontWeight.bold : FontWeight.normal,
//                         color: _isScalingEnabled ? Colors.blue : Colors.black,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               const SizedBox(height: 20),
//
//               // 1. 全局适配区域 - 宽度为当前逻辑宽度的 50%
//               Container(
//                 width: adaptedWidth * 0.5,
//                 height: adaptedHeight * 0.5, // 高度也会随全局适配比例缩放(如果适配开启)
//                 color: Colors.blue.shade200,
//                 child: Center(
//                   child: Text(
//                     '1. 全局适配区域\n(宽度: ${(adaptedWidth * 0.5).toStringAsFixed(1)})',
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(fontSize: 14),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 10),
//               Text(
//                 '逻辑宽度: ${adaptedWidth.toStringAsFixed(1)}',
//                 style: const TextStyle(fontSize: 12, color: Colors.grey),
//               ),
//               const SizedBox(height: 30),
//
//               // 2. 局部回退区域 - 宽度为原生尺寸的 50%
//               const Text(
//                 '--- UnscaledZone 局部回退 ---',
//                 style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 10),
//
//               // 关键：UnscaledZone 局部回退
//               UnscaledZone(
//                 child: InkWell(
//                   onTap: () {
//                     print("LYZ: click");
//                   },
//                   child: Container(
//                     width: 100, // 这里的宽度是基于设备的原始逻辑尺寸
//                     height: 100,
//                     color: Colors.green.shade200,
//                     child: Center(
//                       child: Text(
//                         '2. 局部回退区域\n(原生宽度: ${(100).toStringAsFixed(1)})',
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(fontSize: 14),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 30),
//
//               // 3. 屏幕信息展示（用于对比）
//               Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   children: [
//                     Text(_getScreenInfo(context, true), style: const TextStyle(fontSize: 13)),
//                     const SizedBox(height: 10),
//                     // 在 UnscaledZone 中获取信息
//                     UnscaledZone(
//                       child: Builder(
//                         builder: (innerContext) {
//                           return Text(
//                             _getScreenInfo(innerContext, false),
//                             style: const TextStyle(fontSize: 13, color: Colors.grey),
//                           );
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // ==========================================================
// // 8. 物理像素精准控制组件 (PhysicalPixelZone)
// // ==========================================================
//
// /// 一个特殊的Widget，其子节点的尺寸单位将直接对应屏幕的物理像素。
// ///
// /// 在这个Widget内部:
// /// 1. `Container(width: 1)` 将会渲染为1物理像素宽。
// /// 2. 字体大小也会被相应缩放，`TextStyle(fontSize: 16)` 渲染出来的
// ///    文字高度大约是16个物理像素高。
// ///
// /// 这对于绘制精确的1px边框线、显示不允许缩放的图片（如二维码）等场景非常有用。
// class PhysicalPixelZone extends StatelessWidget {
//   const PhysicalPixelZone({
//     super.key,
//     required this.child,
//   });
//
//   final Widget child;
//
//   @override
//   Widget build(BuildContext context) {
//     // 1. 获取当前上下文的MediaQueryData
//     //    这里使用MediaQuery.of(context)而不是全局的原始数据，
//     //    是为了让PhysicalPixelZone可以嵌套在UnscaledZone或适配区内都能正常工作。
//     final mediaQueryData = MediaQuery.of(context);
//
//     // 2. 获取设备像素比 (DPR)
//     final dpr = mediaQueryData.devicePixelRatio;
//
//     // 如果dpr为1，说明1个逻辑像素正好等于1个物理像素，无需缩放。
//     if (dpr == 1.0) {
//       return child;
//     }
//
//     // 3. 计算缩放比例，即DPR的倒数
//     final double scale = 1.0 / dpr;
//
//     return Transform.scale(
//       // 4. 进行缩放
//       //    我们将子节点的所有逻辑尺寸都缩小dpr倍。
//       //    当渲染引擎将这些逻辑尺寸转换为物理像素时 (乘以dpr)，
//       //    (逻辑尺寸 * scale) * dpr = (逻辑尺寸 / dpr) * dpr = 逻辑尺寸
//       //    这就实现了 1个逻辑单位 = 1个物理像素 的效果。
//       scale: scale,
//       // 5. 保证对齐方式为左上角，防止布局偏移
//       alignment: Alignment.topLeft,
//       child: child,
//     );
//   }
// }
