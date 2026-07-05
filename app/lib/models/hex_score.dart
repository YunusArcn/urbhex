/// hex_scores view satiri: bir H3 altigeninin skoru, merkezi ve baskin olay turu.
class HexScore {
  final String h3Res9;
  final String h3Res7; // kumeleme (cluster) grubu
  final double lat;
  final double lng;
  final int incidentCount;
  final String topEventType; // haritada gosterilecek ikonun turu
  final double riskScore;
  final int safetyScore; // 1-100 (100 = en guvenli/yesil)

  const HexScore({
    required this.h3Res9,
    required this.h3Res7,
    required this.lat,
    required this.lng,
    required this.incidentCount,
    required this.topEventType,
    required this.riskScore,
    required this.safetyScore,
  });

  factory HexScore.fromJson(Map<String, dynamic> json) => HexScore(
        h3Res9: json['h3_res9'] as String,
        h3Res7: json['h3_res7'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        incidentCount: (json['incident_count'] as num).toInt(),
        topEventType: json['top_event_type'] as String? ?? 'diger',
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
        safetyScore: (json['safety_score'] as num?)?.toInt() ?? 100,
      );
}
