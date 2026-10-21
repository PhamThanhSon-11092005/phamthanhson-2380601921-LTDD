import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String? wifiBSSID;
  final String? wifiName;
  final String address;

  LocationResult({
    required this.latitude,
    required this.longitude,
    this.wifiBSSID,
    this.wifiName,
    required this.address,
  });
}

class LocationService {
  static final NetworkInfo _networkInfo = NetworkInfo();

  static Future<LocationResult> getCurrentLocation() async {
    double lat = 10.8558; // Default Đại học HUTECH Campus (Thu Duc)
    double lng = 106.7853;
    String address = 'Trụ sở công ty (Thu Duc Campus)';

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          lat = position.latitude;
          lng = position.longitude;
          address =
              'Vị trí hiện tại (${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)})';
        }
      }
    } catch (_) {
      // Fallback to default coordinates on simulator / PC
    }

    String? wifiBSSID;
    String? wifiName;
    try {
      wifiBSSID = await _networkInfo.getWifiBSSID();
      wifiName = await _networkInfo.getWifiName();
    } catch (_) {}

    // Mock Wi-Fi for simulator testing if empty
    wifiBSSID ??= 'Office_WiFi_5G';

    return LocationResult(
      latitude: lat,
      longitude: lng,
      wifiBSSID: wifiBSSID,
      wifiName: wifiName ?? 'Mạng Wi-Fi Nội Bộ',
      address: address,
    );
  }
}
