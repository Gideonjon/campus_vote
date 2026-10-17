import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../config.dart';

// =============================================================================
// Palette — warm brown + cream, in the style of userank.com.
// Change these few values to re-skin the whole page.
// =============================================================================
class _C {
  static const ink = Color(0xFF26120A); // deep brown (headings, dark bands)
  static const inkSoft = Color(0xFF5B463C); // body text
  static const cream = Color(0xFFFFF8F0); // page background
  static const sand = Color(0xFFF6EADB); // alternate section background
  static const card = Color(0xFFFFFFFF);
  static const line = Color(0xFFEADBC8); // borders
  static const accent = Color(0xFFFF6A2B); // warm orange
  static const accentSoft = Color(0xFFFFE3D3);
  static const onDark = Color(0xFFFFF3E8);
  static const onDarkSoft = Color(0xFFCDB8A9);
}

const _maxW = 1180.0;

/// Marketing landing page for the web build ("/" on web).
class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> {
  final _howKey = GlobalKey();
  final _safeKey = GlobalKey();
  final _faqKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
    }
  }

  void _hostLogin() {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    context.go(signedIn ? '/host' : '/login');
  }

  void _join() => showJoinElectionDialog(context);

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Force the warm light look regardless of the device's dark mode.
      data: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _C.accent,
          primary: _C.ink,
          surface: _C.cream,
        ),
        scaffoldBackgroundColor: _C.cream,
      ),
      child: Scaffold(
        backgroundColor: _C.cream,
        body: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 960;
          final actions = _Actions(onHost: _hostLogin, onJoin: _join);
          return Column(
            children: [
              _NavBar(
                wide: wide,
                actions: actions,
                onHow: () => _scrollTo(_howKey),
                onSafe: () => _scrollTo(_safeKey),
                onFaq: () => _scrollTo(_faqKey),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _Hero(wide: wide, actions: actions),
                      const _StatementBand(),
                      _NumberedFeatures(
                        key: _howKey,
                        wide: wide,
                        actions: actions,
                        onSecurity: () => _scrollTo(_safeKey),
                      ),
                      _Numbers(wide: wide),
                      _SafeSection(key: _safeKey, wide: wide),
                      _Difference(wide: wide),
                      _WhoItsFor(wide: wide),
                      _Faq(key: _faqKey),
                      _CtaBand(wide: wide, actions: actions),
                      _Footer(wide: wide, actions: actions),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _Actions {
  final VoidCallback onHost;
  final VoidCallback onJoin;

  const _Actions({required this.onHost, required this.onJoin});
}

// =============================================================================
// Join dialog (also usable from elsewhere)
// =============================================================================

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
    return Dialog(
      backgroundColor: _C.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Join an election',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 8),
              const Text(
                'Paste the link your electoral committee shared, or type the '
                'election code.',
                style: TextStyle(color: _C.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Link or election code',
                  prefixIcon: const Icon(Icons.link),
                  errorText: _error,
                  filled: true,
                  fillColor: _C.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.line),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _C.line),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _PillButton.outline(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PillButton.dark(label: 'Continue', onTap: _submit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Building blocks
// =============================================================================

class _Section extends StatelessWidget {
  final Widget child;
  final Color color;
  final double v;

  const _Section({required this.child, this.color = _C.cream, this.v = 112});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final h = w < 600 ? 20.0 : 32.0;
    return Container(
      width: double.infinity,
      color: color,
      padding: EdgeInsets.symmetric(horizontal: h, vertical: w < 600 ? v * .55 : v),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: child,
        ),
      ),
    );
  }
}

/// Big, tight, heavy heading used throughout.
class _H extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  const _H(this.text,
      {this.size = 48, this.color = _C.ink, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final s = w < 600 ? size * .62 : (w < 960 ? size * .8 : size);
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontSize: s,
        height: 1.04,
        fontWeight: FontWeight.w800,
        letterSpacing: -s * .035,
        color: color,
      ),
    );
  }
}

class _P extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  const _P(this.text,
      {this.size = 18, this.color = _C.inkSoft, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: size, height: 1.6, color: color),
      );
}

enum _PillStyle { dark, accent, outline, light, ghostLight }

class _PillButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final _PillStyle style;
  final bool large;

  const _PillButton._(this.label, this.onTap, this.icon, this.style, this.large);

  factory _PillButton.dark({required String label, required VoidCallback onTap, IconData? icon, bool large = false}) =>
      _PillButton._(label, onTap, icon, _PillStyle.dark, large);
  factory _PillButton.accent({required String label, required VoidCallback onTap, IconData? icon, bool large = false}) =>
      _PillButton._(label, onTap, icon, _PillStyle.accent, large);
  factory _PillButton.outline({required String label, required VoidCallback onTap, IconData? icon, bool large = false}) =>
      _PillButton._(label, onTap, icon, _PillStyle.outline, large);
  factory _PillButton.light({required String label, required VoidCallback onTap, IconData? icon, bool large = false}) =>
      _PillButton._(label, onTap, icon, _PillStyle.light, large);
  factory _PillButton.ghostLight({required String label, required VoidCallback onTap, IconData? icon, bool large = false}) =>
      _PillButton._(label, onTap, icon, _PillStyle.ghostLight, large);

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (widget.style) {
      _PillStyle.dark => (_C.ink, _C.onDark, _C.ink),
      _PillStyle.accent => (_C.accent, Colors.white, _C.accent),
      _PillStyle.outline => (Colors.transparent, _C.ink, _C.ink),
      _PillStyle.light => (_C.onDark, _C.ink, _C.onDark),
      _PillStyle.ghostLight => (Colors.transparent, _C.onDark, _C.onDark),
    };
    final pad = widget.large
        ? const EdgeInsets.symmetric(horizontal: 28, vertical: 18)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: pad,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
            boxShadow: _hover && widget.style != _PillStyle.outline
                ? [BoxShadow(color: bg.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8))]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.label,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: widget.large ? 16 : 14,
                  )),
              if (widget.icon != null) ...[
                const SizedBox(width: 8),
                Icon(widget.icon, color: fg, size: widget.large ? 20 : 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  final bool light;

  const _Logo({this.light = false});

  @override
  Widget build(BuildContext context) {
    final fg = light ? _C.onDark : _C.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _C.accent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.how_to_vote_rounded, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(AppConfig.appName,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: fg, letterSpacing: -.5)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String badge;
  final String text;

  const _Tag({required this.badge, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _C.accent, borderRadius: BorderRadius.circular(999)),
            child: Text(badge,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(text,
                style: const TextStyle(
                    color: _C.ink, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Nav
// =============================================================================

class _NavBar extends StatelessWidget {
  final bool wide;
  final _Actions actions;
  final VoidCallback onHow;
  final VoidCallback onSafe;
  final VoidCallback onFaq;

  const _NavBar({
    required this.wide,
    required this.actions,
    required this.onHow,
    required this.onSafe,
    required this.onFaq,
  });

  Widget _link(String t, VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: _C.ink),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.cream.withValues(alpha: .96),
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Row(
            children: [
              const _Logo(),
              if (wide) ...[
                const SizedBox(width: 40),
                _link('How it works', onHow),
                _link('Security', onSafe),
                _link('FAQs', onFaq),
              ],
              const Spacer(),
              if (wide) ...[
                _PillButton.outline(label: 'Join election', onTap: actions.onJoin),
                const SizedBox(width: 10),
                _PillButton.dark(label: 'Host login', onTap: actions.onHost),
              ] else ...[
                _PillButton.dark(label: 'Join', onTap: actions.onJoin),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu, color: _C.ink),
                  color: _C.cream,
                  onSelected: (v) {
                    switch (v) {
                      case 'host':
                        actions.onHost();
                      case 'how':
                        onHow();
                      case 'safe':
                        onSafe();
                      default:
                        onFaq();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'host', child: Text('Host login')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'how', child: Text('How it works')),
                    PopupMenuItem(value: 'safe', child: Text('Security')),
                    PopupMenuItem(value: 'faq', child: Text('FAQs')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Hero
// =============================================================================

class _Hero extends StatelessWidget {
  final bool wide;
  final _Actions actions;

  const _Hero({required this.wide, required this.actions});

  @override
  Widget build(BuildContext context) {
    final align = wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final tAlign = wide ? TextAlign.start : TextAlign.center;

    final copy = Column(
      crossAxisAlignment: align,
      children: [
        const _Tag(badge: 'New', text: 'Two-key result reveal for electoral officers'),
        const SizedBox(height: 28),
        _H('The voting app\nfor campuses.', size: 80, align: tAlign),
        const SizedBox(height: 24),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _P(
            'Run student elections where every ballot is encrypted on the '
            'voter\'s own phone. No live leaks, no admin peeking: results '
            'appear only when voting closes.',
            size: 19,
            align: tAlign,
          ),
        ),
        const SizedBox(height: 36),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _PillButton.accent(
                label: 'Join an election',
                icon: Icons.arrow_forward,
                large: true,
                onTap: actions.onJoin),
            _PillButton.outline(
                label: 'Login as host', large: true, onTap: actions.onHost),
          ],
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 24,
          runSpacing: 10,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: const [
            _Trust(icon: Icons.lock_outline, text: 'AES-256 encrypted'),
            _Trust(icon: Icons.phone_iphone, text: 'No app install to vote'),
            _Trust(icon: Icons.verified_outlined, text: 'Verifiable receipts'),
          ],
        ),
      ],
    );

    return _Section(
      v: 72,
      child: wide
          ? Row(
              children: [
                Expanded(flex: 11, child: copy),
                const SizedBox(width: 48),
                const Expanded(flex: 9, child: _HeroArt()),
              ],
            )
          : Column(children: [copy, const SizedBox(height: 56), const _HeroArt()]),
    );
  }
}

class _Trust extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Trust({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _C.accent),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: _C.ink, fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      );
}

/// Warm blob background with a phone mockup and floating chips.
class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: .95,
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFB98F), _C.accent, Color(0xFFB8431A)],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -w * .06,
              top: -w * .06,
              child: Container(
                width: w * .32,
                height: w * .32,
                decoration: const BoxDecoration(color: _C.sand, shape: BoxShape.circle),
              ),
            ),
            Center(child: _Phone(width: w * .46, child: const _MiniBallot())),
            Positioned(
              left: -w * .04,
              bottom: w * .14,
              child: const _FloatChip(icon: Icons.lock, text: 'Encrypted on device'),
            ),
            Positioned(
              right: -w * .02,
              top: w * .22,
              child: const _FloatChip(icon: Icons.groups_2_outlined, text: '312 of 400 voted'),
            ),
          ],
        );
      }),
    );
  }
}

