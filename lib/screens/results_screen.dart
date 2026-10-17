import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/election.dart';
import '../services/ballot_crypto.dart';
import '../services/election_service.dart';
import '../services/key_store.dart';
import '../widgets/common.dart';

class ResultsScreen extends StatefulWidget {
  final String electionId;

  const ResultsScreen({super.key, required this.electionId});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final _service = ElectionService.instance;
  late final Stream<Election?> _election;
  late final Stream<ElectionResults?> _results;
  final _receipt = TextEditingController();
  bool? _receiptFound;

  @override
  void initState() {
    super.initState();
    _election = _service.watchElection(widget.electionId);
    _results = _service.watchResults(widget.electionId);
    KeyStore.loadReceipt(widget.electionId).then((r) {
      if (r != null && mounted && _receipt.text.isEmpty) _receipt.text = r;
    });
  }

  @override
  void dispose() {
    _receipt.dispose();
    super.dispose();
  }

  void _verify(ElectionResults r) {
    final wanted = BallotCrypto.normalizeReceipt(_receipt.text);
    if (wanted.isEmpty) return;
    setState(() {
      _receiptFound =
          r.receipts.any((x) => BallotCrypto.normalizeReceipt(x) == wanted);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/e/${widget.electionId}')),
        title: const Text('Results'),
      ),
      body: StreamBuilder<Election?>(
        stream: _election,
        builder: (context, es) {
          if (!es.hasData) {
            return es.connectionState == ConnectionState.waiting
                ? const LoadingView()
                : const MessageView(icon: Icons.search_off, title: 'Election not found');
          }
          final e = es.data!;
          return StreamBuilder<ElectionResults?>(
            stream: _results,
            builder: (context, rs) {
              if (rs.connectionState == ConnectionState.waiting && !rs.hasData) {
                return const LoadingView();
              }
              final r = rs.data;
              if (r == null || e.status != ElectionStatus.published) {
                return MessageView(
                  icon: Icons.lock_clock,
                  title: 'Results not published yet',
                  message: 'Ballots stay encrypted until the election closes and '
                      'the electoral committee decrypts them.',
                );
              }
              return PageBody(
                children: [
                  Text(e.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  if (r.publishedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Published ${formatDateTime(r.publishedAt!)}'),
                    ),
                  const SizedBox(height: 16),
                  _summary(r),
                  for (final p in e.positions) _PositionResult(position: p, counts: r.tally[p.id] ?? const {}),
                  _verifyCard(r),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summary(ElectionResults r) {
    return SectionCard(
      title: 'Audit summary',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('Voters recorded', '${r.voterCount}'),
          _row('Encrypted ballots received', '${r.totalBallots}'),
          _row('Valid ballots counted', '${r.validBallots}'),
          _row('Invalid / unreadable ballots', '${r.invalidBallots}'),
          const SizedBox(height: 8),
          InfoBanner(
            r.integrityOk
                ? 'Integrity check passed: one ballot per voter.'
                : 'Integrity warning: number of ballots (${r.totalBallots}) '
                    'does not match number of voters (${r.voterCount}).',
            tone: r.integrityOk ? BannerTone.success : BannerTone.warning,
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _verifyCard(ElectionResults r) {
    return SectionCard(
      title: 'Check my ballot was counted',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _receipt,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Receipt code',
              hintText: 'XXXX-XXXX-XXXX-XXXX',
            ),
            onSubmitted: (_) => _verify(r),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _verify(r), child: const Text('Verify')),
          if (_receiptFound != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              _receiptFound!
                  ? 'Found. Your encrypted ballot was included in the count.'
                  : 'Not found. Check the code, or contact the electoral committee.',
              tone: _receiptFound! ? BannerTone.success : BannerTone.error,
            ),
          ],
        ],
      ),
    );
  }
}

class _PositionResult extends StatelessWidget {
  final Position position;
  final Map<String, int> counts;

  const _PositionResult({required this.position, required this.counts});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final rows = position.candidates
        .map((c) => (c, counts[c.id] ?? 0))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final total = rows.fold<int>(0, (sum, r) => sum + r.$2);
    final top = rows.isEmpty ? 0 : rows.first.$2;
    final winners = rows.where((r) => r.$2 == top && top > 0).length;

    return SectionCard(
      title: position.title,
      trailing: winners > 1
          ? const Chip(label: Text('Tie'), visualDensity: VisualDensity.compact)
          : null,
      child: Column(
        children: [
          for (final (c, n) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (n == top && top > 0) ...[
                        Icon(Icons.emoji_events, size: 18, color: s.primary),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(c.name,
                            style: TextStyle(
                              fontWeight: n == top && top > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                      ),
                      Text('$n vote${n == 1 ? '' : 's'}'
                          '${total > 0 ? '  ·  ${(n * 100 / total).toStringAsFixed(1)}%' : ''}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : n / total,
                      minHeight: 10,
                      backgroundColor: s.surfaceContainerHighest,
                      color: n == top && top > 0 ? s.primary : s.secondary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
