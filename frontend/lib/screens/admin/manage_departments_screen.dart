import 'package:flutter/material.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class ManageDepartmentsScreen extends StatefulWidget {
  const ManageDepartmentsScreen({super.key});

  @override
  State<ManageDepartmentsScreen> createState() => _ManageDepartmentsScreenState();
}

class _ManageDepartmentsScreenState extends State<ManageDepartmentsScreen> {
  List<DepartmentModel> _departments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConstants.departments);
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        setState(() {
          _departments = list.map((e) => DepartmentModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showAddEditDepartmentDialog({DepartmentModel? dept}) {
    final isEdit = dept != null;
    final codeController = TextEditingController(text: dept?.departmentCode ?? '');
    final nameController = TextEditingController(text: dept?.departmentName ?? '');
    final addressController = TextEditingController(text: dept?.locationAddress ?? 'Khu Công Nghệ Cao, TP. Thủ Đức');
    final latController = TextEditingController(text: (dept?.allowedLatitude ?? 10.8558).toString());
    final lngController = TextEditingController(text: (dept?.allowedLongitude ?? 106.7853).toString());
    final radiusController = TextEditingController(text: (dept?.allowedRadiusMeter ?? 200).toString());
    final wifiController = TextEditingController(text: dept?.allowedWifiBSSID ?? 'Office_WiFi_5G');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Sửa Phòng Ban & Vị Trí' : 'Thêm Phòng Ban'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: codeController,
                enabled: !isEdit,
                decoration: InputDecoration(
                  labelText: 'Mã phòng (Code)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Tên phòng ban',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: 'Địa chỉ văn phòng',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 18),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Cấu hình Geofence Chấm Công:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: InputDecoration(
                        labelText: 'Vĩ độ (Lat)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: InputDecoration(
                        labelText: 'Kinh độ (Lng)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: radiusController,
                decoration: InputDecoration(
                  labelText: 'Bán kính hợp lệ (mét)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: wifiController,
                decoration: InputDecoration(
                  labelText: 'Mã Wi-Fi BSSID (Chống Fake GPS)',
                  hintText: 'Ví dụ: Office_WiFi_5G',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = {
                'departmentCode': codeController.text.trim(),
                'departmentName': nameController.text.trim(),
                'locationAddress': addressController.text.trim(),
                'allowedLatitude': double.tryParse(latController.text) ?? 10.8558,
                'allowedLongitude': double.tryParse(lngController.text) ?? 106.7853,
                'allowedRadiusMeter': double.tryParse(radiusController.text) ?? 200.0,
                'allowedWifiBSSID': wifiController.text.trim(),
              };

              if (isEdit) {
                payload['departmentId'] = dept.departmentId;
                await ApiService.put('${ApiConstants.departments}/${dept.departmentId}', payload);
              } else {
                await ApiService.post(ApiConstants.departments, payload);
              }
              _fetchDepartments();
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDept(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa phòng ban này?'),
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
      await ApiService.delete('${ApiConstants.departments}/$id');
      _fetchDepartments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng Ban & Geofence (CRUD)'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDepartmentDialog(),
        icon: const Icon(Icons.add_business),
        label: const Text('Thêm Phòng Ban'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _departments.isEmpty
              ? const Center(child: Text('Không có phòng ban nào'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _departments.length,
                  itemBuilder: (ctx, i) {
                    final item = _departments[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.business, color: Colors.indigo),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item.departmentName} (${item.departmentCode})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () => _showAddEditDepartmentDialog(dept: item),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  constraints: const BoxConstraints(),
                                  padding: const EdgeInsets.all(6),
                                  onPressed: () => _deleteDept(item.departmentId),
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            Text('Địa chỉ: ${item.locationAddress ?? "Chưa cấu hình"}', style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              'Tọa độ Geofence: (${item.allowedLatitude ?? 0}, ${item.allowedLongitude ?? 0}) • Bán kính: ${item.allowedRadiusMeter}m',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.wifi, size: 16, color: Colors.teal),
                                const SizedBox(width: 4),
                                Text(
                                  'Wi-Fi chống Fake GPS: ${item.allowedWifiBSSID ?? "Không"}',
                                  style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                                ),
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
