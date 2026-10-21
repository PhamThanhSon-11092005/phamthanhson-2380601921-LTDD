import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_constants.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/face_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _pendingEmail;
  String? _lastDebugOtp;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  String? get pendingEmail => _pendingEmail;
  String? get lastDebugOtp => _lastDebugOtp;

  Future<void> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_profile');
    if (userJson != null) {
      try {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        notifyListeners();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> login(String usernameOrEmail, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post(ApiConstants.login, {
        'usernameOrEmail': usernameOrEmail,
        'password': password,
      });

      _isLoading = false;
      if (res['success'] == true) {
        final emailFromUser = res['user']?['email'] ?? res['user']?['Email'];
        _pendingEmail = emailFromUser ?? (usernameOrEmail.contains('@') ? usernameOrEmail : null);
        _lastDebugOtp = res['debugOtp'];
        notifyListeners();
        return {
          'success': true,
          'email': _pendingEmail,
          'requiresOtp': res['requiresOtp'] ?? true,
          'message': res['message'],
          'debugOtp': res['debugOtp']
        };
      } else {
        notifyListeners();
        return {'success': false, 'message': res['message'] ?? 'Đăng nhập thất bại'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> verifyOtp(String email, String otpCode, {String type = 'LOGIN'}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post(ApiConstants.verifyOtp, {
        'email': email,
        'otpCode': otpCode,
        'type': type,
      });

      _isLoading = false;
      if (res['success'] == true && res['token'] != null) {
        await ApiService.saveToken(res['token']);
        if (res['user'] != null) {
          _currentUser = UserModel.fromJson(res['user']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile', jsonEncode(res['user']));
        }
        notifyListeners();
        return {'success': true, 'message': res['message']};
      } else {
        notifyListeners();
        return {'success': false, 'message': res['message'] ?? 'Mã OTP không hợp lệ'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> faceLogin(String username) async {
    _isLoading = true;
    notifyListeners();

    try {
      final embedding = FaceService.generateFaceEmbedding(username);
      final res = await ApiService.post(ApiConstants.faceLogin, {
        'usernameOrEmail': username,
        'faceEmbedding': embedding,
      });

      _isLoading = false;
      if (res['success'] == true && res['token'] != null) {
        await ApiService.saveToken(res['token']);
        if (res['user'] != null) {
          _currentUser = UserModel.fromJson(res['user']);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_profile', jsonEncode(res['user']));
        }
        notifyListeners();
        return {'success': true, 'message': res['message']};
      } else {
        notifyListeners();
        return {'success': false, 'message': res['message'] ?? 'Khuôn mặt không khớp'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String? phoneNumber,
    int roleId = 2,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.post(ApiConstants.register, {
        'username': username,
        'email': email,
        'password': password,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'roleId': roleId,
      });

      _isLoading = false;
      if (res['success'] == true) {
        _pendingEmail = email;
        _lastDebugOtp = res['debugOtp'];
        notifyListeners();
        return {
          'success': true,
          'message': res['message'],
          'debugOtp': res['debugOtp'],
        };
      } else {
        notifyListeners();
        return {'success': false, 'message': res['message'] ?? 'Đăng ký thất bại'};
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': e.toString().replaceAll('Exception: ', '')};
    }
  }

  Future<bool> registerFace(String embedding, {String? username, int? userId}) async {
    try {
      final targetUserId = userId ?? _currentUser?.userId ?? 0;
      final targetUsername = username ?? _currentUser?.username;
      final res = await ApiService.post(ApiConstants.registerFace, {
        'userId': targetUserId,
        'usernameOrEmail': targetUsername,
        'faceEmbedding': embedding,
      });
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _pendingEmail = null;
    _lastDebugOtp = null;
    await ApiService.clearSession();
    notifyListeners();
  }
}
