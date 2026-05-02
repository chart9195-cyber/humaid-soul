import 'package:flutter/material.dart';
import 'screens/library.dart';
import 'screens/test_lookup.dart';
import 'screens/vocabulary.dart';
import 'screens/search_screen.dart';
import 'screens/doc_stats_screen.dart';
import 'screens/soul_pack_screen.dart';
import 'screens/voice_soul_screen.dart';
import 'services/tts_service.dart';

final TtsService globalTts = TtsService();

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
        '/vocab': (context) => const VocabScreen(),
        '/search': (context) => const SearchScreen(),
        '/soulpacks': (context) => const SoulPackScreen(),
        '/voicesoul': (context) => VoiceSoulScreen(tts: globalTts),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/docstats') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => DocStatsScreen(pdfPath: args['pdfPath'] as String),
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
