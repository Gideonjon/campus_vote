import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../widgets/common.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _openCode() {
    var t = _code.text.trim();
    if (t.isEmpty) return;
    final i = t.indexOf('/e/');
    if (i >= 0) t = t.substring(i + 3);
    t = t.split('/').first.split('?').first.split('#').first;
    if (t.isEmpty) return;
    context.go('/e/$t');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.how_to_vote_rounded, size: 64, color: s.primary),
            const SizedBox(height: 12),
            Text(
              AppConfig.appName,
              textAlign: TextAlign.center,
              style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidential student elections. Every ballot is encrypted on '
              'the voter\'s phone, so nobody (not even the admin) sees '
              'results until voting closes.',
              textAlign: TextAlign.center,
              style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            SectionCard(
              title: 'Running an election?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create positions and candidates, upload the list of '
                    'eligible matric numbers and share one link with voters.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/host'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Host an election'),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Got a voting link?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(
                      labelText: 'Paste the link or election code',
                    ),
                    onSubmitted: (_) => _openCode(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _openCode,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Go to election'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
