/// Analitik kopru — platforma gore dogru uygulamayi secer.
/// Web: PostHog JS (index.html'deki snippet). Diger platformlar: sessiz stub.
/// Kullanim: Analytics.capture('hex_tap', {'score': 72});
export 'analytics_stub.dart' if (dart.library.js_interop) 'analytics_web.dart';
