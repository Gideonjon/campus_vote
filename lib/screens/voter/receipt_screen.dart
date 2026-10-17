import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/key_store.dart';
import '../../widgets/common.dart';

class ReceiptScreen extends StatefulWidget {
  final String electionId;
  final String? receipt;

  const ReceiptScreen({super.key, required this.electionId, this.receipt});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late final Future<String?> _receipt = widget.receipt != null
      ? Future.value(widget.receipt)
      : KeyStore.loadReceipt(widget.electionId);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Vote submitted')),
      body: FutureBuilder<String?>(
        future: _receipt,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          final r = snap.data;
          return PageBody(
            maxWidth: 520,
            children: [
              const SizedBox(height: 24),
              Icon(Icons.verified_rounded, size: 72, color: s.primary),
              const SizedBox(height: 12),
              Text('Your vote is in',
                  textAlign: TextAlign.center,
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'It was encrypted on your device. Nobody can read it until the '
                'election closes, and even then it can\'t be traced back to you.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (r != null)
                SectionCard(
                  title: 'Your receipt code',
                  trailing: IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy),
                    onPressed: () => copyText(context, r, label: 'Receipt copied'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        r,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Screenshot or save this. When results are published, '
                        'enter it on the results page to confirm your ballot '
                        'was counted. It reveals nothing about who you voted for.',
                      ),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () => context.go('/e/${widget.electionId}/results'),
                icon: const Icon(Icons.bar_chart),
                label: const Text('Results page'),
              ),
            ],
          );
        },
      ),
    );
  }
}
