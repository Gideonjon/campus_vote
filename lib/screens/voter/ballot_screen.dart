import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/election.dart';
import '../../services/election_service.dart';
import '../../widgets/common.dart';

class BallotScreen extends StatefulWidget {
  final String electionId;
  final String? matric;

  const BallotScreen({super.key, required this.electionId, this.matric});

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  final _service = ElectionService.instance;
  Election? _election;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  final Map<String, String> _choices = {};

  @override
  void initState() {
    super.initState();
    if (widget.matric == null || FirebaseAuth.instance.currentUser == null) {
      // Opened directly (e.g. page refresh) – go back through verification.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.go('/e/${widget.electionId}'),
      );
      return;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await _service.getElection(widget.electionId);
      if (!mounted) return;
      setState(() {
        _election = e;
        _loading = false;
      });
    } catch (err) {
      if (mounted) {
        setState(() {
          _error = 'Could not load the ballot: $err';
          _loading = false;
        });
      }
    }
  }

  bool get _complete =>
      _election != null && _choices.length == _election!.positions.length;

  Future<void> _review() async {
    final e = _election!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm your vote'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in e.positions) ...[
                Text(p.title, style: Theme.of(ctx).textTheme.labelLarge),
                Text(p.candidate(_choices[p.id]!)?.name ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 10),
              ],
              const Text('Once submitted, your vote can\'t be changed.'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Go back')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.lock),
            label: const Text('Encrypt & submit'),
          ),
        ],
      ),
    );
    if (ok == true) await _submit();
  }

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final e = _election;
    if (user == null || e == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final receipt = await _service.castVote(
        election: e,
        uid: user.uid,
        matric: widget.matric!,
        choices: Map.of(_choices),
      );
      if (mounted) context.go('/e/${e.id}/receipt', extra: receipt);
    } on FirebaseException catch (err) {
      if (!mounted) return;
      setState(() => _error = err.code == 'permission-denied'
          ? 'Your vote was not accepted. You may have already voted, or '
              'voting has just closed.'
          : 'Could not submit: ${err.message}');
    } catch (err) {
      if (mounted) setState(() => _error = 'Could not submit: $err');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _election;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/e/${widget.electionId}')),
        title: const Text('Your ballot'),
      ),
      body: _loading
          ? const LoadingView()
          : e == null
              ? MessageView(
                  icon: Icons.error_outline,
                  title: 'Ballot unavailable',
                  message: _error,
                )
              : PageBody(
                  maxWidth: 560,
                  children: [
                    Text(e.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text('Voting as ${widget.matric}'),
                    const SizedBox(height: 16),
                    const InfoBanner(
                      'Your choices are encrypted on this device before they are '
                      'sent. The stored ballot has no link to your name or matric '
                      'number.',
                      icon: Icons.lock_outline,
                    ),
                    for (final p in e.positions) _positionCard(p),
                    if (_error != null) InfoBanner(_error!, tone: BannerTone.error),
                    FilledButton.icon(
                      onPressed: (_complete && !_submitting && e.acceptingVotes)
                          ? _review
                          : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.how_to_vote),
                      label: Text(_submitting
                          ? 'Encrypting & submitting…'
                          : !e.acceptingVotes
                              ? 'Voting is not open'
                              : _complete
                                  ? 'Review & submit'
                                  : 'Choose a candidate for every position'),
                    ),
                  ],
                ),
    );
  }

  Widget _positionCard(Position p) {
    final s = Theme.of(context).colorScheme;
    return SectionCard(
      title: p.title,
      child: Column(
        children: [
          for (final c in p.candidates)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _choices[p.id] == c.id ? s.primaryContainer : s.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _choices[p.id] == c.id ? s.primary : s.outlineVariant,
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: _submitting
                      ? null
                      : () => setState(() => _choices[p.id] = c.id),
                  leading: Icon(
                    _choices[p.id] == c.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: _choices[p.id] == c.id ? s.primary : null,
                  ),
                  title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: c.bio.isEmpty ? null : Text(c.bio),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
