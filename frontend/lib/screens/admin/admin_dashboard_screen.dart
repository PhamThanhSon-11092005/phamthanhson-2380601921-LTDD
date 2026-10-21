import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'manage_employees_screen.dart';
import 'manage_departments_screen.dart';
import 'manage_shifts_screen.dart';
import 'review_leaves_screen.dart';
import 'live_map_screen.dart';
import 'review_visitor_passes_screen.dart';
import '../videocall/video_rooms_screen.dart';
import '../auth/login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic>? _stats;
  int _pendingVisitorPasses = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoading = true);

    // Fetch visitor passes count from SharedPreferences
    int visitorCount = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final passData = prefs.getString('visitor_passes_list');
      if (passData != null) {
        final List decoded = jsonDecode(passData);
        visitorCount = decoded.where((p) => (p['status'] ?? 'CHỜ DUYỆT') == 'CHỜ DUYỆT').length;
      }
    } catch (_) {}

    try {
      final res = await ApiService.get(ApiConstants.stats);
      if (res['success'] == true && res['data'] != null) {
        setState(() {
          _stats = res['data'];
          _pendingVisitorPasses = visitorCount;
          _isLoading = false;
        });
      } else {
        setState(() {
          _pendingVisitorPasses = visitorCount;
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _pendingVisitorPasses = visitorCount;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    final pendingLeaves = (_stats?["pendingLeaves"] as num?)?.toInt() ?? 0;
    final totalPending = pendingLeaves + _pendingVisitorPasses;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản Trị Hệ Thống (Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới số liệu',
            onPressed: _fetchStats,
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
        onRefresh: _fetchStats,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: LinearProgressIndicator(),
                ),

              // Welcome card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.indigo.shade100,
                        child: const Icon(Icons.admin_panel_settings_rounded, size: 36, color: Colors.indigo),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Xin chào, ${user?.fullName ?? "Quản trị viên"}!',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bộ phận: ${user?.departmentName ?? "Ban Giám Đốc"}',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.indigo.shade200),
                              ),
                              child: const Text(
                                'QUYỀN HẠN TỐI CAO (ADMIN)',
                                style: TextStyle(
                                  color: Colors.indigo,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // KPI Stats Grid
              const Text(
                'Thống Kê Hôm Nay',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Tổng Nhân Viên',
                      value: '${_stats?["totalEmployees"] ?? 2}',
                      subtitle: 'Bao gồm Admin & Nhân sự',
                      icon: Icons.people_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Đã Điểm Danh',
                      value: '${_stats?["checkedInToday"] ?? 1}',
                      subtitle: 'Đã check-in thành công',
                      icon: Icons.how_to_reg_rounded,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      title: 'Chưa Check-in',
                      value: '${_stats?["absentToday"] ?? 1}',
                      subtitle: 'Chưa vào ca làm việc',
                      icon: Icons.person_off_rounded,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      title: 'Đơn Chờ Duyệt',
                      value: '$totalPending',
                      subtitle: _pendingVisitorPasses > 0
                          ? 'Thẻ khách: $_pendingVisitorPasses • Phép: $pendingLeaves'
                          : 'Đơn nghỉ phép: $pendingLeaves',
                      icon: Icons.pending_actions_rounded,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Admin Management CRUD Operations & Features
              const Text(
                'Danh Mục Quản Trị & Tiện Ích',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 5.b: Real-time Live Location Map
              _buildAdminNavTile(
                icon: Icons.map_rounded,
                color: Colors.teal,
                title: 'Bản Đồ Vị Trí Nhân Viên (Live GPS)',
                subtitle: 'Tính năng 5.b: Theo dõi trực tiếp vị trí nhân viên',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LiveMapScreen()),
                  );
                },
              ),

              // 5.c: Group Video Call Room
              _buildAdminNavTile(
                icon: Icons.video_camera_front_rounded,
                color: Colors.blueAccent,
                title: 'Phòng Họp & Gọi Video Nhóm',
                subtitle: 'Tính năng 5.c: Tạo phòng họp & tham gia trực tuyến',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VideoRoomsScreen()),
                  );
                },
              ),

              // CRUD: Employees
              _buildAdminNavTile(
                icon: Icons.badge_outlined,
                color: Colors.indigo,
                title: 'Quản Lý Nhân Viên (CRUD)',
                subtitle: 'Thêm, sửa, xóa, phân quyền & cập nhật hồ sơ',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageEmployeesScreen()),
                  );
                  _fetchStats();
                },
              ),

              // CRUD: Departments
              _buildAdminNavTile(
                icon: Icons.apartment_rounded,
                color: Colors.deepOrange,
                title: 'Quản Lý Phòng Ban & Geofence (CRUD)',
                subtitle: 'Cấu hình tọa độ GPS công ty & Wi-Fi BSSID chống Fake GPS',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageDepartmentsScreen()),
                  );
                },
              ),

              // CRUD: Shifts
              _buildAdminNavTile(
                icon: Icons.schedule_rounded,
                color: Colors.cyan.shade800,
                title: 'Quản Lý Ca Làm Việc (CRUD)',
                subtitle: 'Thiết lập giờ bắt đầu, kết thúc & ân hạn đi trễ',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ManageShiftsScreen()),
                  );
                },
              ),

              // CRUD: Review Leaves
              _buildAdminNavTile(
                icon: Icons.fact_check_rounded,
                color: Colors.purple,
                title: 'Duyệt Đơn Nghỉ Phép & Giải Trình (CRUD)',
                subtitle: 'Phê duyệt hoặc từ chối các đơn xin nghỉ, giải trình',
                badgeCount: pendingLeaves,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewLeavesScreen()),
                  );
                  _fetchStats();
                },
              ),

              // CRUD: Review Visitor Passes
              _buildAdminNavTile(
                icon: Icons.badge_outlined,
                color: Colors.deepPurple,
                title: 'Duyệt Thẻ Khách Ra Vào (Visitor Passes)',
                subtitle: 'Phê duyệt hoặc từ chối yêu cầu cấp mã QR vào cổng của khách',
                badgeCount: _pendingVisitorPasses,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReviewVisitorPassesScreen()),
                  );
                  _fetchStats();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 20),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminNavTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            if (badgeCount != null && badgeCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount mới',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }
}
