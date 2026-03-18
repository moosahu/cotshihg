import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';

class VideoCallPage extends StatefulWidget {
  final String bookingId;
  const VideoCallPage({super.key, required this.bookingId});
  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  Duration _elapsed = Duration.zero;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          // Remote video (full screen placeholder)
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF16213E),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 60, backgroundColor: Color(0xFF0F3460), child: Icon(Icons.person, size: 70, color: Colors.white54)),
                SizedBox(height: 16),
                Text('أحمد محمد', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('00:12:34', style: TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          ),
          // Local video (small, top right)
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(color: const Color(0xFF0F3460), borderRadius: BorderRadius.circular(12)),
              child: _isCameraOff
                  ? const Icon(Icons.videocam_off, color: Colors.white54)
                  : const Icon(Icons.person, size: 40, color: Colors.white54),
            ),
          ),
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), onPressed: () => context.go('/chat/${widget.bookingId}')),
                  ],
                ),
              ),
            ),
          ),
          // Controls
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(icon: _isMuted ? Icons.mic_off : Icons.mic, label: _isMuted ? 'كتم' : 'صوت', onTap: () => setState(() => _isMuted = !_isMuted), active: !_isMuted),
                _CallButton(icon: _isCameraOff ? Icons.videocam_off : Icons.videocam, label: _isCameraOff ? 'إيقاف' : 'كاميرا', onTap: () => setState(() => _isCameraOff = !_isCameraOff), active: !_isCameraOff),
                _CallButton(icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off, label: 'سماعة', onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn), active: _isSpeakerOn),
                _CallButton(icon: Icons.call_end, label: 'إنهاء', onTap: () => context.go('/dashboard'), isEnd: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool isEnd;
  const _CallButton({required this.icon, required this.label, required this.onTap, this.active = true, this.isEnd = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isEnd ? AppTheme.errorColor : active ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isEnd ? Colors.white : active ? Colors.white : Colors.white38, size: 26),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    ),
  );
}
