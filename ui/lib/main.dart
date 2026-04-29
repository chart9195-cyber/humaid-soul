import 'package:flutter/material.dart';
import 'screens/library.dart';
import 'screens/test_lookup.dart';

void main() {
  runApp(const HumaidSoulApp());
}

class HumaidSoulApp extends StatelessWidget {
  const HumaidSoulApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUMAID SOUL',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LibraryScreen(),
        '/test': (context) => const TestLookupScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
