import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/face_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../employee/employee_dashboard_screen.dart';
import '../customer/customer_portal_screen.dart';

class FaceLoginScreen extends StatefulWidget {
  const FaceLoginScreen({super.key});

  @override
  State<FaceLoginScreen> createState() => _FaceLoginScreenState();
}

class _FaceLoginScreenState extends State<FaceLoginScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _hasFaceRegistered = false;
  late AnimationController _animController;
  final TextEditingController _usernameController = TextEditingController();

  static const _faceKeyPrefix = 'face_photo_';
  static const _faceFeaturesPrefix = 'face_features_';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (var c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          frontCamera = c;
          break;
        }
      }
      frontCamera ??= cameras.isNotEmpty ? cameras.first : null;

      if (frontCamera != null) {
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  /// Khi người dùng gõ tên đăng nhập: Kiểm tra xem tài khoản này đã đăng ký khuôn mặt chưa
  Future<void> _checkUsernameRegistration(String username) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) {
      if (mounted) setState(() => _hasFaceRegistered = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasPhoto = prefs.getString('$_faceKeyPrefix$trimmed') != null;
    final hasFeatures = prefs.getString('$_faceFeaturesPrefix$trimmed') != null;

    if (mounted) {
      setState(() {
        _hasFaceRegistered = hasPhoto || hasFeatures;
      });
    }
  }

  /// Quét khuôn mặt và đối soát để đăng nhập
  Future<void> _loginWithFace() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      _showSnack('Vui lòng nhập tên tài khoản trước', Colors.orange);
      return;
    }
    if (!_isCameraInitialized || _cameraController == null) {
      _showSnack('Camera chưa sẵn sàng', Colors.red);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedBase64 = prefs.getString('$_faceKeyPrefix$username');
    final savedFeaturesStr = prefs.getString('$_faceFeaturesPrefix$username');

    // 1. KIỂM TRA TÀI KHOẢN ĐÃ ĐĂNG KÝ KHUÔN MẶT CHƯA
    if (savedBase64 == null && savedFeaturesStr == null) {
      _showSnack(
        '❌ Tài khoản "$username" chưa đăng ký khuôn mặt! Vui lòng nhập đúng tên tài khoản đã thiết lập.',
        Colors.red,
      );
      return;
    }

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      final currentBytes = await photo.readAsBytes();

      // 2. PHÂN TÍCH HÌNH ẢNH: CHỐNG CHE CAMERA & PHÁT HIỆN KHUÔN MẶT NGƯỜI
      final analysis = await FaceService.analyzeFaceImage(currentBytes);
      if (!analysis.isValid || analysis.isCovered || !analysis.hasFace) {
        setState(() => _isProcessing = false);
        _showSnack(
          analysis.errorMessage ?? '❌ Không phát hiện khuôn mặt! Vui lòng đưa khuôn mặt rõ ràng vào giữa camera.',
          Colors.red,
        );
        return;
      }

      // 3. ĐỐI SOÁT VỚI DỮ LIỆU KHUÔN MẶT CỦA CHÍNH TÀI KHOẢN NÀY
      List<double> savedVector = [];
      if (savedFeaturesStr != null) {
        try {
          final List decoded = jsonDecode(savedFeaturesStr);
          savedVector = decoded.map((e) => (e as num).toDouble()).toList();
        } catch (_) {}
      } else if (savedBase64 != null) {
        // Tự động phân tích ảnh gốc đã đăng ký nếu chưa lưu vector
        final savedBytes = base64Decode(savedBase64);
        final savedAnalysis = await FaceService.analyzeFaceImage(savedBytes);
        if (savedAnalysis.isValid && savedAnalysis.hasFace) {
          savedVector = savedAnalysis.featureVector;
          await prefs.setString('$_faceFeaturesPrefix$username', jsonEncode(savedVector));
        }
      }

      if (savedVector.isNotEmpty) {
        final similarity = FaceService.compareFaceFeatures(analysis.featureVector, savedVector);
        // Ngưỡng đối soát: phải khớp tối thiểu 70% với ảnh đã đăng ký của tài khoản
        if (similarity < 0.70) {
          setState(() => _isProcessing = false);
          _showSnack(
            '❌ Khuôn mặt không khớp với hồ sơ của tài khoản "$username" (Độ tương đồng: ${(similarity * 100).toInt()}%). Vui lòng thử lại!',
            Colors.red,
          );
          return;
        }
      }

      // 4. XÁC THỰC VỚI HỆ THỐNG ĐỂ VÀO ỨNG DỤNG
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      var result = await auth.faceLogin(username);

      if (result['success'] != true &&
          (result['message']?.toString().contains('chưa đăng ký') == true ||
           result['message']?.toString().contains('dữ liệu khuôn mặt') == true)) {
        final embedding = FaceService.generateFaceEmbedding(username);
        if (!mounted) return;
        await auth.registerFace(embedding, username: username);
        if (!mounted) return;
        result = await auth.faceLogin(username);
      }

      setState(() => _isProcessing = false);
      if (!mounted) return;

      if (result['success'] == true) {
        _showSnack('✅ Nhận diện khuôn mặt thành công! Đang vào ứng dụng...', Colors.green);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        final user = auth.currentUser;
        Widget targetScreen;
        if (user != null && user.isAdmin) {
          targetScreen = const AdminDashboardScreen();
        } else if (user != null && user.isEmployee) {
          targetScreen = const EmployeeDashboardScreen();
        } else {
          targetScreen = const CustomerPortalScreen();
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
          (route) => false,
        );
      } else {
        _showSnack(result['message'] ?? 'Xác thực thất bại', Colors.red);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      _showSnack('Lỗi: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _usernameController.text.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Đăng Nhập Khuôn Mặt AI'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: username.isEmpty
                    ? Colors.blueGrey.shade900.withValues(alpha: 0.8)
                    : (_hasFaceRegistered
                        ? Colors.green.shade900.withValues(alpha: 0.8)
                        : Colors.red.shade900.withValues(alpha: 0.8)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: username.isEmpty
                      ? Colors.blueGrey
                      : (_hasFaceRegistered ? Colors.greenAccent : Colors.redAccent),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    username.isEmpty
                        ? Icons.info_outline
                        : (_hasFaceRegistered ? Icons.verified_user : Icons.warning_amber_rounded),
                    color: username.isEmpty
                        ? Colors.cyanAccent
                        : (_hasFaceRegistered ? Colors.greenAccent : Colors.redAccent),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      username.isEmpty
                          ? 'Vui lòng nhập tên tài khoản chính xác ở dưới\nSau đó hướng mặt vào camera để xác thực'
                          : (_hasFaceRegistered
                              ? 'Tài khoản "$username" hợp lệ\nHãy đưa khuôn mặt vào giữa khung tròn để quét'
                              : 'Tài khoản "$username" CHƯA đăng ký khuôn mặt\nVui lòng kiểm tra lại tên tài khoản'),
                      style: TextStyle(
                        color: username.isEmpty
                            ? Colors.cyanAccent
                            : (_hasFaceRegistered ? Colors.greenAccent : Colors.white),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Username field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                onChanged: _checkUsernameRegistration,
                decoration: InputDecoration(
                  labelText: 'Tên đăng nhập *',
                  labelStyle: const TextStyle(color: Colors.cyanAccent),
                  hintText: 'Nhập chính xác tên tài khoản...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  prefixIcon: const Icon(Icons.person, color: Colors.cyanAccent),
                  suffixIcon: _usernameController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                          onPressed: () {
                            _usernameController.clear();
                            _checkUsernameRegistration('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: username.isEmpty
                          ? Colors.white24
                          : (_hasFaceRegistered ? Colors.greenAccent : Colors.redAccent),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.cyanAccent, width: 2),
                  ),
                ),
              ),
            ),

            // Camera preview
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 260,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(130),
                        child: SizedBox(
                          width: 260,
                          height: 320,
                          child: _isCameraInitialized && _cameraController != null
                              ? CameraPreview(_cameraController!)
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [Colors.indigo.shade900, Colors.black],
                                    ),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                                  ),
                                ),
                        ),
                      ),

                      // Scan line
                      if (!_isProcessing)
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (ctx, _) => Positioned(
                            top: 10 + (_animController.value * 290),
                            child: Container(
                              width: 240,
                              height: 2.5,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [
                                  Colors.transparent,
                                  Colors.cyanAccent,
                                  Colors.transparent,
                                ]),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Processing overlay
                      if (_isProcessing)
                        Container(
                          width: 260,
                          height: 320,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(130),
                            color: Colors.black.withValues(alpha: 0.65),
                          ),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.cyanAccent),
                                SizedBox(height: 12),
                                Text(
                                  'Đang đối soát khuôn mặt...',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Oval border
                      Container(
                        width: 260,
                        height: 320,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(130),
                          border: Border.all(
                            color: _isProcessing
                                ? Colors.amber
                                : (_hasFaceRegistered
                                    ? Colors.greenAccent
                                    : Colors.cyanAccent.withValues(alpha: 0.6)),
                            width: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Notice text
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _isProcessing
                    ? '🔍 Đang phân tích khuôn mặt...'
                    : (username.isEmpty
                        ? '⌨️ Vui lòng nhập tên tài khoản chính xác ở trên'
                        : (_hasFaceRegistered
                            ? '📷 Hướng mặt vào camera và bấm "ĐĂNG NHẬP NGAY"'
                            : '⚠️ Tài khoản chưa có khuôn mặt — Hãy kiểm tra lại')),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: username.isEmpty
                      ? Colors.white70
                      : (_hasFaceRegistered ? Colors.greenAccent : Colors.redAccent),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Nút đăng nhập duy nhất
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing || username.isEmpty)
                      ? null
                      : _loginWithFace,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.face_unlock_rounded, color: Colors.black),
                  label: Text(
                    _isProcessing ? 'ĐANG ĐỐI SOÁT...' : 'QUÉT MẶT & ĐĂNG NHẬP',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _hasFaceRegistered ? Colors.cyanAccent : Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
