import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart'; // 引入MediaQueryData, Size等

/// 定义屏幕适配的基准。
enum ScreenAdaptType {
  /// 基于屏幕宽度进行适配。
  width,

  /// 基于屏幕高度进行适配。
  height,

  /// 基于屏幕宽度和高度中的最小值进行适配。
  min,
}

/// 用于管理屏幕适配参数的核心工具类。
class ScreenSizeUtils {
  /// 设计稿尺寸
  late Size designSize;

  /// 屏幕适配基准类型
  ScreenAdaptType adaptType = ScreenAdaptType.width;

  /// 原始的MediaQueryData
  late MediaQueryData originData;

  /// 适配后的MediaQueryData
  late MediaQueryData data;

  /// 默认缩放比例
  static const defaultScale = 1.0;

  /// 当前缩放比例
  double scale = defaultScale;

  /// 是否为桌面平台
  bool _isDesktop = false;

  // 单例实现
  factory ScreenSizeUtils() => instance;
  static final ScreenSizeUtils instance = _getInstance();
  static ScreenSizeUtils? _instance;

  static ScreenSizeUtils _getInstance() =>
      _instance ??= ScreenSizeUtils._internal();

  ScreenSizeUtils._internal();

  /// 设置设计稿尺寸以及可选的适配类型。
  void setDesignSize(Size size, {ScreenAdaptType type = ScreenAdaptType.width}) {
    designSize = size;
    adaptType = type;
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      _isDesktop = true;
    }
    setup();
  }

  /// 将适配重置为原始的屏幕指标。
  reset() {
    final view = PlatformDispatcher.instance.views.first;
    originData = MediaQueryData.fromView(view);
    designSize = originData.size; // 将设计稿尺寸重置为当前屏幕尺寸
    if (designSize.width > designSize.height && !_isDesktop) {
      // 横竖屏切换
      designSize = designSize.flipped;
    }
    scale = defaultScale;
  }

  /// 根据所选的 [adaptType] 设置屏幕适配参数。
  setup() {
    final view = PlatformDispatcher.instance.views.first;
    originData = MediaQueryData.fromView(view);

    if (_isDesktop && scale != defaultScale) {
      data = originData.design(); // 对于桌面端，如果 scale 是自定义的，则应用它
      return;
    }

    double currentWidth = originData.size.width;
    double currentHeight = originData.size.height;

    // 处理非桌面设备的横屏情况
    if (view.physicalSize.width > view.physicalSize.height && !_isDesktop) {
      // 在横屏模式下，如果按宽度或最小值适配，则翻转参考尺寸
      currentWidth = originData.size.height; // 使用高度作为横屏适配的有效宽度
      currentHeight = originData.size.width; // 使用宽度作为有效高度
    }

    switch (adaptType) {
      case ScreenAdaptType.width:
        scale = currentWidth / designSize.width;
        break;
      case ScreenAdaptType.height:
        scale = currentHeight / designSize.height;
        break;
      case ScreenAdaptType.min:
        scale = (currentWidth < currentHeight ? currentWidth : currentHeight) / (designSize.width < designSize.height ? designSize.width : designSize.height);
        break;
    }

    data = originData.design();
  }
}

extension MediaQueryDataExtension on MediaQueryData {
  /// 基于[ScreenSizeUtils]中的缩放比例[scale]来适配当前的[MediaQueryData]
  MediaQueryData design() {
    final scale = ScreenSizeUtils.instance.scale;
    return copyWith(
      size: size / scale,
      devicePixelRatio: devicePixelRatio * scale,
      viewInsets: viewInsets / scale,
      viewPadding: viewPadding / scale,
      padding: padding / scale,
    );
  }
}
