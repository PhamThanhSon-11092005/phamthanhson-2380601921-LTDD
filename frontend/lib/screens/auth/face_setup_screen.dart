import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/face_service.dart';

/// Màn hình gợi ý thiết lập khuôn mặt sau khi đăng nhập lần đầu
class FaceSetupScreen extends StatefulWidget {
  final String username;
  final Widget nextScreen;

  const FaceSetupScreen({
    super.key,
    required this.username,
    required this.nextScreen,
  });

  @override
  State<FaceSetupScreen> createState() => _FaceSetupScreenState();
}

class _FaceSetupScreenState extends State<FaceSetupScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _isDone = false;
  late AnimationController _animController;

  static const _faceKeyPrefix = 'face_photo_';
  static const _faceUserKey = 'face_registered_user';

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
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraInitialized = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _captureFace() async {
    if (!_isCameraInitialized || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera chưa sẵn sàng'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isCapturing = true);

    try {
      await Future.delayed(const Duration(milliseconds: 500));
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      // Kiểm tra phát hiện khuôn mặt và chống che camera
      final analysis = await FaceService.analyzeFaceImage(bytes);
      if (!analysis.isValid || analysis.isCovered) {
        if (mounted) {
          setState(() => _isCapturing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(analysis.errorMessage ?? 'Không phát hiện khuôn mặt! Vui lòng đưa khuôn mặt rõ ràng vào giữa camera.'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      final base64Image = base64Encode(bytes);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_faceKeyPrefix${widget.username}', base64Image);
      await prefs.setString('face_features_${widget.username}', jsonEncode(analysis.featureVector));
      await prefs.setString(_faceUserKey, widget.username);

      // Đồng bộ dữ liệu khuôn mặt lên server database
      try {
        final embedding = FaceService.generateFaceEmbedding(widget.username);
        if (mounted) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          await auth.registerFace(embedding, username: widget.username);
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isDone = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu khuôn mặt thành công! Lần sau đăng nhập nhanh bằng khuôn mặt.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) _goNext();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _goNext() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => widget.nextScreen),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade900, Colors.black],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.face_retouching_natural_rounded,
                      size: 56, color: Colors.cyanAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Thiết Lập Đăng Nhập\nBằng Khuôn Mặt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Xin chào ${widget.username}! Hướng mặt vào camera\nvà nhấn "Chụp & Lưu Khuôn Mặt"',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ],
              ),
            ),

            // Camera view
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 250,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(125),
                        child: SizedBox(
                          width: 250,
                          height: 300,
                          child: _isCameraInitialized && _cameraController != null
                              ? CameraPreview(_cameraController!)
                              : Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [Colors.indigo.shade900, Colors.black],
                                    ),
                                  ),
                                  child: const Icon(Icons.face_outlined,
                                      size: 120, color: Colors.cyanAccent),
                                ),
                        ),
                      ),

                      // Scan line
                      if (!_isDone)
                        AnimatedBuilder(
                          animation: _animController,
                          builder: (ctx, _) => Positioned(
                            top: 10 + (_animController.value * 270),
                            child: Container(
                              width: 230,
                              height: 2,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.transparent, Colors.cyanAccent, Colors.transparent],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.cyanAccent.withValues(alpha: 0.7),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Border
                      Container(
                        width: 250,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(125),
                          border: Border.all(
                            color: _isDone
                                ? Colors.greenAccent
                                : (_isCapturing
                                    ? Colors.amber
                                    : Colors.cyanAccent.withValues(alpha: 0.7)),
                            width: 3,
                          ),
                        ),
                      ),

                      // Done checkmark
                      if (_isDone)
                        Container(
                          width: 250,
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(125),
                            color: Colors.green.withValues(alpha: 0.4),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle_outline,
                                color: Colors.greenAccent, size: 80),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  if (!_isDone) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isCapturing ? null : _captureFace,
                        icon: _isCapturing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2),
                              )
                            : const Icon(Icons.camera_alt, color: Colors.black),
                        label: Text(
                          _isCapturing ? 'ĐANG CHỤP...' : 'CHỤP & LƯU KHUÔN MẶT',
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _goNext,
                      child: const Text(
                        'Bỏ qua, thiết lập sau',
                        style: TextStyle(color: Colors.white38, fontSize: 14),
                      ),
                    ),
                  ] else
                    const Text(
                      '✅ Đăng ký thành công! Đang chuyển...',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 16),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
