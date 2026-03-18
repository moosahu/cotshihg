import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video placeholder
          Container(
            color: const Color(0xFF1A1A2E),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 70, color: Colors.white),
                  ),
                  SizedBox(height: 16),
                  Text('د. معالج نفسي', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('جارٍ الاتصال...', style: TextStyle(color: Colors.white54)),
                ],
              ),
            ),
          ),
          // Local video placeholder
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              width: 100,
              height: 140,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.person, color: Colors.white, size: 40)),
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
                _CallButton(
                  icon: _isMuted ? Icons.mic_off : Icons.mic,
                  onTap: () => setState(() => _isMuted = !_isMuted),
                  color: _isMuted ? Colors.red : Colors.white24,
                ),
                _CallButton(
                  icon: Icons.call_end,
                  onTap: () => Navigator.pop(context),
                  color: Colors.red,
                  size: 64,
                ),
                _CallButton(
                  icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                  onTap: () => setState(() => _isCameraOff = !_isCameraOff),
                  color: _isCameraOff ? Colors.red : Colors.white24,
                ),
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
  final VoidCallback onTap;
  final Color color;
  final double size;

  const _CallButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}
