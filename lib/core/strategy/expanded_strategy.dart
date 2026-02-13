import 'dart:ui';

import 'package:flutter/cupertino.dart' as ui;
import 'package:flutter/material.dart';
import 'package:screen_adapt/core/screen_size_utils.dart';
import 'package:screen_adapt/core/strategy/adaptation_config.dart';
import 'package:screen_adapt/core/strategy/adaptation_strategy.dart';

class ExpandedStrategy extends ScreenAdaptStrategy {
  @override
  bool match(Size physicalSize, double originDpr) {
    if (physicalSize.height == 0) return false;
    // 当屏幕宽高比大于 0.8 时（折叠屏展开或平板），激活此策略
    return (physicalSize.width / physicalSize.height) > 0.8;
  }

  @override
  AdaptationConfig compute(Size physicalSize, Size designSize) {
    // 高度填充：以设计稿高度为准缩放
    final dpr = physicalSize.height / designSize.height;
    final logicWidth = physicalSize.width / dpr;
    // 计算居中偏移
    final dx = (logicWidth - designSize.width) / 2.0;

    return AdaptationConfig(
      dpr: dpr,
      gestureOffset: Offset(dx, 0),
      isExpanded: true,
    );
  }

  @override
  Widget wrapRootWidget(
      Widget rootWidget, AdaptationConfig config, ScreenSizeUtils utils) {
    return ui.View(
      view: PlatformDispatcher.instance.implicitView!,
      child: ValueListenableBuilder<Offset>(
        valueListenable: utils.dragOffsetVn,
        builder: (context, dragOffset, _) {
          final totalOffset = config.gestureOffset + dragOffset;

          return Stack(
            textDirection: TextDirection.ltr,
            children: [
              // 1. 最底层：背景图层
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    image: utils.foldBackgroundImage != null
                        ? DecorationImage(
                            image: AssetImage(utils.foldBackgroundImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: Colors.black, // 无图时的兜底色
                  ),
                  // 添加毛玻璃和遮罩，防止背景干扰 App 内容
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                          color: Colors.black.withAlpha((0.4 * 255).ceil())),
                    ),
                  ),
                ),
              ),

              // 2. 中间层：主 App 窗口
              Positioned(
                left: totalOffset.dx,
                top: totalOffset.dy,
                width: utils.designSize.width,
                height: utils.designSize.height,
                child: Container(
                  // 窗口外阴影，增强悬浮感
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.6 * 255).ceil()),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16), // 窗口圆角
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // 顶部拖动手柄区域
                        _buildDragHandle(utils),
                        // 真正的业务页面
                        Expanded(child: rootWidget),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(ScreenSizeUtils utils) {
    return GestureDetector(
      onPanUpdate: (details) => utils.updateDrag(details.delta),
      child: Container(
        height: 30,
        width: double.infinity,
        color: const Color(0xFF2C2C2E), // 模拟 iOS 深色标题栏
        child: Center(
          child: Container(
            width: 45,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
      ),
    );
  }
}
