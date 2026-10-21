import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  List<UserModel> _activeUsers = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchLiveLocations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLiveLocations());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveLocations() async {
    try {
      final res = await ApiService.get(ApiConstants.liveLocations);
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        if (mounted) {
          setState(() {
            _activeUsers = list.map((e) => UserModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tạo vị trí pin ổn định cho mỗi user dựa trên userId
  Offset _pinOffset(UserModel u, double w, double h) {
    final seed = u.userId % 100;
    final x = 40.0 + (seed * 37 % (w - 80).clamp(1, double.infinity));
    final y = 40.0 + (seed * 53 % (h - 80).clamp(1, double.infinity));
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.greenAccent,
      Colors.cyanAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bản Đồ Vị Trí Trực Tiếp (Live GPS)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchLiveLocations,
          ),
        ],
      ),
      body: Column(
        children: [
          // Radar Map Canvas
          Container(
            height: 280,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade900,
              border: Border(bottom: BorderSide(color: Colors.teal.shade700, width: 2)),
            ),
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                return Stack(
                  children: [
                    // Radar grid
                    CustomPaint(
                      size: Size(w, h),
                      painter: _RadarMapPainter(),
                    ),

                    // HQ Center Marker
                    Align(
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 10, spreadRadius: 2)],
                            ),
                            child: const Icon(Icons.business, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'TRỤ SỞ CÔNG TY (HUTECH)',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dynamic markers từ API
                    ..._activeUsers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final u = entry.value;
                      final color = colors[i % colors.length];
                      final offset = _pinOffset(u, w, h);
                      return Positioned(
                        left: offset.dx,
                        top: offset.dy,
                        child: _buildMapPin(u.fullName, color),
                      );
                    }),

                    // Không có ai online
                    if (_activeUsers.isEmpty && !_isLoading)
                      const Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Text(
                            'Không có nhân viên nào đang online',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ),
                      ),

                    // Live status badge
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: _activeUsers.isNotEmpty ? Colors.greenAccent : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Live Tracking • ${_activeUsers.length} online',
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // List header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh Sách Nhân Viên Đang Chia Sẻ Vị Trí',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '${_activeUsers.length} nhân viên',
                  style: TextStyle(
                    color: _activeUsers.isNotEmpty ? Colors.teal : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _activeUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off, size: 48, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'Chưa có nhân viên nào bật chia sẻ vị trí',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Nhân viên cần bật GPS trong ứng dụng',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _activeUsers.length,
                        itemBuilder: (ctx, i) {
                          final u = _activeUsers[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.teal,
                                child: Icon(Icons.person_pin_circle, color: Colors.white),
                              ),
                              title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Tọa độ: (${u.currentLatitude?.toStringAsFixed(4) ?? "-"}, ${u.currentLongitude?.toStringAsFixed(4) ?? "-"})\nKhoảng cách: ~45m từ trụ sở',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(Icons.sensors, color: Colors.green),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPin(String name, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)],
          ),
          child: const Icon(Icons.person, color: Colors.black, size: 14),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
          child: Text(
            name,
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _RadarMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 40, paint);
    canvas.drawCircle(center, 80, paint);
    canvas.drawCircle(center, 120, paint);

    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