class _FloatChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FloatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _C.ink.withValues(alpha: .18), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: _C.accentSoft, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: _C.accent),
          ),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Phone extends StatelessWidget {
  final double width;
  final Widget child;

  const _Phone({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 2.0,
      padding: EdgeInsets.all(width * .035),
      decoration: BoxDecoration(
        color: _C.ink,
        borderRadius: BorderRadius.circular(width * .16),
        boxShadow: [
          BoxShadow(color: _C.ink.withValues(alpha: .35), blurRadius: 40, offset: const Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * .13),
        child: ColoredBox(
          color: _C.cream,
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            child: SizedBox(width: 280, height: 560, child: child),
          ),
        ),
      ),
    );
  }
}

/// Fixed-size (280×560) fake ballot rendered inside the phone frame.
class _MiniBallot extends StatelessWidget {
  const _MiniBallot();

  Widget _opt(String name, String bio, {bool on = false}) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: on ? _C.accentSoft : _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: on ? _C.accent : _C.line, width: on ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Icon(on ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 18, color: on ? _C.accent : _C.onDarkSoft),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink, fontSize: 13)),
                  Text(bio, style: const TextStyle(color: _C.inkSoft, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 40, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('NACOS Elections 2026',
              style: TextStyle(color: _C.inkSoft, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('President',
              style: TextStyle(color: _C.ink, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.6)),
          const SizedBox(height: 16),
          _opt('Ada Okon', 'Transparency first', on: true),
          _opt('Emeka Bassey', 'More hackathons'),
          _opt('Ruth Akpan', 'Better welfare'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _C.sand, borderRadius: BorderRadius.circular(12)),
            child: const Text('ct: 9fA3x0Lq+e2Rk7…\nmac: Qx7h2Lw0…',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _C.inkSoft)),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: _C.ink, borderRadius: BorderRadius.circular(999)),
            alignment: Alignment.center,
            child: const Text('Encrypt & submit',
                style: TextStyle(color: _C.onDark, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Dark statement band
// =============================================================================

class _StatementBand extends StatelessWidget {
  const _StatementBand();

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: _C.ink,
      v: 120,
      child: Column(
        children: [
          const _H(
            'Every student deserves\na vote that stays secret.',
            size: 60,
            color: _C.onDark,
            align: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: const _P(
              'Campus elections run on Google Forms and WhatsApp polls let '
              'whoever owns the form see every vote, live. CampusVote locks '
              'each ballot before it leaves the phone, so the only person who '
              'ever sees your choice is you.',
              color: _C.onDarkSoft,
              align: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Numbered feature rows 01–04 (alternating sides)
// =============================================================================

class _NumberedFeatures extends StatelessWidget {
  final bool wide;
  final _Actions actions;
  final VoidCallback onSecurity;

  const _NumberedFeatures({
    super.key,
    required this.wide,
    required this.actions,
    required this.onSecurity,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      _FeatureRow(
        n: '01',
        title: 'Set up an election in minutes.',
        body: 'Add positions, candidates and a voting window. A fresh '
            'encryption key is generated on your device, and only the public '
            'half is uploaded.',
        link: 'Start as a host',
        onLink: actions.onHost,
        art: const _ArtCreate(),
        flip: false,
        wide: wide,
      ),
      _FeatureRow(
        n: '02',
        title: 'Share one link. Vote from any phone.',
        body: 'Drop the link or QR code in the class group. Students open it in '
            'their browser, confirm their matric number and vote. No downloads.',
        link: 'Join an election',
        onLink: actions.onJoin,
        art: const _ArtShare(),
        flip: true,
        wide: wide,
      ),
      _FeatureRow(
        n: '03',
        title: 'Locked before it leaves the phone.',
        body: 'Each ballot is sealed with X25519 + AES-256-GCM on the voter\'s '
            'device. The database only ever holds ciphertext, and the dashboard '
            'shows turnout only.',
        link: 'See how it\'s secured',
        onLink: onSecurity,
        art: const _ArtLock(),
        flip: false,
        wide: wide,
      ),
      _FeatureRow(
        n: '04',
        title: 'Results you can actually verify.',
        body: 'When voting closes, ballots are decrypted on the host\'s device '
            'and published with an audit check. Voters confirm their receipt '
            'code was counted.',
        link: 'Login as host',
        onLink: actions.onHost,
        art: const _ArtResults(),
        flip: true,
        wide: wide,
      ),
    ];

    return _Section(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: wide ? 120 : 72),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String n;
  final String title;
  final String body;
  final String link;
  final VoidCallback onLink;
  final Widget art;
  final bool flip;
  final bool wide;

  const _FeatureRow({
    required this.n,
    required this.title,
    required this.body,
    required this.link,
    required this.onLink,
    required this.art,
    required this.flip,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n,
            style: const TextStyle(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              color: _C.accent,
            )),
        const SizedBox(height: 16),
        _H(title, size: 46),
        const SizedBox(height: 20),
        _P(body),
        const SizedBox(height: 24),
        _TextLink(label: link, onTap: onLink),
      ],
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [art, const SizedBox(height: 32), text],
      );
    }
    final children = [
      Expanded(child: text),
      const SizedBox(width: 72),
      Expanded(child: art),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: flip ? children.reversed.toList() : children,
    );
  }
}

class _TextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.label, required this.onTap});

  @override
  State<_TextLink> createState() => _TextLinkState();
}

class _TextLinkState extends State<_TextLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label,
                style: TextStyle(
                  color: _C.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                  decorationColor: _hover ? _C.accent : _C.ink,
                  decorationThickness: 2,
                )),
            AnimatedPadding(
              duration: const Duration(milliseconds: 150),
              padding: EdgeInsets.only(left: _hover ? 10 : 6),
              child: const Icon(Icons.arrow_forward, size: 18, color: _C.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded "illustration" panel used by the feature rows.
class _ArtPanel extends StatelessWidget {
  final Color color;
  final Widget child;

  const _ArtPanel({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.1,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(36)),
        child: Center(child: child),
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final Widget child;
  final double width;

  const _MockCard({required this.child, this.width = 340});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _C.ink.withValues(alpha: .12), blurRadius: 30, offset: const Offset(0, 16)),
        ],
      ),
      child: child,
    );
  }
}

class _ArtCreate extends StatelessWidget {
  const _ArtCreate();

  Widget _field(String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _C.cream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: _C.inkSoft)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, color: _C.ink)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _ArtPanel(
      color: _C.sand,
      child: FittedBox(
        child: _MockCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New election',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 14),
              _field('Title', 'NACOS UniUyo Executive Elections'),
              _field('Position 1', 'President · 3 candidates'),
              _field('Position 2', 'PRO · 2 candidates'),
              _field('Closes', 'Fri 14 Nov, 6:00 PM'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _C.ink, borderRadius: BorderRadius.circular(999)),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, color: _C.onDark, size: 16),
                    SizedBox(width: 6),
                    Text('Create election',
                        style: TextStyle(color: _C.onDark, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtShare extends StatelessWidget {
  const _ArtShare();

  @override
  Widget build(BuildContext context) {
    return _ArtPanel(
      color: _C.accentSoft,
      child: FittedBox(
        child: _MockCard(
          width: 300,
          child: Column(
            children: [
              const Text('Scan to vote',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 14),
              QrImageView(
                data: '${AppConfig.publicBaseUrl}/e/demo',
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _C.ink),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle, color: _C.ink),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _C.cream, borderRadius: BorderRadius.circular(999)),
                child: const Text('campusvote.web.app/e/7Gk2PqX9',
                    style: TextStyle(fontSize: 12, color: _C.inkSoft, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtLock extends StatelessWidget {
  const _ArtLock();

  @override
  Widget build(BuildContext context) {
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 13, color: _C.onDarkSoft, height: 1.7);
    return _ArtPanel(
      color: _C.ink,
      child: FittedBox(
        child: SizedBox(
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.radio_button_checked, color: _C.accent),
                    SizedBox(width: 10),
                    Text('President → Ada Okon',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _C.ink)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Icon(Icons.lock, color: _C.accent, size: 36),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.inkSoft),
                ),
                child: const Text(
                  'ballots/k2P9x… {\n'
                  '  epk: "m4Tz9cQ1…",\n'
                  '  ct:  "9fA3x0Lq+e2Rk7…",\n'
                  '  mac: "Qx7h2Lw0…"\n'
                  '}',
                  style: mono,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtResults extends StatelessWidget {
  const _ArtResults();

  Widget _bar(String name, int votes, double pct, {bool win = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (win) ...[
                  const Icon(Icons.emoji_events, size: 16, color: _C.accent),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontWeight: win ? FontWeight.w800 : FontWeight.w600, color: _C.ink)),
                ),
                Text('$votes', style: const TextStyle(color: _C.inkSoft, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: _C.sand,
                color: win ? _C.accent : _C.ink,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _ArtPanel(
      color: _C.sand,
      child: FittedBox(
        child: _MockCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('President: results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
              const SizedBox(height: 16),
              _bar('Ada Okon', 168, .54, win: true),
              _bar('Emeka Bassey', 97, .31),
              _bar('Ruth Akpan', 47, .15),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _C.accentSoft, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.verified, size: 16, color: _C.accent),
                    SizedBox(width: 6),
                    Text('312 ballots · 312 voters · check passed',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.ink)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Numbers strip
// =============================================================================

class _Numbers extends StatelessWidget {
  final bool wide;

  const _Numbers({required this.wide});

  @override
  Widget build(BuildContext context) {
    const items = [
      ('256-bit', 'AES-GCM encryption on every ballot'),
      ('0', 'apps to install for voters'),
      ('1', 'vote per matric number, enforced by the server'),
      ('2', 'keys needed to reveal results (optional)'),
    ];
    return _Section(
      color: _C.sand,
      v: 88,
      child: Wrap(
        spacing: 24,
        runSpacing: 40,
        alignment: WrapAlignment.spaceBetween,
        children: [
          for (final (big, small) in items)
            SizedBox(
              width: wide ? 250 : 280,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _H(big, size: 64, color: _C.accent),
                  const SizedBox(height: 8),
                  _P(small, size: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// How we keep your vote safe (3 columns)
// =============================================================================

class _SafeSection extends StatelessWidget {
  final bool wide;

  const _SafeSection({super.key, required this.wide});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.phonelink_lock, 'Encrypted on your device',
          'Your choices are sealed on your phone before anything is sent. The server never sees plain text.'),
      (Icons.visibility_off_outlined, 'No live results',
          'While voting is open, nobody (not the host, not the developer) can see who is leading.'),
      (Icons.person_off_outlined, 'Who ≠ what',
          'The record that you voted and your encrypted ballot are stored apart, with nothing linking them.'),
      (Icons.key_outlined, 'Two-key reveal',
          'Split the decryption key between the host and an electoral officer so neither can open results alone.'),
      (Icons.schedule, 'Server-enforced window',
          'Voting opens and closes by the server clock. Changing your phone\'s time won\'t help.'),
      (Icons.receipt_long_outlined, 'Receipts for everyone',
          'Every voter gets a code to confirm their ballot was counted, without revealing the choice.'),
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _H('How we keep\nyour vote safe.', size: 56)),
                    SizedBox(width: 48),
                    Expanded(
                      child: _P('Security isn\'t a setting you switch on. It\'s '
                          'how CampusVote is built, from the first tap to the final count.'),
                    ),
                  ],
                )
              : const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _H('How we keep your vote safe.', size: 56),
                    SizedBox(height: 16),
                    _P('Security isn\'t a setting you switch on. It\'s how '
                        'CampusVote is built, from the first tap to the final count.'),
                  ],
                ),
          const SizedBox(height: 64),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 560 ? 2 : 1);
            final w = (c.maxWidth - (cols - 1) * 40) / cols;
            return Wrap(
              spacing: 40,
              runSpacing: 48,
              children: [
                for (final (icon, title, body) in items)
                  SizedBox(
                    width: w,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: _C.accentSoft, borderRadius: BorderRadius.circular(14)),
                          child: Icon(icon, color: _C.accent, size: 26),
                        ),
                        const SizedBox(height: 18),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
                        const SizedBox(height: 8),
                        _P(body, size: 16),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// The CampusVote difference (dark, three blocks)
// =============================================================================

class _Difference extends StatelessWidget {
  final bool wide;

  const _Difference({required this.wide});

  @override
  Widget build(BuildContext context) {
    const blocks = [
      ('Private by design', 'Other tools promise not to look. CampusVote makes it impossible to look.'),
      ('Fair by default', 'One matric number, one vote, inside a fixed window. Every time, no exceptions.'),
      ('Open to audit', 'Published totals, a ballots-vs-voters check and personal receipts anyone can verify.'),
    ];
    return _Section(
      color: _C.ink,
      child: Column(
        children: [
          const _H('The CampusVote difference.', size: 56, color: _C.onDark, align: TextAlign.center),
          const SizedBox(height: 64),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 860 ? 3 : 1;
            final w = (c.maxWidth - (cols - 1) * 24) / cols;
            return Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                for (var i = 0; i < blocks.length; i++)
                  Container(
                    width: w,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: .1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('0${i + 1}',
                            style: const TextStyle(
                                color: _C.accent,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w700,
                                fontSize: 18)),
                        const SizedBox(height: 40),
                        Text(blocks[i].$1,
                            style: const TextStyle(
                                color: _C.onDark,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.8)),
                        const SizedBox(height: 12),
                        _P(blocks[i].$2, size: 16, color: _C.onDarkSoft),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// Who it's for
// =============================================================================

class _WhoItsFor extends StatelessWidget {
  final bool wide;

  const _WhoItsFor({required this.wide});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.account_balance_outlined, 'Student associations',
          'Departmental and faculty executive elections, from NACOS to SUG.', _C.sand),
      (Icons.apartment_outlined, 'Hostels & halls',
          'Hall reps, floor reps and welfare officers, with voting from your room.', _C.accentSoft),
      (Icons.groups_outlined, 'Clubs & communities',
          'Tech communities, fellowships and societies choosing their leads.', _C.sand),
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _H('Built for every\nelection on campus.', size: 56),
          const SizedBox(height: 56),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 860 ? 3 : 1;
            final w = (c.maxWidth - (cols - 1) * 20) / cols;
            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                for (final (icon, title, body, bg) in items)
                  Container(
                    width: w,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 40, color: _C.ink),
                        const SizedBox(height: 48),
                        Text(title,
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w800, color: _C.ink, letterSpacing: -.6)),
                        const SizedBox(height: 10),
                        _P(body, size: 16),
                      ],
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// =============================================================================
// FAQ accordion
// =============================================================================

class _Faq extends StatelessWidget {
  const _Faq({super.key});

  static const _qs = [
    ('Do voters need to install an app?',
        'No. Voters open the link in any phone browser, sign in with email, confirm their matric number and vote. Only hosts may choose to use the mobile app.'),
    ('Can the host see who is winning before voting ends?',
        'No. Ballots are encrypted on each voter\'s phone and the dashboard only shows turnout. With two-key mode on, the host can\'t decrypt alone even after voting closes.'),
    ('How do you stop someone from voting twice?',
        'Each matric number on the voter list can be used exactly once, and each account can vote once. The database security rules reject any second attempt.'),
    ('What happens if the host loses the key?',
        'The key is never stored in the cloud, so results could not be revealed. That\'s why hosts must back up their key when they create an election.'),
    ('How do I know my vote was counted?',
        'After voting you get a receipt code. When results are published, enter it on the results page to confirm your ballot was included.'),
    ('Is it free?',
        'Yes. CampusVote runs on Firebase\'s free tier, which comfortably handles departmental and faculty elections.'),
  ];

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: _C.sand,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              const _H('Frequently asked questions', size: 52, align: TextAlign.center),
              const SizedBox(height: 48),
              for (final (q, a) in _qs) _FaqItem(q: q, a: a),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String q;
  final String a;

  const _FaqItem({required this.q, required this.a});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _C.card, borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.q,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700, color: _C.ink)),
                  ),
                  const SizedBox(width: 16),
                  AnimatedRotation(
                    turns: _open ? .125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _open ? _C.accent : _C.sand,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.add, size: 20, color: _open ? Colors.white : _C.ink),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12, right: 50),
                        child: _P(widget.a, size: 16),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CTA band with QR
// =============================================================================

class _CtaBand extends StatelessWidget {
  final bool wide;
  final _Actions actions;

  const _CtaBand({required this.wide, required this.actions});

  @override
  Widget build(BuildContext context) {
    final copy = Column(
      crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        _H('Join the new way\ncampuses vote.',
            size: 60, color: _C.onDark, align: wide ? TextAlign.start : TextAlign.center),
        const SizedBox(height: 20),
        _P('Host your first election in minutes, or jump into the one you were invited to.',
            color: _C.onDarkSoft, align: wide ? TextAlign.start : TextAlign.center),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _PillButton.accent(
                label: 'Join an election', icon: Icons.arrow_forward, large: true, onTap: actions.onJoin),
            _PillButton.ghostLight(label: 'Login as host', large: true, onTap: actions.onHost),
          ],
        ),
      ],
    );

    final qr = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _C.onDark, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: AppConfig.publicBaseUrl,
            size: 170,
            backgroundColor: _C.onDark,
            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _C.ink),
            dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square, color: _C.ink),
          ),
          const SizedBox(height: 10),
          const Text('Scan to open on your phone',
              style: TextStyle(color: _C.ink, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );

    return Container(
      color: _C.cream,
      padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 16, vertical: wide ? 64 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxW),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: _C.ink, borderRadius: BorderRadius.circular(40)),
            child: Stack(
              children: [
                Positioned(
                  right: -80,
                  bottom: -120,
                  child: Container(
                    width: 360,
                    height: 360,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.accent.withValues(alpha: .18),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(wide ? 72 : 32),
                  child: wide
                      ? Row(children: [Expanded(child: copy), const SizedBox(width: 48), qr])
                      : Column(children: [copy, const SizedBox(height: 40), qr]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Footer
// =============================================================================

class _Footer extends StatelessWidget {
  final bool wide;
  final _Actions actions;

  const _Footer({required this.wide, required this.actions});

  Widget _col(String title, List<(String, VoidCallback?)> links) => SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: _C.ink, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 16),
            for (final (label, onTap) in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: onTap,
                  child: Text(label, style: const TextStyle(color: _C.inkSoft, fontSize: 15)),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return _Section(
      color: _C.sand,
      v: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 48,
            runSpacing: 40,
            alignment: WrapAlignment.spaceBetween,
            children: [
              const SizedBox(
                width: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Logo(),
                    SizedBox(height: 16),
                    _P('Confidential, verifiable elections for student communities.', size: 15),
                  ],
                ),
              ),
              _col('Voters', [
                ('Join an election', actions.onJoin),
                ('Check a receipt', actions.onJoin),
              ]),
              _col('Hosts', [
                ('Login as host', actions.onHost),
                ('Create an election', actions.onHost),
              ]),
              _col('Project', [
                ('University of Uyo', null),
                ('Akwa Ibom, Nigeria', null),
              ]),
            ],
          ),
          const SizedBox(height: 48),
          const Divider(color: _C.line),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} ${AppConfig.appName}. Ballots are '
            'encrypted end-to-end; results are published by each election\'s host.',
            style: const TextStyle(color: _C.inkSoft, fontSize: 13),
          ),
        ],
      ),
    );
  }
}