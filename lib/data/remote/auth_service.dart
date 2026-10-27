import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around Supabase auth.
class AuthService {
  AuthService(this._client);

  static const String redirectUrl =
      'io.supabase.habitpulse://login-callback';

  final SupabaseClient _client;

  bool get isSignedIn => _client.auth.currentUser != null;
  String? get email => _client.auth.currentUser?.email;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectUrl,
    );
  }

  Future<void> sendMagicLink(String email) {
    return _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirectUrl,
    );
  }

  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectUrl,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
