import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Allow dynamic override so group members can easily enter their Wi-Fi IP (e.g. http://192.168.1.5:5000)
  static String? _customBaseUrl;

  static void setCustomBaseUrl(String url) {
    if (url.endsWith('/')) {
      _customBaseUrl = url.substring(0, url.length - 1);
    } else {
      _customBaseUrl = url;
    }
  }

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }

    if (kIsWeb) {
      return 'http://localhost:5000';
    }

    try {
      if (Platform.isAndroid) {
        // Android Emulator maps 10.0.2.2 to host machine's localhost
        return 'http://10.0.2.2:5000';
      }
    } catch (_) {}

    return 'http://localhost:5000';
  }

  static String get apiBaseUrl => '$baseUrl/api';

  // Auth endpoints
  static String get login => '$apiBaseUrl/auth/login';
  static String get register => '$apiBaseUrl/auth/register';
  static String get verifyOtp => '$apiBaseUrl/auth/verify-otp';
  static String get faceLogin => '$apiBaseUrl/auth/face-login';
  static String get registerFace => '$apiBaseUrl/auth/register-face';

  // Attendance endpoints
  static String get checkIn => '$apiBaseUrl/attendance/check-in';
  static String get checkOut => '$apiBaseUrl/attendance/check-out';
  static String get todayAttendance => '$apiBaseUrl/attendance/today';
  static String get myHistory => '$apiBaseUrl/attendance/my-history';
  static String get allAttendances => '$apiBaseUrl/attendance/all';
  static String get stats => '$apiBaseUrl/attendance/stats';

  // Management endpoints
  static String get users => '$apiBaseUrl/users';
  static String get updateLocation => '$apiBaseUrl/users/update-location';
  static String get liveLocations => '$apiBaseUrl/users/live-locations';
  static String get departments => '$apiBaseUrl/departments';
  static String get shifts => '$apiBaseUrl/shifts';
  static String get leaveRequests => '$apiBaseUrl/leaverequests';
  static String get videoRooms => '$apiBaseUrl/videocall/rooms';
  static String get createVideoRoom => '$apiBaseUrl/videocall/create';
}
