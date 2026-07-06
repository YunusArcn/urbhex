import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kimlik islemleri: Google OAuth + e-posta/sifre (dogrulama mailli).
class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<AuthState> get onAuthChange => _client.auth.onAuthStateChange;

  /// Web'de giris/dogrulama sonrasi DONULECEK adres: o an calisilan origin.
  /// (Gelistirmede http://localhost:3000, canlida https://urbhex.com —
  ///  boylece Supabase'in Site URL'i ne olursa olsun dogru yere donulur.
  ///  Adresin Supabase > Auth > URL Configuration'da izinli olmasi gerekir.)
  String? get _redirect => kIsWeb ? Uri.base.origin : null;

  /// Google ile giris — Supabase yonlendirmeli OAuth (sayfa yonlenir, geri gelir).
  Future<void> signInWithGoogle() => _client.auth
      .signInWithOAuth(OAuthProvider.google, redirectTo: _redirect);

  /// Kayit: Supabase dogrulama e-postasi gonderir; kullanici onaylayana
  /// kadar oturum acilmaz (Dashboard'da "Confirm email" acik olmali).
  /// displayName, profiles tablosuna trigger uzerinden otomatik yazilir.
  Future<void> signUp(String email, String password, {String? displayName}) =>
      _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _redirect,
        data: displayName != null && displayName.isNotEmpty
            ? {'full_name': displayName}
            : null,
      );

  Future<void> signIn(String email, String password) =>
      _client.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    return _client.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  Future<void> updateProfile({String? displayName, String? avatarUrl}) async {
    final user = currentUser;
    if (user == null) return;
    await _client.from('profiles').update({
      if (displayName != null) 'display_name': displayName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', user.id);
  }
}
