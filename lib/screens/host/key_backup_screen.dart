import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/ballot_crypto.dart';
import '../../widgets/common.dart';

/// Shown once, right after creating an election: the private key share(s)
/// the host must back up. They are never stored in Firebase.
class KeyBackupScreen extends StatefulWidget {
  final String electionId;
  final ElectionKeys? keys;

  const KeyBackupScreen({super.key, required this.electionId, this.keys});

  @override
  State<KeyBackupScreen> createState() => _KeyBackupScreenState();
}

class _KeyBackupScreenState extends State<KeyBackupScreen> {
  bool _saved = false;

  void _continue() => context.go('/host/e/${widget.electionId}');

  @override
  Widget build(BuildContext context) {
    final keys = widget.keys;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Back up your keys'),
      ),
      body: keys == null
          ? MessageView(
              icon: Icons.key_off_outlined,
              title: 'Keys are only shown once',
              message: 'Your host key is saved on the device you created the '
                  'election with. If you need it elsewhere, use the backup '
                  'you copied when you created the election.',
              action: FilledButton(onPressed: _continue, child: const Text('Go to dashboard')),
            )
          : PageBody(
              children: [
                const InfoBanner(
                  'These keys decrypt the ballots. They are NOT stored in the '
                  'cloud, so if you lose them, the results can never be '
                  'revealed. Copy them somewhere safe now.',
                  tone: BannerTone.warning,
                ),
                _KeyCard(
                  title: 'Your host key',
                  description: 'Also saved on this device automatically.',
                  value: BallotCrypto.encodeKey(BallotCrypto.hostKeyPrefix, keys.hostShare),
                ),
                if (keys.officerShare != null)
                  _KeyCard(
                    title: 'Electoral officer key',
                    description: 'Give this to the electoral officer (e.g. send '
                        'privately). Results need BOTH keys.',
                    value: BallotCrypto.encodeKey(
                        BallotCrypto.officerKeyPrefix, keys.officerShare!),
                  ),
                CheckboxListTile(
                  value: _saved,
                  onChanged: (v) => setState(() => _saved = v ?? false),
                  title: const Text('I have saved my key(s) somewhere safe'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saved ? _continue : null,
                  child: const Text('Continue to dashboard'),
                ),
              ],
            ),
    );
  }
}

class _KeyCard extends StatelessWidget {
  final String title;
  final String description;
  final String value;

  const _KeyCard({required this.title, required this.description, required this.value});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      trailing: IconButton(
        tooltip: 'Copy',
        icon: const Icon(Icons.copy),
        onPressed: () => copyText(context, value, label: '$title copied'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(description),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
