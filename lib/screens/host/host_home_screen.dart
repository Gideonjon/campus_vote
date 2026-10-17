import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/election.dart';
import '../../services/auth_service.dart';
import '../../services/election_service.dart';
import '../../widgets/common.dart';

class HostHomeScreen extends StatefulWidget {
  const HostHomeScreen({super.key});

  @override
  State<HostHomeScreen> createState() => _HostHomeScreenState();
}

class _HostHomeScreenState extends State<HostHomeScreen> {
  Stream<List<Election>>? _stream;
  String? _uid;

  Stream<List<Election>> _streamFor(String uid) {
    if (_uid != uid || _stream == null) {
      _uid = uid;
      _stream = ElectionService.instance.watchMyElections(uid);
    }
    return _stream!;
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: const Text('My elections'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/host/new'),
        icon: const Icon(Icons.add),
        label: const Text('New election'),
      ),
      body: StreamBuilder<List<Election>>(
        stream: _streamFor(user.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return MessageView(
              icon: Icons.cloud_off,
              title: 'Could not load elections',
              message: '${snap.error}',
            );
          }
          if (!snap.hasData) return const LoadingView();
          final elections = snap.data!;
          if (elections.isEmpty) {
            return MessageView(
              icon: Icons.ballot_outlined,
              title: 'No elections yet',
              message: 'Create your first election to get a shareable voting link.',
              action: FilledButton.icon(
                onPressed: () => context.go('/host/new'),
                icon: const Icon(Icons.add),
                label: const Text('Create election'),
              ),
            );
          }
          return PageBody(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Signed in as ${user.displayName ?? user.email}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              for (final e in elections)
                Card(
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    title: Text(e.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${e.positions.length} position(s) · '
                        '${e.eligibleCount} eligible\n${formatWindow(e)}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: StatusChip(e.status),
                    onTap: () => context.go('/host/e/${e.id}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
