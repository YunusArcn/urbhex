import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Giris / kayit ekrani: Google OAuth + e-posta (dogrulama mailli).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registerMode = false;
  bool _busy = false;
  String? _message;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_registerMode) {
        await _auth.signUp(_email.text.trim(), _password.text);
        setState(() => _message =
            'Doğrulama e-postası gönderildi. Gelen kutunu kontrol edip '
            'linke tıkladıktan sonra giriş yapabilirsin.');
      } else {
        await _auth.signIn(_email.text.trim(), _password.text);
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _message = 'Hata: e-posta/şifre kontrol et. '
          'Kayıt olduysan önce e-postanı doğrula.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_registerMode ? 'Kayıt Ol' : 'Giriş Yap')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.hexagon, size: 56, color: Color(0xFF1B5E20)),
                const SizedBox(height: 8),
                const Text('urbhex', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300)),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _auth.signInWithGoogle(),
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text('Google ile devam et'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('veya e-posta ile'),
                    ),
                    Expanded(child: Divider()),
                  ]),
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'E-posta', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Şifre (en az 6 karakter)',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_registerMode ? 'Kayıt ol' : 'Giriş yap'),
                ),
                TextButton(
                  onPressed: () => setState(() => _registerMode = !_registerMode),
                  child: Text(_registerMode
                      ? 'Zaten hesabın var mı? Giriş yap'
                      : 'Hesabın yok mu? Kayıt ol'),
                ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orange.shade800)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
