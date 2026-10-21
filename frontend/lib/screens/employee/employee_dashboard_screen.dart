import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import 'checkin_screen.dart';
import 'attendance_history_screen.dart';
import 'request_leave_screen.dart';
import '../videocall/video_rooms_screen.dart';
import '../auth/login_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  AttendanceModel? _todayAttendance;
  bool _isLoadingToday = true;
  bool _isSharingLocation = false;
  Timer? _locationTimer;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchTodayAttendance();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTodayAttendance() async {
    setState(() => _isLoadingToday = true);
    try {
      final res = await ApiService.get(ApiConstants.todayAttendance);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _todayAttendance = AttendanceModel.fromJson(res['data']);
          _isLoadingToday = false;
        });
      } else {
        setState(() {
          _todayAttendance = null;
          _isLoadingToday = false;
        });
      }
    } catch (_) {
      setState(() => _isLoadingToday = false);
    }
  }

  // Feature 5.b: Chia sẻ vị trí thời gian thực (Real-time Live Location Sharing)
  void _toggleLocationSharing() {
    setState(() => _isSharingLocation = !_isSharingLocation);

    if (_isSharingLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã bật chia sẻ vị trí trực tiếp cho quản lý!'),
          backgroundColor: Colors.teal,
        ),
      );
      _sendLocationUpdate();
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _sendLocationUpdate());
    } else {
      _locationTimer?.cancel();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã dừng chia sẻ vị trí')),
      );
    }
  }

  Future<void> _sendLocationUpdate() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      final loc = await LocationService.getCurrentLocation();
      await ApiService.post(ApiConstants.updateLocation, {
        'userId': user.userId,
        'latitude': loc.latitude,
        'longitude': loc.longitude,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng Điều Khiển Nhân Viên'),
        actions: [
          IconButton(
            icon: Icon(
              _isSharingLocation ? Icons.location_on : Icons.location_off_outlined,
              color: _isSharingLocation ? Colors.greenAccent : Colors.white,
            ),
            tooltip: _isSharingLocation ? 'Đang chia sẻ vị trí' : 'Bật chia sẻ vị trí',
            onPressed: _toggleLocationSharing,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              final nav = Navigator.of(context);
              await auth.logout();
              if (mounted) {
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTodayAttendance,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoadingToday) const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: LinearProgressIndicator(),
              ),
              // User Greeting Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: primary.withValues(alpha: 0.15),
                        child: Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primary),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.fullName ?? 'Nhân viên',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phòng ban: ${user?.departmentName ?? "Công nghệ thông tin"}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            Text(
                              'Ca: ${user?.shiftName ?? "Ca Hành Chính (08:00 - 17:00)"}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Live Digital Clock & Date
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('HH:mm:ss').format(_currentTime),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(_currentTime),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Today's Status Card
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
                            'Trạng Thái Chấm Công Hôm Nay',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _todayAttendance?.checkInTime != null ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _todayAttendance?.checkInTime != null ? Colors.green : Colors.orange,
                              ),
                            ),
                            child: Text(
                              _todayAttendance?.checkInTime != null
                                  ? (_todayAttendance?.checkOutTime != null ? 'Đã hoàn tất ngày' : 'Đang làm việc')
                                  : 'Chưa Check-in',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _todayAttendance?.checkInTime != null ? Colors.green.shade800 : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.login_rounded, color: Colors.green, size: 28),
                              const SizedBox(height: 4),
                              const Text('Check-In', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _todayAttendance?.checkInTime != null
                                    ? DateFormat('HH:mm:ss').format(_todayAttendance!.checkInTime!)
                                    : '--:--:--',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 40, color: Colors.grey.shade300),
                          Column(
                            children: [
                              const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
                              const SizedBox(height: 4),
                              const Text('Check-Out', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text(
                                _todayAttendance?.checkOutTime != null
                                    ? DateFormat('HH:mm:ss').format(_todayAttendance!.checkOutTime!)
                                    : '--:--:--',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Main Checkin / Checkout Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final changed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CheckInScreen(existingAttendance: _todayAttendance),
                              ),
                            );
                            if (changed == true) _fetchTodayAttendance();
                          },
                          icon: Icon(
                            _todayAttendance?.checkInTime == null ? Icons.fingerprint : Icons.exit_to_app_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _todayAttendance?.checkInTime == null
                                ? 'CHẤM CÔNG VÀO (CHECK-IN GPS & FACE)'
                                : 'CHẤM CÔNG RA (CHECK-OUT)',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _todayAttendance?.checkInTime == null ? Colors.green.shade700 : Colors.red.shade700,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Feature Grid
              const Text(
                'Chức Năng & Tiện Ích',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.25,
                children: [

                  // Feature 5.c: Video Call Room
                  _buildFeatureCard(
                    title: 'Gọi Video Nhóm\n(Phòng Họp)',
                    subtitle: 'Họp trực tuyến',
                    icon: Icons.video_camera_front_rounded,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VideoRoomsScreen()),
                      );
                    },
                  ),

                  // Feature 5.b: Realtime Location Sharing
                  _buildFeatureCard(
                    title: _isSharingLocation ? 'Đang Chia Sẻ\nVị Trí Trực Tiếp' : 'Chia Sẻ\nVị Trí (Live GPS)',
                    subtitle: _isSharingLocation ? 'Chạm để dừng' : 'Chạm để bật',
                    icon: Icons.share_location_rounded,
                    color: _isSharingLocation ? Colors.green : Colors.teal,
                    onTap: _toggleLocationSharing,
                  ),

                  // Attendance History
                  _buildFeatureCard(
                    title: 'Lịch Sử\nChấm Công',
                    subtitle: 'Xem bảng công tháng',
                    icon: Icons.calendar_month_rounded,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen()),
                      );
                    },
                  ),

                  // Leave Request Form
                  _buildFeatureCard(
                    title: 'Đơn Xin Nghỉ\n& Giải Trình',
                    subtitle: 'Gửi đơn online',
                    icon: Icons.description_outlined,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RequestLeaveScreen()),
                      );
                    },
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
