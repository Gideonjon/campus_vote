import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth_screen.dart';
import 'screens/host/create_election_screen.dart';
import 'screens/host/election_dashboard_screen.dart';
import 'screens/host/host_home_screen.dart';
import 'screens/host/key_backup_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/results_screen.dart';
import 'screens/voter/ballot_screen.dart';
import 'screens/voter/receipt_screen.dart';
import 'screens/voter/voter_entry_screen.dart';
import 'services/ballot_crypto.dart';
import 'widgets/common.dart';

/// Re-runs router redirects whenever the user signs in or out.
class _AuthRefresh extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  _AuthRefresh(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _AuthRefresh(FirebaseAuth.instance.authStateChanges()),
  redirect: (context, state) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final loc = state.matchedLocation;
    if (loc.startsWith('/host') && !signedIn) {
      return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
    }
    if (loc == '/login' && signedIn) {
      return state.uri.queryParameters['from'] ?? '/host';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
    GoRoute(path: '/login', builder: (_, __) => const AuthScreen()),

    // ---------------- host
    GoRoute(path: '/host', builder: (_, __) => const HostHomeScreen()),
    GoRoute(path: '/host/new', builder: (_, __) => const CreateElectionScreen()),
    GoRoute(
      path: '/host/e/:id',
      builder: (_, s) => ElectionDashboardScreen(electionId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/host/e/:id/keys',
      builder: (_, s) => KeyBackupScreen(
        electionId: s.pathParameters['id']!,
        keys: s.extra is ElectionKeys ? s.extra as ElectionKeys : null,
      ),
    ),

    // ---------------- voter (shared link)
    GoRoute(
      path: '/e/:id',
      builder: (_, s) => VoterEntryScreen(electionId: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/e/:id/ballot',
      builder: (_, s) => BallotScreen(
        electionId: s.pathParameters['id']!,
        matric: s.extra is String ? s.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/e/:id/receipt',
      builder: (_, s) => ReceiptScreen(
        electionId: s.pathParameters['id']!,
        receipt: s.extra is String ? s.extra as String : null,
      ),
    ),
    GoRoute(
      path: '/e/:id/results',
      builder: (_, s) => ResultsScreen(electionId: s.pathParameters['id']!),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: MessageView(
      icon: Icons.search_off,
      title: 'Page not found',
      action: FilledButton(
        onPressed: () => context.go('/'),
        child: const Text('Go home'),
      ),
    ),
  ),
);
