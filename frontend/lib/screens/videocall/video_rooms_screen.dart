import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_constants.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'video_call_active_screen.dart';

class VideoRoomsScreen extends StatefulWidget {
  const VideoRoomsScreen({super.key});

  @override
  State<VideoRoomsScreen> createState() => _VideoRoomsScreenState();
}

class _VideoRoomsScreenState extends State<VideoRoomsScreen> {
  List<VideoRoomModel> _rooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRooms();
  }

  Future<void> _fetchRooms() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.get(ApiConstants.videoRooms);
      if (res['success'] == true && res['data'] != null) {
        final List list = res['data'];
        setState(() {
          _rooms = list.map((e) => VideoRoomModel.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateRoomDialog() {
    final roomNameController = TextEditingController(text: 'Họp Giao Ban & Điểm Danh Đầu Ngày');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tạo Phòng Họp Video Mới'),
        content: TextField(
          controller: roomNameController,
          decoration: const InputDecoration(
            labelText: 'Tên phòng họp (*)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
              final res = await ApiService.post(ApiConstants.createVideoRoom, {
                'roomName': roomNameController.text.trim(),
                'hostUserId': user?.userId ?? 1,
              });

              if (res['success'] == true && res['data'] != null) {
                final newRoom = VideoRoomModel.fromJson(res['data']);
                _joinRoom(newRoom);
              }
              _fetchRooms();
            },
            child: const Text('Tạo Phòng'),
          ),
        ],
      ),
    );
  }

  void _joinRoom(VideoRoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallActiveScreen(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gọi Video Nhóm (Mục 5.c)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRooms,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRoomDialog,
        icon: const Icon(Icons.video_call),
        label: const Text('Tạo Phòng Họp'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.video_camera_front_outlined, size: 72, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Chưa có phòng họp video nào đang mở'),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _showCreateRoomDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo Phòng Đầu Tiên'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _rooms.length,
                  itemBuilder: (ctx, i) {
                    final item = _rooms[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.blue.shade100,
                              child: const Icon(Icons.groups, color: Colors.blue, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.roomName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Mã phòng: ${item.roomCode}',
                                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    'Chủ tọa: ${item.hostName ?? "Quản lý"}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade700,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _joinRoom(item),
                              icon: const Icon(Icons.call, size: 18),
                              label: const Text('Tham gia'),
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
