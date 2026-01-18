import 'package:flutter/material.dart';

import 'shared/layout_block.dart';
import 'shared/media_query_data_text.dart';

class ScaledAppDemo extends StatelessWidget {
  const ScaledAppDemo({super.key});
  @override
  Widget build(BuildContext context) {
    debugPrint("ScaledAppDemo build");
    final mediaQueryData = MediaQuery.of(context);
    return ListView(
      children: [
        const LayoutBlock(),
        MediaQueryDataText(
          mediaQueryData,
          title: "mediaQueryData:",
        ),
      ],
    );
  }
}
