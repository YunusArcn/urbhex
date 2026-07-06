import 'dart:js_interop';

@JS('posthog')
external JSAny? get _posthog;

@JS('posthog.capture')
external void _capture(JSString event, JSAny? props);

@JS('posthog.identify')
external void _identify(JSString id, JSAny? props);

/// Web analitigi: index.html'deki PostHog snippet'ine olay gonderir.
/// Anahtar girilmemisse (posthog yuklenmemisse) sessizce hicbir sey yapmaz.
class Analytics {
  static bool get _ready => _posthog != null;

  static void capture(String event, [Map<String, Object?>? props]) {
    if (!_ready) return;
    try {
      _capture(event.toJS, props?.jsify());
    } catch (_) {/* analitik asla uygulamayi dusurmez */}
  }

  static void identify(String userId, [Map<String, Object?>? props]) {
    if (!_ready) return;
    try {
      _identify(userId.toJS, props?.jsify());
    } catch (_) {}
  }
}
