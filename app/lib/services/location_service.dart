import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Tarayici/cihaz konumu: harita kullanicinin bulundugu yerden acilir.
/// Izin yoksa veya alinamazsa null doner; harita varsayilan merkezde kalir.
class LocationService {
  static Future<LatLng?> currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // mahalle seviyesi yeterli, pil dostu
          timeLimit: Duration(seconds: 8),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Izin SORMADAN sessiz kontrol: kullanici izni sonradan verdiyse yakalar.
  /// (Tarayici izin kutusunu geç onaylayanlar için otomatik yenileme.)
  static Future<LatLng?> positionIfGranted() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }
}
