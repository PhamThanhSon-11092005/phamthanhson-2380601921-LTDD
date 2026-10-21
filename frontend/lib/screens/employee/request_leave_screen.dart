import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class RequestLeaveScreen extends StatefulWidget {
  const RequestLeaveScreen({super.key});

  @override
  State<RequestLeaveScreen> createState() => _RequestLeaveScreenState();
}

class _RequestLeaveScreenState extends State<RequestLeaveScreen> {
  final _reasonController = TextEditingController();
  String _selectedType = 'NghiPhep';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isSubmitting = false;

  List<LeaveRequestModel> _myRequests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _fetchMyRequests();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchMyRequests() async {
    setState(() => _isLoadingRequests = true);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    try {
      final res = await ApiService.get('${ApiConstants.leaveRequests}/my-requests?userId=${user.userId}');
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        setState(() {
          _myRequests = list.map((e) => LeaveRequestModel.fromJson(e)).toList();
          _isLoadingRequests = false;
        });
      } else {
        setState(() => _isLoadingRequests = false);
      }
    } catch (_) {
      setState(() => _isLoadingRequests = false);
    }
  }

  Future<void> _handleSubmit() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do đơn từ')),
      );
      return;
    }

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await ApiService.post(ApiConstants.leaveRequests, {
        'userId': user.userId,
        'requestType': _selectedType,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'reason': reason,
      });

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res['success'] == true) {
        _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi đơn thành công!'), backgroundColor: Colors.green),
        );
        _fetchMyRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Gửi đơn thất bại'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đơn Từ & Giải Trình'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tạo Đơn Mới', icon: Icon(Icons.add_circle_outline)),
              Tab(text: 'Đơn Đã Gửi', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Form
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Loại yêu cầu',
                      prefixIcon: const Icon(Icons.category),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'NghiPhep', child: Text('Đơn xin nghỉ phép')),
                      DropdownMenuItem(value: 'DiTreVeSom', child: Text('Đơn xin đi trễ / về sớm')),
                      DropdownMenuItem(value: 'GiaiTrinh', child: Text('Giải trình quên chấm công')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Dates
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _startDate,
                              firstDate: DateTime(2025),
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _startDate = d);
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Từ: ${DateFormat("dd/MM/yyyy").format(_startDate)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _endDate,
                              firstDate: _startDate,
                              lastDate: DateTime(2030),
                            );
                            if (d != null) setState(() => _endDate = d);
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text('Đến: ${DateFormat("dd/MM/yyyy").format(_endDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Lý do chi tiết (*)',
                      hintText: 'Nhập rõ nguyên nhân để ban quản lý phê duyệt...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('GỬI ĐƠN LÊN QUẢN LÝ', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Tab 2: List of Requests
            _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : _myRequests.isEmpty
                    ? const Center(child: Text('Chưa có đơn từ nào được gửi'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _myRequests.length,
                        itemBuilder: (ctx, i) {
                          final item = _myRequests[i];
                          Color statusColor = Colors.orange;
                          String statusText = 'Đang chờ duyệt';
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
                                        item.requestType == 'NghiPhep'
                                            ? 'Nghỉ phép'
                                            : item.requestType == 'DiTreVeSom'
                                                ? 'Đi trễ / Về sớm'
                                                : 'Giải trình',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Chip(
                                        label: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                        backgroundColor: statusColor.withValues(alpha: 0.1),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Thời gian: ${DateFormat("dd/MM/yyyy").format(item.startDate)} - ${DateFormat("dd/MM/yyyy").format(item.endDate)}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Lý do: ${item.reason}'),
                                  if (item.approverComment != null && item.approverComment!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Phản hồi quản lý: ${item.approverComment}',
                                      style: const TextStyle(color: Colors.blue, fontStyle: FontStyle.italic, fontSize: 13),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
