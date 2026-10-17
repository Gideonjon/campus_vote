import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';

/// Marketing landing page for the web build (the "/" route on web).
/// Two main actions everywhere: "Host login" and "Join an election".
class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final _scroll = ScrollController();
  final _howKey = GlobalKey();
  final _securityKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
  }

  void _hostLogin() {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    context.go(signedIn ? '/host' : '/login');
  }

  void _join() => showJoinElectionDialog(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 900;
          return Column(
            children: [
              _NavBar(
                wide: wide,
                onHost: _hostLogin,
                onJoin: _join,
                onHow: () => _scrollTo(_howKey),
                onSecurity: () => _scrollTo(_securityKey),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      _Hero(wide: wide, onHost: _hostLogin, onJoin: _join),
                      _HowItWorks(key: _howKey, wide: wide),
                      _Security(key: _securityKey, wide: wide),
                      _Features(wide: wide),
                      _FinalCta(onHost: _hostLogin, onJoin: _join),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- join

/// Asks for an election link or code and opens it.
Future<void> showJoinElectionDialog(BuildContext context) async {
  final id = await showDialog<String>(
    context: context,
    builder: (_) => const _JoinDialog(),
  );
  if (id != null && id.isNotEmpty && context.mounted) context.go('/e/$id');
}

/// Accepts "abc123", "https://site.web.app/e/abc123" or "/e/abc123/ballot".
String parseElectionCode(String input) {
  var t = input.trim();
  final i = t.indexOf('/e/');
  if (i >= 0) t = t.substring(i + 3);
  return t.split('/').first.split('?').first.split('#').first.trim();
}

class _JoinDialog extends StatefulWidget {
  const _JoinDialog();

  @override
  State<_JoinDialog> createState() => _JoinDialogState();
}

class _JoinDialogState extends State<_JoinDialog> {
  final _ctrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final id = parseElectionCode(_ctrl.text);
    if (id.isEmpty) {
      setState(() => _error = 'Paste the voting link or enter the election code.');
      return;
    }
    Navigator.pop(context, id);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join an election'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Paste the link your electoral committee shared, or '
                'type the election code.'),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Link or election code',
                hintText: 'e.g. 7Gk2PqX9aB',
                prefixIcon: const Icon(Icons.link),
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Continue'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- layout

class _Section extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double vPad;

  const _Section({required this.child, this.color, this.vPad = 80});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: narrow ? vPad * .6 : vPad),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: child,
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String text;

  const _Eyebrow(this.text);

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: s.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        fontSize: 13,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.eyebrow, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;
    return Column(
      children: [
        _Eyebrow(eyebrow),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
        if (subtitle != null) ...[
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Text(subtitle!,
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant, height: 1.5)),
          ),
        ],
        const SizedBox(height: 48),
      ],
    );
  }
}

/// Lays children in a row on wide screens and a column on narrow ones.
class _ResponsiveRow extends StatelessWidget {
  final bool wide;
  final List<Widget> children;
  final double gap;

