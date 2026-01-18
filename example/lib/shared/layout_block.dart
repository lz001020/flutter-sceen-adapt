import "package:flutter/material.dart";
import "package:screen_adapt/screen_adapt.dart";

class LayoutBlock extends StatelessWidget {
  const LayoutBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(alignment: Alignment.center, color: Colors.red, child: const Text('1/3屏宽'),),
              ),
            ),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(alignment: Alignment.center, color: Colors.yellow, child: const Text('1/3屏宽'),),
              ),
            ),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(alignment: Alignment.center, color: Colors.green, child: const Text('1/3屏宽'),),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            color: Colors.purple.shade50,
            width: 250 ,
            height: 250,
            child: Center(child: Text("250 x 250")),
          ),
        ),
        // --- START: 新增的代码 ---
        // 为了视觉上分开，我加了一个10像素的间距
        const SizedBox(height: 10),

        // 这是新增的另一个 250x250 未适配容器
        MediaQuery(
          data: ScreenSizeUtils.instance.originData,
          child: UnscaledZone(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                // 修改了颜色以作区分
                width: 250,
                height: 250,
                color: Colors.blue.shade50,
                child: Center(child: Text("又一个 250 x 250")),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
