import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';

class VisitorPassScreen extends StatefulWidget {
  const VisitorPassScreen({super.key});

  @override
  State<VisitorPassScreen> createState() => _VisitorPassScreenState();
}

class _VisitorPassScreenState extends State<VisitorPassScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _companyController = TextEditingController();
  final _idNumberController = TextEditingController();

  String _selectedDepartment = 'Phòng CNTT';
  final List<String> _departments = [
    'Phòng CNTT',
    'Phòng Nhân Sự',
    'Phòng Kinh Doanh',
    'Ban Giám Đốc',
    'Phòng Kế Toán',
    'Phòng Kỹ Thuật',
    'Bộ Phận CSKH'
  ];

  String _selectedPurpose = 'Gặp gỡ đối tác / Trao đổi dự án';
  final List<String> _purposes = [
    'Gặp gỡ đối tác / Trao đổi dự án',
    'Phỏng vấn tuyển dụng',
    'Ký kết hợp đồng / Thủ tục giấy tờ',
    'Tham quan văn phòng',
    'Giao nhận tài liệu / Hàng mẫu',
    'Khác'
  ];

  DateTime _visitDate = DateTime.now();
  TimeOfDay _visitTime = TimeOfDay.now();

  List<Map<String, dynamic>> _savedPasses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user != null) {
        if (_nameController.text.isEmpty && user.fullName.isNotEmpty) {
          _nameController.text = user.fullName;
        }
      }
    });
    _loadSavedPasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedPasses() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('visitor_passes_list');
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        setState(() {
          _savedPasses = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _savePass(Map<String, dynamic> pass) async {
    final prefs = await SharedPreferences.getInstance();
    _savedPasses.insert(0, pass);
    await prefs.setString('visitor_passes_list', jsonEncode(_savedPasses));
    setState(() {});
  }

  Future<void> _deletePass(int index) async {
    final prefs = await SharedPreferences.getInstance();
    _savedPasses.removeAt(index);
    await prefs.setString('visitor_passes_list', jsonEncode(_savedPasses));
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa thẻ khách')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _visitDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _visitTime,
    );
    if (picked != null) {
      setState(() => _visitTime = picked);
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final passId = 'VIS-${DateFormat('yyyyMMdd').format(_visitDate)}-${(1000 + (DateTime.now().millisecondsSinceEpoch % 9000))}';
    final dateStr = DateFormat('dd/MM/yyyy').format(_visitDate);
    final timeStr = _visitTime.format(context);

    // Initial status is CHỜ DUYỆT (Pending approval from Admin)
    const initialStatus = 'CHỜ DUYỆT';

    final qrPayload = jsonEncode({
      'type': 'VISITOR_PASS',
      'pass_id': passId,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'company': _companyController.text.trim().isEmpty ? 'Tự do' : _companyController.text.trim(),
      'department': _selectedDepartment,
      'purpose': _selectedPurpose,
      'date': dateStr,
      'time': timeStr,
      'status': initialStatus,
      'created_at': DateTime.now().toIso8601String(),
    });

    final newPass = {
      'id': passId,
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'company': _companyController.text.trim().isEmpty ? 'Tự do' : _companyController.text.trim(),
      'id_number': _idNumberController.text.trim(),
      'department': _selectedDepartment,
      'purpose': _selectedPurpose,
      'date': dateStr,
      'time': timeStr,
      'qr_data': qrPayload,
      'created_at': DateTime.now().toIso8601String(),
      'status': initialStatus,
    };

    _savePass(newPass);

    setState(() => _isLoading = false);

    _showPassDialog(newPass);
  }

  void _showPassDialog(Map<String, dynamic> pass) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            // Find freshest pass data from _savedPasses
            final currentPass = _savedPasses.firstWhere(
              (p) => p['id'] == pass['id'],
              orElse: () => pass,
            );
            final status = currentPass['status'] ?? 'CHỜ DUYỆT';

            Color headerColor1;
            Color headerColor2;
            Color badgeBg;
            Color badgeFg;
            String badgeText;
            IconData badgeIcon;

            if (status == 'ĐÃ DUYỆT') {
              headerColor1 = const Color(0xFF11998E);
              headerColor2 = const Color(0xFF38EF7D);
              badgeBg = Colors.white;
              badgeFg = Colors.green.shade800;
              badgeText = 'ĐÃ DUYỆT (HỢP LỆ)';
              badgeIcon = Icons.check_circle;
            } else if (status == 'TỪ CHỐI') {
              headerColor1 = const Color(0xFFEB3349);
              headerColor2 = const Color(0xFFF45C43);
              badgeBg = Colors.white;
              badgeFg = Colors.red.shade800;
              badgeText = 'BỊ TỪ CHỐI';
              badgeIcon = Icons.cancel;
            } else {
              headerColor1 = const Color(0xFFF2994A);
              headerColor2 = const Color(0xFFF2C94C);
              badgeBg = Colors.white;
              badgeFg = Colors.orange.shade900;
              badgeText = 'CHỜ ADMIN DUYỆT';
              badgeIcon = Icons.hourglass_top_rounded;
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [headerColor1, headerColor2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: headerColor1.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: Icon(Icons.badge, color: Colors.white),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'THẺ KHÁCH VIẾNG THĂM',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Mã: ${currentPass['id']}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 16, color: badgeFg),
                                const SizedBox(width: 6),
                                Text(
                                  badgeText,
                                  style: TextStyle(color: badgeFg, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // QR Code or Locked State
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: status == 'ĐÃ DUYỆT'
                                    ? Colors.green.shade400
                                    : (status == 'TỪ CHỐI' ? Colors.red.shade300 : Colors.orange.shade300),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Opacity(
                              opacity: status == 'ĐÃ DUYỆT' ? 1.0 : 0.2,
                              child: QrImageView(
                                data: currentPass['qr_data'] ?? currentPass['id'] ?? '',
                                version: QrVersions.auto,
                                size: 180.0,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: status == 'ĐÃ DUYỆT' ? Colors.green.shade700 : Colors.grey,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                          if (status == 'CHỜ DUYỆT')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade900.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock_clock, color: Colors.white, size: 36),
                                  SizedBox(height: 6),
                                  Text(
                                    'ĐANG CHỜ ADMIN DUYỆT',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Thẻ chưa có hiệu lực vào cổng',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          if (status == 'TỪ CHỐI')
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.block, color: Colors.white, size: 36),
                                  SizedBox(height: 6),
                                  Text(
                                    'YÊU CẦU BỊ TỪ CHỐI',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Notice Text
                    if (status == 'ĐÃ DUYỆT')
                      const Text(
                        '✅ Mã QR đã được duyệt! Hãy xuất trình tại cổng bảo vệ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                      )
                    else if (status == 'CHỜ DUYỆT')
                      const Text(
                        '⏳ Yêu cầu cấp thẻ đã được gửi đến Admin. Mã QR sẽ tự động kích hoạt ngay khi Admin phê duyệt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.deepOrange),
                      )
                    else
                      Text(
                        '❌ Lý do từ chối: ${currentPass['admin_note'] ?? "Không đáp ứng quy định ra vào"}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                      ),

                    const Divider(height: 24),

                    // Chi tiết
                    _detailRow(Icons.person, 'Khách viếng thăm', currentPass['name'] ?? ''),
                    _detailRow(Icons.phone, 'Số điện thoại', currentPass['phone'] ?? ''),
                    _detailRow(Icons.business, 'Đơn vị / Công ty', currentPass['company'] ?? 'Tự do'),
                    _detailRow(Icons.meeting_room, 'Phòng ban tiếp', currentPass['department'] ?? ''),
                    _detailRow(Icons.calendar_today, 'Ngày giờ hẹn', '${currentPass['date']} - ${currentPass['time']}'),
                    _detailRow(Icons.flag, 'Mục đích', currentPass['purpose'] ?? ''),

                    const SizedBox(height: 16),

                    // Actions
                    if (status == 'CHỜ DUYỆT')
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(40),
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade400),
                        ),
                        onPressed: () async {
                          await _loadSavedPasses();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Kiểm tra trạng thái duyệt lại'),
                      ),

                    const SizedBox(height: 8),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2575FC),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _tabController.animateTo(1);
                      },
                      icon: const Icon(Icons.view_list),
                      label: const Text('Xem danh sách thẻ của tôi'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.blueGrey),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Ký Thẻ Khách Ra Vào'),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: _loadSavedPasses,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.amber,
          tabs: [
            const Tab(icon: Icon(Icons.add_card), text: 'Đăng Ký Mới'),
            Tab(icon: const Icon(Icons.view_list), text: 'Thẻ Của Tôi (${_savedPasses.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRegistrationForm(),
          _buildPassesList(),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    final dateStr = DateFormat('dd/MM/yyyy').format(_visitDate);
    final timeStr = _visitTime.format(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info Header Card
            Card(
              elevation: 0,
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade300),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.amber, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Quy định bảo an: Thẻ sau khi tạo sẽ được gửi về Admin xác nhận. Mã QR chỉ có hiệu lực vào cổng khi Admin phê duyệt.',
                        style: TextStyle(fontSize: 13, color: Colors.brown, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Họ và tên
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Họ và tên khách *',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null,
            ),
            const SizedBox(height: 14),

            // Số điện thoại
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Số điện thoại liên hệ *',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
            ),
            const SizedBox(height: 14),

            // Đơn vị / Công ty
            TextFormField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Đơn vị / Công ty công tác',
                hintText: 'Ví dụ: Công ty Cổ phần ABC (hoặc để trống)',
                prefixIcon: const Icon(Icons.business_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // CCCD / CMND
            TextFormField(
              controller: _idNumberController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Số CCCD / CMND (tùy chọn)',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Phòng ban tiếp đón
            DropdownButtonFormField<String>(
              value: _selectedDepartment,
              decoration: InputDecoration(
                labelText: 'Phòng ban tiếp đón *',
                prefixIcon: const Icon(Icons.meeting_room_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _departments.map((dep) {
                return DropdownMenuItem(value: dep, child: Text(dep));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedDepartment = val);
              },
            ),
            const SizedBox(height: 14),

            // Mục đích
            DropdownButtonFormField<String>(
              value: _selectedPurpose,
              decoration: InputDecoration(
                labelText: 'Mục đích viếng thăm *',
                prefixIcon: const Icon(Icons.assignment_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _purposes.map((p) {
                return DropdownMenuItem(value: p, child: Text(p, overflow: TextOverflow.ellipsis));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPurpose = val);
              },
            ),
            const SizedBox(height: 14),

            // Chọn Ngày và Giờ
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Ngày hẹn',
                        prefixIcon: const Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Giờ dự kiến',
                        prefixIcon: const Icon(Icons.access_time_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Nút Gửi Đăng Ký
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 3,
              ),
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.send_rounded),
                        SizedBox(width: 8),
                        Text(
                          'GỬI ĐĂNG KÝ CHO ADMIN XÁC NHẬN',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPassesList() {
    if (_savedPasses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.badge_outlined, size: 70, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Chưa có thẻ khách nào',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hãy chuyển qua tab "Đăng Ký Mới" để tạo thẻ ra vào gửi Admin duyệt.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.add_card),
                label: const Text('Đăng ký thẻ ngay'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedPasses,
      child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _savedPasses.length,
        itemBuilder: (context, index) {
          final pass = _savedPasses[index];
          final status = pass['status'] ?? 'CHỜ DUYỆT';

          Color statusBg;
          Color statusFg;
          IconData statusIcon;

          if (status == 'ĐÃ DUYỆT') {
            statusBg = Colors.green.shade100;
            statusFg = Colors.green.shade800;
            statusIcon = Icons.check_circle;
          } else if (status == 'TỪ CHỐI') {
            statusBg = Colors.red.shade100;
            statusFg = Colors.red.shade800;
            statusIcon = Icons.cancel;
          } else {
            statusBg = Colors.orange.shade100;
            statusFg = Colors.orange.shade900;
            statusIcon = Icons.hourglass_top;
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showPassDialog(pass),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: statusBg.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, size: 30, color: statusFg),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  pass['name'] ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    color: statusFg,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Mã: ${pass['id']}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Hẹn: ${pass['date']} (${pass['time']}) • ${pass['department']}',
                            style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      tooltip: 'Xóa thẻ',
                      onPressed: () => _deletePass(index),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
