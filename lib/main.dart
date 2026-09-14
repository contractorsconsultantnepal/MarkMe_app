import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const MarkMeApp());
}

class MarkMeApp extends StatelessWidget {
  const MarkMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarkMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const MapScreen(),
    );
  }
}
