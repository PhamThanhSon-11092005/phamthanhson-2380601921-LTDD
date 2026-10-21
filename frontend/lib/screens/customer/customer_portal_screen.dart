import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../videocall/video_rooms_screen.dart';
import '../auth/login_screen.dart';
import 'visitor_pass_screen.dart';

class CustomerPortalScreen extends StatelessWidget {
  const CustomerPortalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cổng Dịch Vụ Khách Hàng'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.teal.shade100,
                      child: const Icon(Icons.handshake_rounded, size: 40, color: Colors.teal),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Xin chào, ${user?.fullName ?? "Quý Khách"}!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cổng thông tin đối tác & khách hàng doanh nghiệp',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Dịch Vụ Nổi Bật',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.video_camera_front, color: Colors.white),
                ),
                title: const Text('Họp Trực Tuyến & Tư Vấn (Mục 5.c)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tham gia phòng họp video với nhân viên hỗ trợ'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VideoRoomsScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.purple,
                  child: Icon(Icons.badge, color: Colors.white),
                ),
                title: const Text('Đăng Ký Thẻ Khách Ra Vào', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Tạo mã QR khách viếng thăm văn phòng công ty'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VisitorPassScreen()),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.contact_support, color: Colors.white),
                ),
                title: const Text('Hỗ Trợ & Liên Hệ', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hotline: 0901234567 • Email: support@company.com'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đang kết nối nhân viên tư vấn...')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
