import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config.dart';
import '../../models/election.dart';
import '../../services/auth_service.dart';
import '../../services/election_service.dart';
import '../../services/key_store.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';

/// Where the shared link lands: /e/{electionId}
class VoterEntryScreen extends StatefulWidget {
  final String electionId;

  const VoterEntryScreen({super.key, required this.electionId});

  @override
  State<VoterEntryScreen> createState() => _VoterEntryScreenState();
}

class _VoterEntryScreenState extends State<VoterEntryScreen> {
  final _service = ElectionService.instance;
  late final Stream<Election?> _election;
  late final Stream<User?> _auth;
  final _matric = TextEditingController();
  bool _checking = false;
  String? _error;

  Future<bool>? _hasVotedFuture;
  String? _hasVotedUid;

  @override
  void initState() {
    super.initState();
    _election = _service.watchElection(widget.electionId);
    _auth = FirebaseAuth.instance.authStateChanges();
  }

  @override
  void dispose() {
    _matric.dispose();
    super.dispose();
  }

  Future<bool> _hasVoted(String uid) {
    if (_hasVotedUid != uid || _hasVotedFuture == null) {
      _hasVotedUid = uid;
      _hasVotedFuture = _service.hasVoted(widget.electionId, uid);
    }
    return _hasVotedFuture!;
  }

  Future<void> _continue(Election e, User user) async {
    if (_matric.text.trim().isEmpty) {
      setState(() => _error = 'Enter your matric number.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final (status, matric) =
          await _service.checkEligibility(e.id, _matric.text, user.uid);
      if (!mounted) return;
      switch (status) {
        case EligibilityStatus.notListed:
          setState(() => _error =
              'That matric number is not on the voter list for this election.');
        case EligibilityStatus.usedByOther:
          setState(() => _error =
              'That matric number has already been used to vote. If this '
              'wasn\'t you, contact the electoral committee.');
        case EligibilityStatus.ok:
          context.go('/e/${e.id}/ballot', extra: matric);
      }
    } catch (err) {
      if (mounted) setState(() => _error = 'Could not check eligibility: $err');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Election?>(
      stream: _election,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            body: MessageView(
              icon: Icons.cloud_off,
              title: 'Could not load election',
              message: '${snap.error}',
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: LoadingView());
        }
        final e = snap.data;
        if (e == null) {
          return Scaffold(
            body: MessageView(
              icon: Icons.search_off,
              title: 'Election not found',
              message: 'Check the link and try again.',
              action: FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go home'),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.how_to_vote_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text(AppConfig.appName),
              ],
            ),
          ),
          body: PageBody(
            maxWidth: 560,
            children: [_header(e), ..._body(e)],
          ),
        );
      },
    );
  }

  Widget _header(Election e) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(e.status),
          const SizedBox(height: 10),
          Text(e.title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(e.description),
          ],
          const SizedBox(height: 8),
          Text(formatWindow(e), style: t.bodySmall),
          Text('Hosted by ${e.hostName}', style: t.bodySmall),
        ],
      ),
    );
  }

  List<Widget> _body(Election e) {
    switch (e.status) {
      case ElectionStatus.draft:
        return const [
          InfoBanner('Voting has not opened yet. Check back at the start time.'),
        ];
      case ElectionStatus.closed:
        return const [
          InfoBanner('Voting has closed. Results will appear here once the '
              'electoral committee decrypts them.'),
        ];
      case ElectionStatus.published:
        return [
          const InfoBanner('Results are out!', tone: BannerTone.success),
          FilledButton.icon(
            onPressed: () => context.go('/e/${e.id}/results'),
            icon: const Icon(Icons.bar_chart),
            label: const Text('View results'),
          ),
        ];
      case ElectionStatus.open:
        if (!e.hasStarted) {
          return [InfoBanner('Voting opens ${formatDateTime(e.startAt)}.')];
        }
        if (e.hasEnded) {
          return const [InfoBanner('The voting window has ended.')];
        }
        return [
          StreamBuilder<User?>(
            stream: _auth,
            initialData: FirebaseAuth.instance.currentUser,
            builder: (context, snap) {
              final user = snap.data;
              if (user == null) {
                return const SectionCard(
                  child: AuthForm(
                    headline: 'Sign in to vote',
                    subtitle: 'Your account only proves you haven\'t voted '
                        'before. It is never linked to your choices.',
                  ),
                );
              }
              return FutureBuilder<bool>(
                future: _hasVoted(user.uid),
                builder: (context, voted) {
                  if (voted.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: LoadingView(),
                    );
                  }
                  if (voted.hasError) {
                    return InfoBanner('Could not check your status: ${voted.error}',
                        tone: BannerTone.error);
                  }
                  if (voted.data == true) return _AlreadyVoted(electionId: e.id);
                  return _matricForm(e, user);
                },
              );
            },
          ),
        ];
    }
  }

  Widget _matricForm(Election e, User user) {
    return SectionCard(
      title: 'Verify you can vote',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _matric,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Matric number',
              hintText: 'e.g. 18/CS/1001',
            ),
            onSubmitted: (_) => _continue(e, user),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(_error!, tone: BannerTone.error),
          ] else
            const SizedBox(height: 16),
          FilledButton(
            onPressed: _checking ? null : () => _continue(e, user),
            child: _checking
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue to ballot'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Signed in as ${user.displayName ?? user.email}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              TextButton(
                onPressed: AuthService.signOut,
                child: const Text('Switch account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlreadyVoted extends StatelessWidget {
  final String electionId;

  const _AlreadyVoted({required this.electionId});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBanner('You have already voted in this election. Thank you!',
              tone: BannerTone.success),
          FutureBuilder<String?>(
            future: KeyStore.loadReceipt(electionId),
            builder: (context, snap) {
              final r = snap.data;
              if (r == null) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Your receipt code'),
                  const SizedBox(height: 4),
                  SelectableText(
                    r,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text('Use it to confirm your ballot was counted once '
                      'results are published.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
