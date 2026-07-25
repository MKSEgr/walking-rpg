import 'package:flutter/material.dart';
import 'package:walking_rpg_mobile/features/home/presentation/home_screen.dart';

class WalkingRpgApp extends StatelessWidget {
  const WalkingRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walking RPG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF496D61),
      ),
      home: const HomeScreen(),
    );
  }
}
