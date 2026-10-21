import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewVisitorPassesScreen extends StatefulWidget {
  const ReviewVisitorPassesScreen({super.key});

  @override
  State<ReviewVisitorPassesScreen> createState() => _ReviewVisitorPassesScreenState();
}

class _ReviewVisitorPassesScreenState extends State<ReviewVisitorPassesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _passes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPasses() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('visitor_passes_list');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        _passes = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {
        _passes = [];
      }
    } else {
      _passes = [];
    }
    setState(() => _isLoading = false);
  }

  Future<void> _updatePassStatus(String passId, String newStatus, {String? note}) async {
    final prefs = await SharedPreferences.getInstance();
    for (var pass in _passes) {
      if (pass['id'] == passId) {
        pass['status'] = newStatus;
        if (note != null && note.isNotEmpty) {
          pass['admin_note'] = note;
        }
        pass['reviewed_at'] = DateTime.now().toIso8601String();

        // Update QR payload to reflect approval
        final qrMap = {
          'type': 'VISITOR_PASS',
          'pass_id': pass['id'],
          'name': pass['name'],
          'company': pass['company'],
          'department': pass['department'],
          'date': pass['date'],
          'time': pass['time'],
          'status': newStatus,
          'reviewed_at': DateTime.now().toIso8601String(),
        };
        pass['qr_data'] = jsonEncode(qrMap);
        break;
      }
    }

    await prefs.setString('visitor_passes_list', jsonEncode(_passes));
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'ĐÃ DUYỆT'
                ? 'Đã phê duyệt thẻ khách thành công! Thẻ đã có hiệu lực.'
                : 'Đã từ chối cấp thẻ khách.',
          ),
          backgroundColor: newStatus == 'ĐÃ DUYỆT' ? Colors.green.shade700 : Colors.redAccent,
        ),
      );
    }
  }

  void _showRejectDialog(String passId, String visitorName) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Từ chối thẻ: $visitorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vui lòng nhập lý do từ chối cấp thẻ:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Ví dụ: Phòng ban bận họp đột xuất...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _updatePassStatus(passId, 'TỪ CHỐI', note: reasonController.text.trim());
            },
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    );
  }

  void _showPassDetail(Map<String, dynamic> pass) {
    final status = pass['status'] ?? 'CHỜ DUYỆT';
    Color statusColor;
    if (status == 'ĐÃ DUYỆT') {
      statusColor = Colors.green;
    } else if (status == 'TỪ CHỐI') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.badge_outlined, color: Colors.indigo),
            const SizedBox(width: 8),
            const Expanded(child: Text('Chi Tiết Thẻ Khách', style: TextStyle(fontSize: 18))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailItem('Mã thẻ', pass['id'] ?? ''),
              _detailItem('Họ và tên', pass['name'] ?? ''),
              _detailItem('Số điện thoại', pass['phone'] ?? ''),
              _detailItem('Đơn vị/Công ty', pass['company'] ?? 'Tự do'),
              _detailItem('CCCD/CMND', pass['id_number'] ?? 'Không có'),
              _detailItem('Phòng ban tiếp đón', pass['department'] ?? ''),
              _detailItem('Mục đích', pass['purpose'] ?? ''),
              _detailItem('Thời gian hẹn', '${pass['date']} lúc ${pass['time']}'),
              if (pass['admin_note'] != null)
                _detailItem('Lý do từ chối', pass['admin_note'], isAlert: true),
            ],
          ),
        ),
        actions: [
          if (status == 'CHỜ DUYỆT') ...[
            TextButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRejectDialog(pass['id'], pass['name']);
              },
              icon: const Icon(Icons.close, color: Colors.red),
              label: const Text('Từ Chối', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _updatePassStatus(pass['id'], 'ĐÃ DUYỆT');
              },
              icon: const Icon(Icons.check),
              label: const Text('Phê Duyệt'),
            ),
          ] else
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value, {bool isAlert = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isAlert ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterPasses(String tabFilter) {
    if (tabFilter == 'Tất Cả') return _passes;
    if (tabFilter == 'Chờ Duyệt') return _passes.where((p) => (p['status'] ?? 'CHỜ DUYỆT') == 'CHỜ DUYỆT').toList();
    if (tabFilter == 'Đã Duyệt') return _passes.where((p) => p['status'] == 'ĐÃ DUYỆT').toList();
    if (tabFilter == 'Từ Chối') return _passes.where((p) => p['status'] == 'TỪ CHỐI').toList();
    return _passes;
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _passes.where((p) => (p['status'] ?? 'CHỜ DUYỆT') == 'CHỜ DUYỆT').length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt Thẻ Khách Ra Vào'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadPasses,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            Tab(text: 'Tất Cả (${_passes.length})'),
            Tab(text: 'Chờ Duyệt ($pendingCount)'),
            Tab(text: 'Đã Duyệt (${_passes.where((p) => p['status'] == 'ĐÃ DUYỆT').length})'),
            Tab(text: 'Từ Chối (${_passes.where((p) => p['status'] == 'TỪ CHỐI').length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPassList('Tất Cả'),
                _buildPassList('Chờ Duyệt'),
                _buildPassList('Đã Duyệt'),
                _buildPassList('Từ Chối'),
              ],
            ),
    );
  }

  Widget _buildPassList(String tabFilter) {
    final list = _filterPasses(tabFilter);

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Không có thẻ khách nào trong mục "$tabFilter"',
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPasses,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final pass = list[index];
          final status = pass['status'] ?? 'CHỜ DUYỆT';

          Color statusBg;
          Color statusFg;
          IconData statusIcon;

          if (status == 'ĐÃ DUYỆT') {
            statusBg = Colors.green.shade50;
            statusFg = Colors.green.shade800;
            statusIcon = Icons.check_circle;
          } else if (status == 'TỪ CHỐI') {
            statusBg = Colors.red.shade50;
            statusFg = Colors.red.shade800;
            statusIcon = Icons.cancel;
          } else {
            statusBg = Colors.orange.shade50;
            statusFg = Colors.orange.shade800;
            statusIcon = Icons.hourglass_top;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: statusBg,
                        child: Icon(statusIcon, color: statusFg),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pass['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Đơn vị: ${pass['company'] ?? 'Tự do'} • SĐT: ${pass['phone'] ?? ''}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: statusFg.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(color: statusFg, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.meeting_room, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Đến: ${pass['department']} (${pass['date']} - ${pass['time']})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Mục đích: ${pass['purpose']}',
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                  if (pass['admin_note'] != null && pass['admin_note'].toString().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Ghi chú: ${pass['admin_note']}',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontStyle: FontStyle.italic),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _showPassDetail(pass),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Xem Chi Tiết'),
                      ),
                      if (status == 'CHỜ DUYỆT') ...[
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _showRejectDialog(pass['id'], pass['name']),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Từ Chối'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _updatePassStatus(pass['id'], 'ĐÃ DUYỆT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Duyệt Thẻ'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
