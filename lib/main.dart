import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs: /e/abc123 instead of /#/e/abc123 (no effect on mobile).
  if (kIsWeb) usePathUrlStrategy();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // Without this, a Firebase setup problem leaves a blank white screen.
    debugPrint('Firebase init failed: $e\n$st');
    runApp(SetupErrorApp(error: e.toString()));
    return;
  }

  runApp(const CampusVoteApp());
}

class CampusVoteApp extends StatelessWidget {
  const CampusVoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // appRouter is a top-level final, so Dart creates it lazily here —
      // after Firebase.initializeApp has finished.
      routerConfig: appRouter,
    );
  }
}

/// Shown instead of a blank screen when Firebase isn't configured correctly.
class SetupErrorApp extends StatelessWidget {
  final String error;

  const SetupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.build_circle_outlined, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Firebase is not set up yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const Text(
                'In the project folder, run:\n\n'
                '  dart pub global activate flutterfire_cli\n'
                '  flutterfire configure\n\n'
                'Select ios, android and web. Then stop the app and run '
                '`flutter run` again (a hot reload is not enough).',
              ),
              const SizedBox(height: 20),
              const Text('Error details:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              SelectableText(
                error,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}