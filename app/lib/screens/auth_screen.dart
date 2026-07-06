import 'package:flutter/material.dart';

import '../services/analytics/analytics.dart';
import '../services/auth_service.dart';

/// Giris / kayit ekrani — iki mod ayri kurgulanmistir:
///  Giris : e-posta + sifre
///  Kayit : ad soyad + e-posta + sifre + sifre tekrar (dogrulama mailli)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  bool _registerMode = false;
  bool _busy = false;
  bool _obscure = true;
  bool _termsAccepted = false;
  String? _error;
  String? _info;

  static const _termsText = '''
SORUMLULUK REDDİ BEYANI

1. Urbhex, yalnızca kamuya açık haber kaynaklarında YAYIMLANMIŞ içerikleri
otomatik olarak toplayıp harita üzerinde görselleştiren bir platformdur.
Haber üretmez, haberleri doğrulamaz; içeriğin doğruluğu kaynak sitelere aittir.

2. Bir bölge için gösterilen veriler, o bölgeyle ilgili ERİŞİLEBİLEN
haberlerle sınırlıdır ve gerçek olay sayısını tam yansıtmayabilir. Haritada
haber görünmemesi "olay yaşanmadığı" anlamına gelmez; haber görünmesi tek
başına "bölge güvensizdir" anlamına gelmez.

3. Güvenlik skorları, haber verisinden üretilen İSTATİSTİKSEL göstergelerdir;
kesinlik veya garanti içermez.

4. Platformdaki hiçbir içerik emlak, yatırım, taşınma, kiralama veya kişisel
güvenlik TAVSİYESİ değildir. Platformun tek amacı yayımlanmış haberleri
harita üzerinde görünür kılmaktır. Bu bilgilere dayanarak alınan her türlü
karar ve sonuçları münhasıran KULLANICIYA aittir.

5. Olay konumları, kişisel veri içermeyecek şekilde yaklaşık bölge (altıgen)
merkezine yerleştirilir; açık adres ve kişi bilgisi saklanmaz (KVKK).

6. Urbhex; verilerin kullanımından doğabilecek doğrudan veya dolaylı hiçbir
zarardan sorumlu tutulamaz. Ayrıntı için her olay kartındaki orijinal haber
kaynağına başvurunuz.

Kayıt olarak bu beyanı okuduğunuzu ve kabul ettiğinizi onaylarsınız.''';

  void _showTerms() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sorumluluk Reddi Beyanı'),
        content: const SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Text(_termsText, style: TextStyle(fontSize: 13, height: 1.45)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat')),
          FilledButton(
            onPressed: () {
              setState(() => _termsAccepted = true);
              Navigator.pop(context);
            },
            child: const Text('Okudum, kabul ediyorum'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_registerMode && !_termsAccepted) {
      setState(() => _error =
          'Kayıt için Sorumluluk Reddi Beyanı\'nı okuyup onaylaman gerekiyor.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      if (_registerMode) {
        await _auth.signUp(
          _email.text.trim(),
          _password.text,
          displayName: _name.text.trim(),
        );
        Analytics.capture('sign_up');
        setState(() {
          _info = 'Hesabın oluşturuldu! ${_email.text.trim()} adresine '
              'doğrulama linki gönderdik. Linke tıkladıktan sonra buradan '
              'giriş yapabilirsin.';
          _registerMode = false;
        });
      } else {
        await _auth.signIn(_email.text.trim(), _password.text);
        final user = _auth.currentUser;
        if (user != null) Analytics.identify(user.id, {'email': user.email});
        Analytics.capture('login', {'method': 'email'});
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _error = _humanize(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Supabase hata metinlerini kullanicinin anlayacagi dile cevirir.
  String _humanize(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'E-postan henüz doğrulanmamış — gelen kutundaki linke tıkla '
          '(spam klasörünü de kontrol et).';
    }
    if (raw.contains('already registered')) {
      return 'Bu e-posta zaten kayıtlı — giriş yapmayı dene.';
    }
    if (raw.contains('rate limit') || raw.contains('Too many')) {
      return 'Çok fazla deneme yapıldı — birkaç dakika bekleyip tekrar dene.';
    }
    return 'İşlem başarısız: ${raw.length > 120 ? raw.substring(0, 120) : raw}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.hexagon, size: 52, color: Color(0xFF1B5E20)),
                  const SizedBox(height: 6),
                  Text.rich(
                    const TextSpan(children: [
                      TextSpan(text: 'urb', style: TextStyle(fontWeight: FontWeight.w300)),
                      TextSpan(
                          text: 'hex',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, color: Color(0xFF1B5E20))),
                    ]),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  Text(
                    _registerMode
                        ? 'Ücretsiz hesap oluştur; bölgeni favorile, gelişmeleri kaçırma.'
                        : 'Tekrar hoş geldin!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),

                  // Mod secici: Giris / Kayit gorsel olarak net ayrilir.
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                          value: false,
                          label: Text('Giriş Yap'),
                          icon: Icon(Icons.login)),
                      ButtonSegment(
                          value: true,
                          label: Text('Kayıt Ol'),
                          icon: Icon(Icons.person_add_alt)),
                    ],
                    selected: {_registerMode},
                    onSelectionChanged: (s) => setState(() {
                      _registerMode = s.first;
                      _error = null;
                      _info = null;
                    }),
                  ),
                  const SizedBox(height: 20),

                  if (_registerMode) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().length < 3) ? 'Adını yaz' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Geçerli bir e-posta gir'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      helperText: _registerMode ? 'En az 6 karakter' : null,
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                  ),
                  if (_registerMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password2,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Şifre (tekrar)',
                        prefixIcon: Icon(Icons.lock_reset),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v != _password.text ? 'Şifreler aynı değil' : null,
                    ),
                    const SizedBox(height: 10),
                    // Yasal onay: beyan okunup kabul edilmeden kayit olmaz.
                    Row(children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (v) =>
                            setState(() => _termsAccepted = v ?? false),
                      ),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _showTerms,
                              child: const Text(
                                'Sorumluluk Reddi Beyanı\'nı',
                                style: TextStyle(
                                  color: Color(0xFF1B5E20),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const Text(' okudum, kabul ediyorum.'),
                          ],
                        ),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 18),

                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(
                            _registerMode
                                ? 'Hesap Oluştur'
                                : 'Giriş Yap',
                            style: const TextStyle(fontSize: 15)),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('veya', style: TextStyle(fontSize: 12)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                  ),

                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _auth.signInWithGoogle(),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13)),
                    icon: const Icon(Icons.g_mobiledata, size: 26),
                    label: Text(_registerMode
                        ? 'Google ile kayıt ol'
                        : 'Google ile giriş yap'),
                  ),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        Icon(Icons.error_outline,
                            color: theme.colorScheme.onErrorContainer, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 13)),
                        ),
                      ]),
                    ),
                  if (_info != null)
                    Container(
                      margin: const EdgeInsets.only(top: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        Icon(Icons.mark_email_read_outlined,
                            color: Colors.green.shade800, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_info!,
                              style: TextStyle(
                                  color: Colors.green.shade900, fontSize: 13)),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }
}
