import 'package:example/scale_the_app.dart';
import 'package:flutter/material.dart';
import 'package:screen_adapt/widgets/design_size_widget.dart';


class Page2 extends StatefulWidget {
  const Page2({super.key});

  @override
  State<Page2> createState() => _Page2State();
}

class _Page2State extends State<Page2> {
  bool switchMediaQueryData = true;

  FocusNode keyboardFocusNode = FocusNode();
  TextEditingController controller = TextEditingController(text: "");

  @override
  Widget build(BuildContext context) {
    debugPrint("page2 build");
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          "Page2",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Switch(
              value: switchMediaQueryData,
              onChanged: (bool value) {
                if (value) {
                  DesignSize.of(context).setDesignSize(const Size(375, 667));
                } else {
                  DesignSize.of(context).reset();
                }

                setState(() {
                  switchMediaQueryData = value;
                });
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Offstage(
            child: TextField(
              focusNode: keyboardFocusNode,
              controller: controller,
            ),
          ),
          const Expanded(child: ScaledAppDemo())
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (keyboardFocusNode.hasFocus) {
            keyboardFocusNode.unfocus();
          } else {
            keyboardFocusNode.requestFocus();
          }
          // Navigator.of(context).pushNamed("/home2");
        },
        child: const Icon(Icons.keyboard),
      ),
    );
  }
}
