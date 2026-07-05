import 'package:flutter/material.dart';

/// Olay turu → ikon eslemesi (harita isaretcileri ve olay kartlari ortak kullanir).
IconData eventTypeIcon(String eventType) => switch (eventType) {
      'cinayet' => Icons.dangerous,
      'silahli_saldiri' => Icons.track_changes,
      'gasp' => Icons.back_hand,
      'yaralama' => Icons.personal_injury,
      'haneye_tecavuz' => Icons.door_front_door,
      'kavga' => Icons.sports_mma,
      'hirsizlik' => Icons.lock_open,
      'uyusturucu' => Icons.medication,
      'trafik_kazasi' => Icons.car_crash,
      _ => Icons.info_outline,
    };

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

  IconData get icon => eventTypeIcon(eventType);

  String get eventTypeLabel => switch (eventType) {
        'cinayet' => 'Cinayet',
        'silahli_saldiri' => 'Silahli Saldiri',
        'gasp' => 'Gasp',
        'yaralama' => 'Yaralama',
        'haneye_tecavuz' => 'Haneye Tecavuz',
        'kavga' => 'Kavga',
        'hirsizlik' => 'Hirsizlik',
        'uyusturucu' => 'Uyusturucu',
        'trafik_kazasi' => 'Trafik Kazasi',
        _ => 'Diger',
      };
}
