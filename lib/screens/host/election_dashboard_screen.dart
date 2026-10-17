import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../config.dart';
import '../../models/election.dart';
import '../../services/ballot_crypto.dart';
import '../../services/election_service.dart';
import '../../services/key_store.dart';
import '../../widgets/common.dart';

class ElectionDashboardScreen extends StatefulWidget {
  final String electionId;

  const ElectionDashboardScreen({super.key, required this.electionId});

  @override
  State<ElectionDashboardScreen> createState() => _ElectionDashboardScreenState();
}

class _ElectionDashboardScreenState extends State<ElectionDashboardScreen> {
  final _service = ElectionService.instance;
  late final Stream<Election?> _election;
  late final Stream<int> _voterCount;
  late final Stream<List<EligibleVoter>> _eligible;
  final _matricInput = TextEditingController();
  bool _busy = false;
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    _election = _service.watchElection(widget.electionId);
    _voterCount = _service.watchVoterCount(widget.electionId);
    _eligible = _service.watchEligible(widget.electionId);
  }

  @override
  void dispose() {
    _matricInput.dispose();
    super.dispose();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _busyLabel = label;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------ actions

  Future<void> _addEligible() async {
    final text = _matricInput.text;
    if (text.trim().isEmpty) return;
    await _run('Adding voters…', () async {
      final n = await _service.addEligible(widget.electionId, text);
      _matricInput.clear();
      if (mounted) showSnack(context, 'Added $n matric number(s)');
    });
  }

  Future<void> _openVoting(Election e) async {
    if (e.eligibleCount == 0) {
      showSnack(context, 'Add at least one eligible matric number first.');
      return;
    }
    if (e.hasEnded) {
      showSnack(context, 'The closing time has passed. Change it first.');
      return;
    }
    final ok = await confirm(
      context,
      title: 'Open voting?',
      message: 'Voters with the link can vote from ${formatDateTime(e.startAt)} '
          'until ${formatDateTime(e.endAt)}. The ballot and voter list can\'t be '
          'changed after this.',
      confirmLabel: 'Open voting',
    );
    if (!ok) return;
    await _run('Opening…', () => _service.setStatus(e.id, ElectionStatus.open));
  }

  Future<void> _closeVoting(Election e) async {
    final ok = await confirm(
      context,
      title: 'Close voting now?',
      message: 'No more votes will be accepted. This cannot be undone.',
      confirmLabel: 'Close voting',
    );
    if (!ok) return;
    await _run('Closing…', () => _service.setStatus(e.id, ElectionStatus.closed));
  }

  Future<void> _changeEnd(Election e) async {
    final d = await pickDateTime(context, e.endAt);
    if (d == null) return;
    if (!d.isAfter(e.startAt)) {
      if (mounted) showSnack(context, 'Closing time must be after opening time.');
      return;
    }
    await _run('Saving…', () => _service.updateWindow(e.id, e.startAt, d));
  }

  Future<void> _decryptAndPublish(Election e) async {
    final stored = await KeyStore.loadHostShare(e.id);
    if (!mounted) return;
    final input = await showDialog<_KeyInput>(
      context: context,
      builder: (_) => _DecryptDialog(
        needHostKey: stored == null,
        needOfficerKey: e.requiresOfficerKey,
      ),
    );
    if (input == null || !mounted) return;

    final seed = await _rebuildKey(e, stored, input);
    if (seed == null) {
      if (mounted) {
        showSnack(context, 'Those keys don\'t unlock this election. Check and try again.');
      }
      return;
    }

    await _run('Decrypting ballots on this device…', () async {
      final r = await _service.tallyAndPublish(election: e, seed: seed);
      if (mounted) {
        showSnack(context, 'Counted ${r.validBallots} valid ballot(s).');
        context.go('/e/${e.id}/results');
      }
    });
  }

  /// Rebuilds the election private key from the key share(s) and checks it
  /// against the public key. Returns null if the keys are wrong.
  Future<List<int>?> _rebuildKey(Election e, List<int>? stored, _KeyInput input) async {
    try {
      final hostShare = stored ?? BallotCrypto.decodeKey(input.hostKey ?? '');
      final seed = e.requiresOfficerKey
          ? BallotCrypto.xor(hostShare, BallotCrypto.decodeKey(input.officerKey ?? ''))
          : hostShare;
      return await BallotCrypto.keyMatches(seed, e.publicKey) ? seed : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteDraft(Election e) async {
    final ok = await confirm(
      context,
      title: 'Delete this draft?',
      message: 'This removes the election. Voters on the list are not notified.',
      confirmLabel: 'Delete',
    );
    if (!ok) return;
    await _run('Deleting…', () async {
      await _service.deleteDraft(e.id);
      if (mounted) context.go('/host');
    });
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Election?>(
      stream: _election,
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: MessageView(icon: Icons.cloud_off, title: 'Error', message: '${snap.error}'),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: LoadingView());
        }
        final e = snap.data;
        if (e == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.go('/host'))),
            body: const MessageView(icon: Icons.search_off, title: 'Election not found'),
          );
        }
        if (e.hostId != FirebaseAuth.instance.currentUser?.uid) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.go('/host'))),
            body: const MessageView(
              icon: Icons.lock_outline,
              title: 'Not your election',
              message: 'Only the host can manage this election.',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go('/host')),
            title: Text(e.title, overflow: TextOverflow.ellipsis),
          ),
          body: Stack(
            children: [
              PageBody(
                children: [
                  _header(e),
                  if (e.status != ElectionStatus.draft) _turnoutCard(e),
                  _actionsCard(e),
                  _shareCard(e),
                  if (e.status == ElectionStatus.draft) _eligibleEditor(e),
                  _ballotPreview(e),
                ],
              ),
              if (_busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black38,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(_busyLabel),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Election e) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(e.status),
              const SizedBox(width: 8),
              if (e.requiresOfficerKey)
                const Chip(
                  avatar: Icon(Icons.key, size: 16),
                  label: Text('2-key results'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(formatWindow(e), style: t.bodyMedium),
          if (e.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(e.description, style: t.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _turnoutCard(Election e) {
    return StreamBuilder<int>(
      stream: _voterCount,
      builder: (context, snap) {
        final voted = snap.data ?? 0;
        final total = e.eligibleCount;
        final ratio = total == 0 ? 0.0 : (voted / total).clamp(0.0, 1.0);
        final t = Theme.of(context).textTheme;
        return SectionCard(
          title: 'Live turnout',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$voted of $total voted',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: ratio, minHeight: 10),
              ),
              const SizedBox(height: 10),
              Text('${(ratio * 100).toStringAsFixed(1)}% turnout'),
              const SizedBox(height: 12),
              const InfoBanner(
                'Only turnout is visible. Ballots are encrypted, so nobody can '
                'see who is winning until you decrypt after voting closes.',
                icon: Icons.visibility_off_outlined,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actionsCard(Election e) {
    final children = <Widget>[];
    switch (e.status) {
      case ElectionStatus.draft:
        children.addAll([
          const Text('1. Add eligible matric numbers below.\n'
              '2. Share the link.\n3. Open voting.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openVoting(e),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Open voting'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _changeEnd(e),
            icon: const Icon(Icons.schedule),
            label: const Text('Change closing time'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _deleteDraft(e),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete draft'),
          ),
        ]);
      case ElectionStatus.open:
        children.addAll([
          if (!e.hasStarted)
            InfoBanner('Voting starts at ${formatDateTime(e.startAt)}.')
          else if (e.hasEnded)
            const InfoBanner('The voting window has ended. Close the election '
                'to decrypt the results.', tone: BannerTone.warning)
          else
            const InfoBanner('Voting is live.', tone: BannerTone.success),
          FilledButton.icon(
            onPressed: () => _closeVoting(e),
            icon: const Icon(Icons.stop),
            label: const Text('Close voting'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _changeEnd(e),
            icon: const Icon(Icons.schedule),
            label: const Text('Change closing time'),
          ),
        ]);
      case ElectionStatus.closed:
        children.addAll([
          InfoBanner(
            e.requiresOfficerKey
                ? 'Voting is closed. You and the electoral officer must both '
                    'enter your keys to decrypt the results.'
                : 'Voting is closed. Decrypt the ballots on this device to '
                    'count and publish the results.',
          ),
          FilledButton.icon(
            onPressed: () => _decryptAndPublish(e),
            icon: const Icon(Icons.lock_open),
            label: const Text('Decrypt & publish results'),
          ),
        ]);
      case ElectionStatus.published:
        children.addAll([
          const InfoBanner('Results are published.', tone: BannerTone.success),
          FilledButton.icon(
            onPressed: () => context.go('/e/${e.id}/results'),
            icon: const Icon(Icons.bar_chart),
            label: const Text('View results'),
          ),
        ]);
    }
    return SectionCard(
      title: 'Next step',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _shareCard(Election e) {
    final link = AppConfig.electionLink(e.id);
    return SectionCard(
      title: 'Share with voters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(link, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Election code: ${e.id}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => copyText(context, link, label: 'Link copied'),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/e/${e.id}'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Voter view'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eligibleEditor(Election e) {
    return SectionCard(
      title: 'Eligible voters (${e.eligibleCount})',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _matricInput,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Paste matric numbers',
              hintText: '18/CS/1001\n18/CS/1002\n… one per line or comma-separated',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _addEligible,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add to voter list'),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<EligibleVoter>>(
            stream: _eligible,
            builder: (context, snap) {
              final list = snap.data ?? const <EligibleVoter>[];
              if (list.isEmpty) {
                return const Text('No voters added yet.');
              }
              const maxShown = 60;
              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final v in list.take(maxShown))
                    InputChip(
                      label: Text(v.label),
                      onDeleted: () => _run(
                        'Removing…',
                        () => _service.removeEligible(e.id, v.id),
                      ),
                    ),
                  if (list.length > maxShown)
                    Chip(label: Text('+${list.length - maxShown} more')),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _ballotPreview(Election e) {
    return SectionCard(
      title: 'Ballot',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in e.positions) ...[
            Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            for (final c in p.candidates)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text('• ${c.name}'),
              ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _KeyInput {
  final String? hostKey;
  final String? officerKey;

  const _KeyInput(this.hostKey, this.officerKey);
}

class _DecryptDialog extends StatefulWidget {
  final bool needHostKey;
  final bool needOfficerKey;

  const _DecryptDialog({required this.needHostKey, required this.needOfficerKey});

  @override
  State<_DecryptDialog> createState() => _DecryptDialogState();
}

class _DecryptDialogState extends State<_DecryptDialog> {
  final _host = TextEditingController();
  final _officer = TextEditingController();

  @override
  void dispose() {
    _host.dispose();
    _officer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Decrypt results'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ballots are downloaded and decrypted on this device. '
              'The private key never leaves it.',
            ),
            if (!widget.needHostKey) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 18),
                  SizedBox(width: 6),
                  Expanded(child: Text('Host key found on this device')),
                ],
              ),
            ],
            if (widget.needHostKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _host,
                decoration: const InputDecoration(labelText: 'Host key (CVHOST:…)'),
              ),
            ],
            if (widget.needOfficerKey) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _officer,
                decoration: const InputDecoration(
                  labelText: 'Electoral officer key (CVOFFICER:…)',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _KeyInput(_host.text, _officer.text)),
          child: const Text('Decrypt'),
        ),
      ],
    );
  }
}
