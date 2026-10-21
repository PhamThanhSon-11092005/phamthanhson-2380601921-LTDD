import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';

class VideoCallActiveScreen extends StatefulWidget {
  final VideoRoomModel room;

  const VideoCallActiveScreen({super.key, required this.room});

  @override
  State<VideoCallActiveScreen> createState() => _VideoCallActiveScreenState();
}

class _VideoCallActiveScreenState extends State<VideoCallActiveScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _showChat = false;

  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {'sender': 'Hệ thống', 'text': 'Chào mừng bạn tham gia phòng họp video nhóm.'},
    {'sender': 'Quản lý', 'text': 'Mọi người báo cáo tiến độ điểm danh hôm nay nhé.'},
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      CameraDescription? frontCamera;
      for (var c in cameras) {
        if (c.lensDirection == CameraLensDirection.front) {
          frontCamera = c;
          break;
        }
      }
      frontCamera ??= cameras.isNotEmpty ? cameras.first : null;
      if (frontCamera != null) {
        _cameraController = CameraController(frontCamera, ResolutionPreset.medium, enableAudio: false);
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraReady = true);
      }
    } catch (_) {
      if (mounted) setState(() => _isCameraReady = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    setState(() {
      _messages.add({
        'sender': user?.fullName ?? 'Tôi',
        'text': text,
      });
      _chatController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).currentUser;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.roomName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Mã: ${widget.room.roomCode} • 3 thành viên', style: const TextStyle(fontSize: 12, color: Colors.greenAccent)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_showChat ? Icons.chat_bubble : Icons.chat_bubble_outline),
            onPressed: () => setState(() => _showChat = !_showChat),
            tooltip: 'Trò chuyện',
          ),
        ],
      ),
      body: Stack(
        children: [
          // 4-Participant Video Conference Grid
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // Tile 1: Local User (Current User)
                    Expanded(
                      child: _buildVideoTile(
                        name: '${user?.fullName ?? "Tôi"} (Bạn)',
                        isLocal: true,
                        isVideoOff: _isVideoOff,
                        color: Colors.blue.shade900,
                        cameraPreview: _isCameraReady && !_isVideoOff && _cameraController != null
                            ? CameraPreview(_cameraController!)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Tile 2: Admin / Host
                    Expanded(
                      child: _buildVideoTile(
                        name: 'Quản Trị Viên (Host)',
                        isLocal: false,
                        isVideoOff: false,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  children: [
                    // Tile 3: Employee 2
                    Expanded(
                      child: _buildVideoTile(
                        name: 'Phạm Thanh Sơn (IT)',
                        isLocal: false,
                        isVideoOff: false,
                        color: Colors.purple.shade900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Tile 4: Employee 3 / Client
                    Expanded(
                      child: _buildVideoTile(
                        name: 'Nguyễn Văn Khách',
                        isLocal: false,
                        isVideoOff: true,
                        color: Colors.teal.shade900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 90), // Space for bottom controls
            ],
          ),

          // In-call Chat Drawer
          if (_showChat)
            Positioned(
              top: 0,
              bottom: 90,
              right: 0,
              width: MediaQuery.of(context).size.width * 0.85,
              child: Container(
                color: Colors.grey.shade900.withValues(alpha: 0.95),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trò chuyện cuộc họp', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => setState(() => _showChat = false),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final m = _messages[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m['sender']!, style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(m['text']!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _chatController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Nhập tin nhắn...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              filled: true,
                              fillColor: Colors.white12,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.cyanAccent),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Call Control Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              color: Colors.grey.shade900,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mic button
                  IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                    color: _isMuted ? Colors.red : Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: _isMuted ? Colors.white12 : Colors.white24,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                    tooltip: _isMuted ? 'Bật mic' : 'Tắt mic',
                  ),

                  // Video camera button
                  IconButton(
                    icon: Icon(_isVideoOff ? Icons.videocam_off : Icons.videocam),
                    color: _isVideoOff ? Colors.red : Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: _isVideoOff ? Colors.white12 : Colors.white24,
                      padding: const EdgeInsets.all(14),
                    ),
                    onPressed: () => setState(() => _isVideoOff = !_isVideoOff),
                    tooltip: _isVideoOff ? 'Mở camera' : 'Tắt camera',
                  ),

                  // Screen Share
                  IconButton(
                    icon: const Icon(Icons.screen_share_rounded),
                    color: Colors.white,
                    style: IconButton.styleFrom(backgroundColor: Colors.white24, padding: const EdgeInsets.all(14)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đang chia sẻ màn hình điểm danh...')),
                      );
                    },
                    tooltip: 'Chia sẻ màn hình',
                  ),

                  // End call button
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.all(16),
                    ),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Rời phòng họp',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoTile({
    required String name,
    required bool isLocal,
    required bool isVideoOff,
    required Color color,
    Widget? cameraPreview,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (cameraPreview != null)
            Positioned.fill(child: cameraPreview)
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white24,
                  child: Text(
                    name.isNotEmpty ? name[0] : 'U',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                if (isVideoOff) ...[
                  const SizedBox(height: 8),
                  const Text('Camera tắt', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ],
            ),

          // User Name Tag
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic, color: Colors.greenAccent, size: 12),
                  const SizedBox(width: 4),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
