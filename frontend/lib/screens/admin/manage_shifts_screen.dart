import 'package:flutter/material.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class ManageShiftsScreen extends StatefulWidget {
  const ManageShiftsScreen({super.key});

  @override
  State<ManageShiftsScreen> createState() => _ManageShiftsScreenState();
}

class _ManageShiftsScreenState extends State<ManageShiftsScreen> {
  List<ShiftModel> _shifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchShifts();
  }

  Future<void> _fetchShifts() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConstants.shifts);
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        setState(() {
          _shifts = list.map((e) => ShiftModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditShiftDialog({ShiftModel? shift}) {
    final isEdit = shift != null;
    final nameController = TextEditingController(text: shift?.shiftName ?? '');
    final startController = TextEditingController(text: shift?.startTime ?? '08:00:00');
    final endController = TextEditingController(text: shift?.endTime ?? '17:00:00');
    final graceController = TextEditingController(text: (shift?.gracePeriodMinutes ?? 15).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Sửa Ca Làm Việc' : 'Thêm Ca Làm Việc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Tên ca làm việc',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: startController,
              decoration: InputDecoration(
                labelText: 'Giờ bắt đầu (HH:mm:ss)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: endController,
              decoration: InputDecoration(
                labelText: 'Giờ kết thúc (HH:mm:ss)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: graceController,
              decoration: InputDecoration(
                labelText: 'Ân hạn đi trễ (phút)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = {
                'shiftName': nameController.text.trim(),
                'startTime': startController.text.trim(),
                'endTime': endController.text.trim(),
                'gracePeriodMinutes': int.tryParse(graceController.text) ?? 15,
              };

              try {
                if (isEdit) {
                  payload['shiftId'] = shift.shiftId;
                  final res = await ApiService.put('${ApiConstants.shifts}/${shift.shiftId}', payload);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['success'] == true ? 'Cập nhật ca thành công!' : (res['message'] ?? 'Cập nhật thất bại')),
                      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                    ));
                  }
                } else {
                  final res = await ApiService.post(ApiConstants.shifts, payload);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res['success'] == true ? 'Thêm ca làm việc thành công!' : (res['message'] ?? 'Thêm thất bại')),
                      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                    ));
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Lỗi: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ));
                }
              }
              _fetchShifts();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteShift(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa ca làm việc này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.delete('${ApiConstants.shifts}/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(res['success'] == true ? 'Đã xóa ca làm việc thành công!' : (res['message'] ?? 'Xóa thất bại')),
            backgroundColor: res['success'] == true ? Colors.green : Colors.red,
          ));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Lỗi khi xóa: ${e.toString()}'),
            backgroundColor: Colors.red,
          ));
        }
      }
      _fetchShifts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ca Làm Việc (CRUD)')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditShiftDialog(),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Thêm Ca Mới'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? const Center(child: Text('Không có ca làm việc nào'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _shifts.length,
                  itemBuilder: (ctx, i) {
                    final item = _shifts[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.schedule, color: Colors.white),
                        ),
                        title: Text(item.shiftName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          'Giờ làm: ${item.startTime} - ${item.endTime}\nÂn hạn: ${item.gracePeriodMinutes} phút',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _showAddEditShiftDialog(shift: item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteShift(item.shiftId),
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
