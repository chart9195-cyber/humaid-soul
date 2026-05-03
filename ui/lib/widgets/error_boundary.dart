import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Wraps the entire app to catch all unhandled exceptions.
///
/// Flutter 3.22 catches errors via two channels:
/// 1. `FlutterError.onError` — framework & widget build errors
/// 2. `PlatformDispatcher.instance.onError` — uncaught async errors
///
/// Both are forwarded to this class, which logs to disk and surfaces
/// a gentle recovery screen instead of a cryptic stack trace.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _setupErrorHandlers();
  }

  void _setupErrorHandlers() {
    // Replace Flutter's default error reporter
    FlutterError.onError = (details) {
      // Log to console in debug mode
      FlutterError.presentError(details);
      // Log to file
      _logError(details.exceptionAsString());
      setState(() {
        _hasError = true;
        _errorMessage = details.exceptionAsString();
      });
    };

    // Catch unhandled async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Unhandled async error: $error\n$stack');
      setState(() {
        _hasError = true;
        _errorMessage = 'Unhandled async error: $error';
      });
      // Return true to mark the error as handled
      return true;
    };

    // Replace the "red screen of death" with our custom widget
    ErrorWidget.builder = (details) {
      return Material(
        color: const Color(0xFF1E1E2E),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.tealAccent, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                details.exceptionAsString(),
                style: const TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    };
  }

  Future<void> _logError(String message) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/error.log');
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString('[ $timestamp ] $message\n', mode: FileMode.append);
    } catch (_) {
      // If we can't log, at least print to console (visible via logcat)
      debugPrint('HUMAID SOUL ERROR: $message');
    }
  }

  void _restart() {
    setState(() {
      _hasError = false;
      _errorMessage = null;
    });
    // Attempt to re‑initialize the engine on restart
    // (The app's main() will be called again by the platform if we actually restart;
    //  but here we just reset the UI state so the user can try again.)
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.teal,
          scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        ),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.tealAccent, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Something went wrong',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage ?? 'An unexpected error occurred.',
                    style: const TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _restart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => exit(0),
                    child: const Text('Close App', style: TextStyle(color: Colors.white38)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}
