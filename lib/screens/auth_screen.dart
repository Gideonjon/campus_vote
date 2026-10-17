import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/auth_form.dart';
import '../widgets/common.dart';

/// Host sign in. After success, the router redirect sends the user on.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/')),
        title: const Text('Host account'),
      ),
      body: PageBody(
        maxWidth: 460,
        children: const [
          SectionCard(
            child: AuthForm(
              headline: 'Sign in to host',
              subtitle: 'Create and manage your elections.',
            ),
          ),
        ],
      ),
    );
  }
}
