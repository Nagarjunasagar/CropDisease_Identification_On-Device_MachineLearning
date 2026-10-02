import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/features/home/home_screen.dart';

void main() {
  runApp(const ProviderScope(child: CroHealApp()));
}

class CroHealApp extends StatelessWidget {
  const CroHealApp({super.key});

  static const _seed = Color(0xFF2E7D32); // leaf green

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CroHeal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
