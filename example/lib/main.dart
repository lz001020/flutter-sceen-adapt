import 'dart:io';

import 'package:example/demo3/pointer_test_page.dart';
import 'package:example/page1.dart';
import 'package:example/page2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_adapt/screen_adapt.dart';


void main() {
  DesignSizeWidgetsFlutterBinding.ensureInitialized(
    const Size(375, 667),
    scaleText: true,
    supportSystemTextScale: false,
  );
  if (Platform.isAndroid) {
    SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: false),
      ),
      initialRoute: "/page1",
      routes: {
        "/page1": (context) => const Page1(),
        "/page2": (context) => const Page2(), "/demo3": (context) => const PointerTestPage()
      },
    );
  }
}
