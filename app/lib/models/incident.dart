/// incidents tablosu satiri: tek bir anonim asayis olayi.
class Incident {
  final String id;
  final DateTime occurredOn;
  final String eventType;
  final String summary;
  final List<String> sourceUrls;

  const Incident({
    required this.id,
    required this.occurredOn,
    required this.eventType,
    required this.summary,
    required this.sourceUrls,
  });

  factory Incident.fromJson(Map<String, dynamic> json) => Incident(
        id: json['id'] as String,
        occurredOn: DateTime.parse(json['occurred_on'] as String),
        eventType: json['event_type'] as String,
        summary: json['summary'] as String,
        sourceUrls: List<String>.from(json['source_urls'] as List),
      );

  /// "Bu olay X farkli kaynak tarafindan dogrulandi" etiketi icin.
  int get sourceCount => sourceUrls.length;

  String get eventTypeLabel => switch (eventType) {
        'cinayet' => 'Cinayet',
        'gasp' => 'Gasp',
        'yaralama' => 'Yaralama',
        'haneye_tecavuz' => 'Haneye Tecavuz',
        'hirsizlik' => 'Hirsizlik',
        'uyusturucu' => 'Uyusturucu',
        _ => 'Diger',
      };
}
