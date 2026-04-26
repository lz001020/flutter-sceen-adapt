import 'dart:io';

import 'package:example/app/home_page.dart';
import 'package:example/pages/input/pointer_events_page.dart';
import 'package:example/pages/platform_view/platform_view_demo_page.dart';
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
        scaffoldBackgroundColor: const Color(0xFFF7F3EA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF123458),
          surface: const Color(0xFFF7F3EA),
        ),
      ),
      home: const HomePage(),
      routes: {
        '/pointer_demo': (context) => const PointerTestPage(),
        '/platform_view_demo': (context) => const PlatformViewDemoPage(),
      },
    );
  }
}
