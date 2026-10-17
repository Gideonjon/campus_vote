import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/election.dart';
import '../../services/election_service.dart';
import '../../widgets/common.dart';

class _CandidateDraft {
  final name = TextEditingController();
  final bio = TextEditingController();

  void dispose() {
    name.dispose();
    bio.dispose();
  }
}

class _PositionDraft {
  final title = TextEditingController();
  final candidates = <_CandidateDraft>[_CandidateDraft(), _CandidateDraft()];

  void dispose() {
    title.dispose();
    for (final c in candidates) {
      c.dispose();
    }
  }
}

class CreateElectionScreen extends StatefulWidget {
  const CreateElectionScreen({super.key});

  @override
  State<CreateElectionScreen> createState() => _CreateElectionScreenState();
}

class _CreateElectionScreenState extends State<CreateElectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _positions = <_PositionDraft>[_PositionDraft()];
  late DateTime _start;
  late DateTime _end;
  bool _withOfficer = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _end = _start.add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final p in _positions) {
      p.dispose();
    }
    super.dispose();
  }

  void _disposeLater(void Function() dispose) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => dispose());

  Future<void> _pickStart() async {
    final d = await pickDateTime(context, _start);
    if (d == null) return;
    setState(() {
      _start = d;
      if (!_end.isAfter(_start)) _end = _start.add(const Duration(hours: 2));
    });
  }

  Future<void> _pickEnd() async {
    final d = await pickDateTime(context, _end);
    if (d == null) return;
    setState(() => _end = d);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'The end time must be after the start time.');
      return;
    }

    final positions = <Position>[];
    for (var i = 0; i < _positions.length; i++) {
      final draft = _positions[i];
      final pid = 'p${i + 1}';
      final candidates = <Candidate>[];
      for (var j = 0; j < draft.candidates.length; j++) {
        final c = draft.candidates[j];
        if (c.name.text.trim().isEmpty) continue;
        candidates.add(Candidate(
          id: '${pid}c${j + 1}',
          name: c.name.text.trim(),
          bio: c.bio.text.trim(),
        ));
      }
      if (candidates.isEmpty) {
        setState(() => _error =
            '"${draft.title.text.trim()}" needs at least one candidate.');
        return;
      }
      positions.add(Position(id: pid, title: draft.title.text.trim(), candidates: candidates));
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _busy = true);
    try {
      final (id, keys) = await ElectionService.instance.createElection(
        host: user,
        title: _title.text,
        description: _description.text,
        startAt: _start,
        endAt: _end,
        positions: positions,
        withOfficer: _withOfficer,
      );
      if (mounted) context.go('/host/e/$id/keys', extra: keys);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not create election: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/host')),
        title: const Text('New election'),
      ),
      body: Form(
        key: _formKey,
        child: PageBody(
          children: [
            SectionCard(
              title: 'Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Election title',
                      hintText: 'e.g. NACOS UniUyo Executive Elections 2026',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                    ),
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Voting window',
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('Opens'),
                    subtitle: Text(formatDateTime(_start)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickStart,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.stop_circle_outlined),
                    title: const Text('Closes'),
                    subtitle: Text(formatDateTime(_end)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _pickEnd,
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Votes are only accepted between these times AND after '
                      'you press "Open voting" on the dashboard.',
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < _positions.length; i++) _positionCard(i),
            OutlinedButton.icon(
              onPressed: () => setState(() => _positions.add(_PositionDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Add position'),
            ),
            const SizedBox(height: 16),
            SectionCard(
              title: 'Security',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _withOfficer,
                onChanged: (v) => setState(() => _withOfficer = v),
                title: const Text('Require an electoral officer key'),
                subtitle: const Text(
                  'The decryption key is split in two. Results can only be '
                  'revealed when you AND the electoral officer both enter '
                  'your keys, so no single person can peek.',
                ),
              ),
            ),
            if (_error != null) InfoBanner(_error!, tone: BannerTone.error),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_outline),
              label: Text(_busy ? 'Generating keys…' : 'Create election'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionCard(int i) {
    final p = _positions[i];
    return Card(
      key: ObjectKey(p),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: p.title,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Position ${i + 1}',
                      hintText: 'e.g. President',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter the position' : null,
                  ),
                ),
                if (_positions.length > 1)
                  IconButton(
                    tooltip: 'Remove position',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _positions.removeAt(i));
                      _disposeLater(p.dispose);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (var j = 0; j < p.candidates.length; j++)
              _candidateRow(p, j),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => p.candidates.add(_CandidateDraft())),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Add candidate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _candidateRow(_PositionDraft p, int j) {
    final c = p.candidates[j];
    return Padding(
      key: ObjectKey(c),
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14, right: 8),
            child: CircleAvatar(radius: 14, child: Text('${j + 1}')),
          ),
          Expanded(
            child: Column(
              children: [
                TextFormField(
                  controller: c.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Candidate name'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: c.bio,
                  decoration: const InputDecoration(
                    labelText: 'Short bio / manifesto line (optional)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          if (p.candidates.length > 1)
            IconButton(
              tooltip: 'Remove candidate',
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() => p.candidates.removeAt(j));
                _disposeLater(c.dispose);
              },
            ),
        ],
      ),
    );
  }
}
