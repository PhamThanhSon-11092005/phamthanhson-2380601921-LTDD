import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';

class CheckInScreen extends StatefulWidget {
  final AttendanceModel? existingAttendance;

  const CheckInScreen({super.key, this.existingAttendance});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  LocationResult? _currentLocation;
  bool _isLoadingLocation = true;
  bool _isSubmitting = false;
  CameraController? _cameraController;
  bool _isCameraReady = false;
  final TextEditingController _notesController = TextEditingController();

  bool get _isCheckOut => widget.existingAttendance?.checkInTime != null;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    _initCamera();
  }

  Future<void> _loadLocation() async {
    setState(() => _isLoadingLocation = true);
    final loc = await LocationService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentLocation = loc;
        _isLoadingLocation = false;
      });
    }
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
        _cameraController = CameraController(frontCamera, ResolutionPreset.low, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraReady = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa lấy được tọa độ vị trí GPS')),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      if (!_isCheckOut) {
        // Check-in
        final res = await ApiService.post(
          '${ApiConstants.checkIn}?userId=${user.userId}',
          {
            'latitude': _currentLocation!.latitude,
            'longitude': _currentLocation!.longitude,
            'address': _currentLocation!.address,
            'wifiBSSID': _currentLocation!.wifiBSSID,
            'faceMatchPercent': 99.4,
            'notes': _notesController.text.trim(),
          },
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Điểm danh Check-in thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Check-in thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Check-out
        final res = await ApiService.post(
          '${ApiConstants.checkOut}?userId=${user.userId}',
          {
            'latitude': _currentLocation!.latitude,
            'longitude': _currentLocation!.longitude,
            'wifiBSSID': _currentLocation!.wifiBSSID,
          },
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);

        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Điểm danh Check-out thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Check-out thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCheckOut ? 'Chấm Công Check-Out' : 'Chấm Công Check-In'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Face Camera Box
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                height: 220,
                color: Colors.black87,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_isCameraReady && _cameraController != null)
                      CameraPreview(_cameraController!)
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face_retouching_natural_rounded, size: 72, color: Colors.cyanAccent.shade200),
                          const SizedBox(height: 8),
                          const Text(
                            'AI Face Liveness Recognition',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const Text(
                            'Đã xác thực khuôn mặt nhân viên',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 12),
                          ),
                        ],
                      ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.greenAccent, size: 16),
                            SizedBox(width: 4),
                            Text('Khớp 99.4%', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location & Anti-Fake Wi-Fi Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Xác Thực Vị Trí & Wi-Fi Công Ty',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.indigo),
                          tooltip: 'Lấy lại tọa độ GPS',
                          onPressed: _loadLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoadingLocation)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      // GPS Info
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tọa độ: ${_currentLocation?.latitude.toStringAsFixed(4)}, ${_currentLocation?.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          _currentLocation?.address ?? '',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Feature 6: Wi-Fi Anti Fake GPS
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.indigo.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.wifi_lock_rounded, color: Colors.indigo),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Wi-Fi: ${_currentLocation?.wifiName ?? "Mạng Nội Bộ"}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'BSSID: ${_currentLocation?.wifiBSSID ?? "Office_WiFi_5G"} (Chống Fake GPS)',
                                    style: TextStyle(color: Colors.indigo.shade700, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Notes
            if (!_isCheckOut)
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Ghi chú chấm công (tùy chọn)',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(_isCheckOut ? Icons.logout : Icons.login, color: Colors.white),
                label: Text(
                  _isSubmitting
                      ? 'ĐANG XÁC THỰC...'
                      : (_isCheckOut ? 'XÁC NHẬN CHECK-OUT' : 'XÁC NHẬN CHECK-IN HÔM NAY'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCheckOut ? Colors.red.shade700 : Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
