import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/providers/cloud_providers.dart';
import '../../app/theme/app_colors.dart';
import '../../data/remote/auth_service.dart';

/// Email/password, magic-link and Google sign-in.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _creatingAccount = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final runtime = ref.watch(cloudRuntimeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                  ),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  size: 40,
                  color: Color(0xFF052012),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sync across every device',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Your habits stay on this device. Sign in to keep them in sync '
              'with your phone, tablet and Windows laptop.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (!runtime.configured)
              _NotConfiguredCard(theme: theme)
            else ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Sign in')),
                  ButtonSegment(value: true, label: Text('Create account')),
                ],
                selected: {_creatingAccount},
                showSelectedIcon: false,
                onSelectionChanged: (selection) {
                  setState(() {
                    _creatingAccount = selection.first;
                    _error = null;
                    _message = null;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    onPressed: () => setState(
                      () => _obscurePassword = !_obscurePassword,
                    ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: const TextStyle(color: AppColors.green),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy
                    ? null
                    : (_creatingAccount ? _signUp : _signIn),
                child: _busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _creatingAccount ? 'Create account' : 'Sign in',
                      ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _sendMagicLink,
                icon: const Icon(Icons.mark_email_unread_outlined),
                label: const Text('Email me a magic link'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _google,
                icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 18),
              Text(
                'Magic links open back in HabitPulse via '
                '${AuthService.redirectUrl}. On Windows, email + password '
                'is the most reliable option.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function(AuthService auth) action) async {
    final auth = ref.read(authServiceProvider);
    if (auth == null) return;

    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });

    try {
      await action(auth);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _validCredentials() {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return false;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return false;
    }
    return true;
  }

  Future<void> _signIn() async {
    if (!_validCredentials()) return;
    await _run((auth) async {
      await auth.signIn(email: _email.text.trim(), password: _password.text);
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _signUp() async {
    if (!_validCredentials()) return;
    await _run((auth) async {
      final response = await auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pop();
      } else {
        setState(
          () => _message =
              'Check your email to confirm your account, then sign in.',
        );
      }
    });
  }

  Future<void> _sendMagicLink() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    await _run((auth) async {
      await auth.sendMagicLink(_email.text.trim());
      if (mounted) {
        setState(() => _message = 'Magic link sent. Check your inbox.');
      }
    });
  }

  Future<void> _google() async {
    await _run((auth) async {
      final opened = await auth.signInWithGoogle();
      if (!opened && mounted) {
        setState(() => _error = 'Could not open Google sign-in.');
      }
    });
  }
}

class _NotConfiguredCard extends StatelessWidget {
  const _NotConfiguredCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud sync is not configured', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Add SUPABASE_URL and SUPABASE_ANON_KEY to the .env file, '
              'restart the app, then come back here. See SETUP_SUPABASE.md.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
