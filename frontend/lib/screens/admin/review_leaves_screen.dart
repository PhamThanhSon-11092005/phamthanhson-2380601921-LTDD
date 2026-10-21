import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ReviewLeavesScreen extends StatefulWidget {
  const ReviewLeavesScreen({super.key});

  @override
  State<ReviewLeavesScreen> createState() => _ReviewLeavesScreenState();
}

class _ReviewLeavesScreenState extends State<ReviewLeavesScreen> {
  List<LeaveRequestModel> _requests = [];
  bool _isLoading = true;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final url = _statusFilter != null
          ? '${ApiConstants.leaveRequests}?status=$_statusFilter'
          : ApiConstants.leaveRequests;
      final res = await ApiService.get(url);
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        setState(() {
          _requests = list.map((e) => LeaveRequestModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _reviewRequest(int requestId, String status) async {
    final commentController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'Approved' ? 'Phê Duyệt Đơn' : 'Từ Chối Đơn'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(status == 'Approved'
                ? 'Bạn có đồng ý phê duyệt đơn này cho nhân viên?'
                : 'Bạn có chắc chắn muốn từ chối đơn này?'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Ý kiến phê duyệt / Ghi chú',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: status == 'Approved' ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              status == 'Approved' ? 'Duyệt' : 'Từ chối',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      await ApiService.put('${ApiConstants.leaveRequests}/$requestId/review', {
        'approverId': user?.userId ?? 1,
        'status': status,
        'comment': commentController.text.trim(),
      });
      if (mounted) {
        _fetchRequests();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt Đơn & Giải Trình (CRUD)'),
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả'),
                  selected: _statusFilter == null,
                  onSelected: (_) {
                    setState(() => _statusFilter = null);
                    _fetchRequests();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chờ duyệt'),
                  selected: _statusFilter == 'Pending',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'Pending');
                    _fetchRequests();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Đã duyệt'),
                  selected: _statusFilter == 'Approved',
                  onSelected: (_) {
                    setState(() => _statusFilter = 'Approved');
                    _fetchRequests();
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                    ? const Center(child: Text('Không có đơn từ nào'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        itemBuilder: (ctx, i) {
                          final item = _requests[i];
                          Color statusColor = Colors.orange;
                          String statusText = 'Chờ duyệt';
                          if (item.status == 'Approved') {
                            statusColor = Colors.green;
                            statusText = 'Đã duyệt';
                          } else if (item.status == 'Rejected') {
                            statusColor = Colors.red;
                            statusText = 'Từ chối';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.fullName ?? 'Nhân viên',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Chip(
                                        label: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                        backgroundColor: statusColor.withValues(alpha: 0.1),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Loại: ${item.requestType == "NghiPhep" ? "Nghỉ phép" : item.requestType == "DiTreVeSom" ? "Đi trễ/Về sớm" : "Giải trình"}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo),
                                  ),
                                  Text(
                                    'Từ: ${DateFormat("dd/MM/yyyy").format(item.startDate)} - Đến: ${DateFormat("dd/MM/yyyy").format(item.endDate)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Lý do: ${item.reason}'),
                                  if (item.status == 'Pending') ...[
                                    const Divider(height: 20),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () => _reviewRequest(item.requestId, 'Rejected'),
                                          icon: const Icon(Icons.close, color: Colors.red),
                                          label: const Text('Từ chối', style: TextStyle(color: Colors.red)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                          onPressed: () => _reviewRequest(item.requestId, 'Approved'),
                                          icon: const Icon(Icons.check, color: Colors.white),
                                          label: const Text('Phê duyệt', style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
