import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_profile');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<dynamic> get(String url) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      throw _cleanErrorMessage(e);
    }
  }

  static Future<dynamic> post(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      throw _cleanErrorMessage(e);
    }
  }

  static Future<dynamic> put(String url, Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      throw _cleanErrorMessage(e);
    }
  }

  static Future<dynamic> delete(String url) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      throw _cleanErrorMessage(e);
    }
  }

  static String _cleanErrorMessage(dynamic e) {
    var msg = e.toString().replaceFirst('Exception: ', '');
    return msg;
  }

  static dynamic _processResponse(http.Response response) {
    String decodedBody;
    try {
      decodedBody = utf8.decode(response.bodyBytes);
    } catch (_) {
      decodedBody = response.body;
    }

    dynamic body;
    try {
      body = jsonDecode(decodedBody);
    } catch (_) {
      body = {'message': decodedBody};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    } else {
      String msg = 'Đã có lỗi xảy ra (${response.statusCode})';
      if (body is Map && body['message'] != null) {
        msg = body['message'].toString();
      }
      throw Exception(msg);
    }
  }
}
