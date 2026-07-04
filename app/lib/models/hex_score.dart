/// hex_scores view satiri: bir H3 altigeninin risk skoru ve merkezi.
class HexScore {
  final String h3Res9;
  final double lat;
  final double lng;
  final int incidentCount;
  final double riskScore;

  const HexScore({
    required this.h3Res9,
    required this.lat,
    required this.lng,
    required this.incidentCount,
    required this.riskScore,
  });

  factory HexScore.fromJson(Map<String, dynamic> json) => HexScore(
        h3Res9: json['h3_res9'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        incidentCount: (json['incident_count'] as num).toInt(),
        riskScore: (json['risk_score'] as num?)?.toDouble() ?? 0,
      );

  /// 0-100 arasi guvenlik skoru (yuksek = guvenli).
  int get safetyScore => (100 - riskScore.clamp(0, 100)).round();
}