  const _ResponsiveRow({required this.wide, required this.children, this.gap = 20});

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            children[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- nav

class _NavBar extends StatelessWidget {
  final bool wide;
  final VoidCallback onHost;
  final VoidCallback onJoin;
  final VoidCallback onHow;
  final VoidCallback onSecurity;

  const _NavBar({
    required this.wide,
    required this.onHost,
    required this.onJoin,
    required this.onHow,
    required this.onSecurity,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surface,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: s.outlineVariant.withValues(alpha: .6))),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Row(
              children: [
                const _Logo(),
                const Spacer(),
                if (wide) ...[
                  TextButton(onPressed: onHow, child: const Text('How it works')),
                  TextButton(onPressed: onSecurity, child: const Text('Security')),
                  const SizedBox(width: 12),
                  OutlinedButton(onPressed: onJoin, child: const Text('Join election')),
                  const SizedBox(width: 10),
                  FilledButton(onPressed: onHost, child: const Text('Host login')),
                ] else
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu),
                    onSelected: (v) {
                      switch (v) {
                        case 'join':
                          onJoin();
                        case 'host':
                          onHost();
                        case 'how':
                          onHow();
                        default:
                          onSecurity();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'join', child: Text('Join election')),
                      PopupMenuItem(value: 'host', child: Text('Host login')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'how', child: Text('How it works')),
                      PopupMenuItem(value: 'security', child: Text('Security')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.how_to_vote_rounded, color: s.onPrimary, size: 20),
        ),
        const SizedBox(width: 10),
        const Text(AppConfig.appName,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ---------------------------------------------------------------- hero

class _Hero extends StatelessWidget {
  final bool wide;
  final VoidCallback onHost;
  final VoidCallback onJoin;

  const _Hero({required this.wide, required this.onHost, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = Theme.of(context).colorScheme;

    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: s.primaryContainer,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 14, color: s.onPrimaryContainer),
              const SizedBox(width: 6),
              Text('End-to-end encrypted ballots',
                  style: TextStyle(
                      color: s.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Student elections nobody can peek at.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: (wide ? t.displayMedium : t.headlineLarge)
              ?.copyWith(fontWeight: FontWeight.w800, height: 1.08, letterSpacing: -1),
        ),
        const SizedBox(height: 20),
        Text(
          'Every vote is encrypted on the voter\'s own phone before it is sent. '
          'No live results, no leaks, no "the admin saw it first". Results '
          'are revealed only when voting closes.',
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: t.titleMedium?.copyWith(color: s.onSurfaceVariant, height: 1.55),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: onJoin,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              icon: const Icon(Icons.how_to_vote_outlined),
              label: const Text('Join an election'),
            ),
            OutlinedButton.icon(
              onPressed: onHost,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(200, 56),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Login as host'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Free for student associations · No app install needed to vote',
            textAlign: wide ? TextAlign.start : TextAlign.center,
            style: t.bodySmall?.copyWith(color: s.onSurfaceVariant)),
      ],
    );

    return _Section(
      vPad: 96,
      color: s.surface,
      child: wide
          ? Row(
              children: [
                Expanded(flex: 6, child: copy),
                const SizedBox(width: 56),
                const Expanded(flex: 5, child: _BallotMockup()),
              ],
            )
          : Column(children: [copy, const SizedBox(height: 48), const _BallotMockup()]),
    );
  }
}

/// A small illustrated "phone ballot" that shows plain text becoming ciphertext.
class _BallotMockup extends StatelessWidget {
  const _BallotMockup();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 12, color: s.onSurfaceVariant);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: s.surfaceContainerLow,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: s.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: s.shadow.withValues(alpha: .08),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('President', style: TextStyle(fontWeight: FontWeight.w700, color: s.onSurface)),
              const SizedBox(height: 10),
              _mockOption(context, 'Ada Okon', selected: true),
              _mockOption(context, 'Emeka Bassey'),
              _mockOption(context, 'Ruth Akpan'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: s.primary),
                  const SizedBox(width: 6),
                  Text('Encrypted on this phone',
                      style: TextStyle(
                          color: s.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: s.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ct: 9fA3x0Lq+e2Rk7…Vb81==\nmac: Qx7h2Lw0…\nepk: m4Tz9c…',
                  style: mono,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(onPressed: null, child: const Text('Vote submitted ✓')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mockOption(BuildContext context, String name, {bool selected = false}) {
    final s = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: selected ? s.primaryContainer : s.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? s.primary : s.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: selected ? s.primary : s.outline,
          ),
          const SizedBox(width: 10),
          Text(name, style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- how

class _HowItWorks extends StatelessWidget {
  final bool wide;

  const _HowItWorks({super.key, required this.wide});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return _Section(
      color: s.surfaceContainerLow,
      child: Column(
        children: [
          const _SectionTitle(
            eyebrow: 'How it works',
            title: 'From setup to results in four steps',
          ),
          _ResponsiveRow(
            wide: wide,
            children: const [
              _StepCard(
                n: 1,
                icon: Icons.edit_note,
                title: 'Create the election',
                body: 'Add positions, candidates and the voting window. A '
                    'unique encryption key is generated on your device.',
              ),
              _StepCard(
                n: 2,
                icon: Icons.groups_outlined,
                title: 'Add eligible voters',
                body: 'Paste the matric numbers of students allowed to vote. '
                    'Each number can be used exactly once.',
              ),
              _StepCard(
                n: 3,
                icon: Icons.qr_code_2,
                title: 'Share one link',
                body: 'Send the link or QR code to the class group. Students '
                    'vote from any phone browser, with no app install.',
              ),
              _StepCard(
                n: 4,
                icon: Icons.lock_open,
                title: 'Reveal the results',
                body: 'When voting closes, ballots are decrypted on the host\'s '
                    'device and the results are published for everyone.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int n;
  final IconData icon;
  final String title;
  final String body;

  const _StepCard({required this.n, required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: s.primary, size: 28),
              const Spacer(),
              Text('0$n',
                  style: t.titleLarge?.copyWith(
                      color: s.outlineVariant, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- security

class _Security extends StatelessWidget {
  final bool wide;

  const _Security({super.key, required this.wide});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final points = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _Point(
          icon: Icons.phonelink_lock,
          title: 'Encrypted before it leaves the phone',
          body: 'X25519 key exchange + AES-256-GCM. The server only ever '
              'stores ciphertext.',
        ),
        _Point(
          icon: Icons.visibility_off_outlined,
          title: 'No live results, not even for the admin',
          body: 'While voting is open, the dashboard shows turnout only. '
              'The decryption key never touches the cloud.',
        ),
        _Point(
          icon: Icons.key,
          title: 'Optional two-key reveal',
          body: 'Split the key between the host and an electoral officer. '
              'Results need both of them.',
        ),
        _Point(
          icon: Icons.person_off_outlined,
          title: 'Who voted ≠ what was voted',
          body: 'Voter records and ballots are stored separately with nothing '
              'linking them together.',
        ),
        _Point(
          icon: Icons.receipt_long_outlined,
          title: 'Verifiable receipts',
          body: 'Every voter gets a receipt code to confirm their ballot was '
              'counted, without revealing their choice.',
        ),
      ],
    );

    final dark = Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: s.inverseSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What the database actually sees',
              style: t.titleMedium?.copyWith(
                  color: s.onInverseSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          for (final line in const [
            'ballots/k2P9x… {',
            '  epk:   "m4Tz9cQ1…",',
            '  nonce: "7sLq0b…",',
            '  ct:    "9fA3x0Lq+e2Rk7…",',
            '  mac:   "Qx7h2Lw0…"',
            '}',
          ])
            Text(line,
                style: TextStyle(
                    fontFamily: 'monospace',
                    color: s.onInverseSurface.withValues(alpha: .85),
                    height: 1.6)),
          const SizedBox(height: 20),
          Text('No name. No matric number. No timestamp. No readable choice.',
              style: TextStyle(color: s.inversePrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );

    return _Section(
      color: s.surface,
      child: Column(
        children: [
          const _SectionTitle(
            eyebrow: 'Security',
            title: 'Built so even we can\'t see your vote',
            subtitle: 'Most online polls trust whoever runs the server. '
                'CampusVote is designed so the server never has anything '
                'worth reading.',
          ),
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: points),
                    const SizedBox(width: 48),
                    Expanded(child: dark),
                  ],
                )
              : Column(children: [points, const SizedBox(height: 24), dark]),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _Point({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: s.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: s.onPrimaryContainer, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- features

class _Features extends StatelessWidget {
  final bool wide;

  const _Features({required this.wide});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return _Section(
      color: s.surfaceContainerLow,
      child: Column(
        children: [
          const _SectionTitle(
            eyebrow: 'Made for campuses',
            title: 'Everything an electoral committee needs',
          ),
          _ResponsiveRow(
            wide: wide,
            children: const [
              _StepCard(
                n: 1,
                icon: Icons.badge_outlined,
                title: 'Matric-number eligibility',
                body: 'Only students on your list can vote, and each matric '
                    'number works exactly once.',
              ),
              _StepCard(
                n: 2,
                icon: Icons.schedule,
                title: 'Automatic voting window',
                body: 'Voting opens and closes on schedule, enforced by the '
                    'server clock, not the user\'s phone.',
              ),
              _StepCard(
                n: 3,
                icon: Icons.insights_outlined,
                title: 'Live turnout & audit',
                body: 'Watch turnout climb, and publish results with a '
                    'ballots-vs-voters integrity check.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- cta + footer

class _FinalCta extends StatelessWidget {
  final VoidCallback onHost;
  final VoidCallback onJoin;

  const _FinalCta({required this.onHost, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return _Section(
      color: s.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 56),
        decoration: BoxDecoration(
          color: s.primary,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Text('Ready to run a fair election?',
                textAlign: TextAlign.center,
                style: t.headlineMedium?.copyWith(
                    color: s.onPrimary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Set one up in minutes, or jump into the one you were invited to.',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: s.onPrimary.withValues(alpha: .85))),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onHost,
                  style: FilledButton.styleFrom(
                    backgroundColor: s.onPrimary,
                    foregroundColor: s.primary,
                    minimumSize: const Size(200, 52),
                  ),
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  label: const Text('Login as host'),
                ),
                OutlinedButton.icon(
                  onPressed: onJoin,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: s.onPrimary,
                    side: BorderSide(color: s.onPrimary),
                    minimumSize: const Size(200, 52),
                  ),
                  icon: const Icon(Icons.how_to_vote_outlined),
                  label: const Text('Join an election'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return _Section(
      vPad: 32,
      color: s.surfaceContainerLow,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          const _Logo(),
          Text('© ${DateTime.now().year} ${AppConfig.appName} · Confidential student elections',
              style: TextStyle(color: s.onSurfaceVariant, fontSize: 13)),
        ],
      ),
    );
  }
}