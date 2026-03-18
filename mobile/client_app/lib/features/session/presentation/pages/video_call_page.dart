import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

const _agoraAppId = '45772ce780f046808740a6d07c34781b';

class VideoCallPage extends StatefulWidget {
  final String bookingId;
  final String sessionType; // 'video' or 'voice'

  const VideoCallPage({
    super.key,
    required this.bookingId,
    this.sessionType = 'video',
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _loading = true;
  String? _errorMsg;
  String? _debugInfo; // shows full error for diagnosis
  String? _roomId;

  // Timer — 45 minutes countdown
  static const _totalSeconds = 45 * 60;
  int _remainingSeconds = _totalSeconds;
  Timer? _timer;
  bool _showWarning = false;

  bool get _isVoiceOnly => widget.sessionType == 'voice';

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final res = await getIt<ApiClient>().startSession(widget.bookingId);
      final data = res['data'] as Map<String, dynamic>;
      _roomId = data['room_id'] as String? ?? widget.bookingId;
      final token = data['agora_token'] as String? ?? '';
      _debugInfo = 'API ✓ | room: ${_roomId?.substring(0, 8)}... | token: ${token.isEmpty ? "EMPTY" : token.substring(0, 10) + "..."}';
      await _initAgora(token);
    } catch (e) {
      _debugInfo = 'API Error: $e';
      _roomId = widget.bookingId;
      try {
        await _initAgora('');
      } catch (e2) {
        if (mounted) setState(() { _loading = false; _errorMsg = 'فشل التهيئة'; _debugInfo = (_debugInfo ?? '') + '\nAgora init error: $e2'; });
      }
    }
  }

  Future<void> _initAgora(String token) async {
    // Request permissions
    if (_isVoiceOnly) {
      await Permission.microphone.request();
    } else {
      await [Permission.microphone, Permission.camera].request();
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: _agoraAppId));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (mounted) setState(() { _isJoined = true; _loading = false; });
        _startTimer();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (mounted) setState(() => _remoteUid = remoteUid);
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        if (mounted) setState(() => _remoteUid = null);
      },
      onError: (ErrorCodeType err, String msg) {
        final detail = 'Agora ${err.name}(${err.index}) msg:$msg';
        if (mounted) setState(() {
          _loading = false;
          _errorMsg = 'خطأ في الاتصال';
          _debugInfo = (_debugInfo ?? '') + '\n$detail';
        });
      },
    ));

    if (!_isVoiceOnly) {
      await _engine!.enableVideo();
      await _engine!.startPreview();
    }

    await _engine!.joinChannel(
      token: token,
      channelId: _roomId!,
      uid: 0,
      options: ChannelMediaOptions(
        publishMicrophoneTrack: true,
        publishCameraTrack: !_isVoiceOnly,
        autoSubscribeAudio: true,
        autoSubscribeVideo: !_isVoiceOnly,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds == 5 * 60) _showWarning = true; // 5 min warning
        if (_remainingSeconds <= 0) {
          t.cancel();
          _endCall();
        }
      });
    });
  }

  String get _timerText {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Color get _timerColor {
    if (_remainingSeconds <= 5 * 60) return Colors.red.shade400;
    if (_remainingSeconds <= 10 * 60) return Colors.orange;
    return Colors.white70;
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
    if (mounted) {
      if (context.canPop()) context.pop();
      else context.go('/home');
    }
  }

  void _toggleMute() async {
    final muted = !_isMuted;
    await _engine?.muteLocalAudioStream(muted);
    setState(() => _isMuted = muted);
  }

  void _toggleCamera() async {
    final off = !_isCameraOff;
    await _engine?.muteLocalVideoStream(off);
    setState(() => _isCameraOff = off);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Remote area
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (_errorMsg != null)
            Center(child: _ErrorView(msg: _errorMsg!, debug: _debugInfo, onRetry: _initSession))
          else
            _RemoteArea(
              engine: _engine,
              remoteUid: _remoteUid,
              roomId: _roomId,
              isVoiceOnly: _isVoiceOnly,
            ),

          // Local video (video calls only)
          if (!_isVoiceOnly && _isJoined && _engine != null)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: _isCameraOff
                    ? const Center(child: Icon(Icons.videocam_off, color: Colors.white54, size: 32))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: const VideoCanvas(uid: 0),
                          ),
                        ),
                      ),
              ),
            ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                      onPressed: _endCall,
                    ),
                    const Spacer(),
                    // Timer
                    if (_isJoined)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _remainingSeconds <= 5 * 60
                              ? Colors.red.withOpacity(0.3)
                              : Colors.black38,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _remainingSeconds <= 5 * 60
                                ? Colors.red.shade400
                                : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, color: _timerColor, size: 14),
                            const SizedBox(width: 4),
                            Text(_timerText,
                                style: TextStyle(
                                    color: _timerColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    const Spacer(),
                    Icon(
                      _isVoiceOnly ? Icons.phone : Icons.videocam,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5-minute warning banner
          if (_showWarning && _remainingSeconds > 0 && _remainingSeconds <= 5 * 60)
            Positioned(
              top: 80, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تبقى ${_remainingSeconds ~/ 60} دقائق على انتهاء الجلسة',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showWarning = false),
                      child: const Icon(Icons.close, color: Colors.white54, size: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Call controls
          if (!_loading && _errorMsg == null)
            Positioned(
              bottom: 48, left: 0, right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    onTap: _toggleMute,
                    color: _isMuted ? Colors.red.shade700 : Colors.white24,
                    label: _isMuted ? 'صامت' : 'ميكروفون',
                  ),
                  _CallButton(
                    icon: Icons.call_end,
                    onTap: _endCall,
                    color: Colors.red,
                    size: 68,
                    label: 'إنهاء',
                  ),
                  if (_isVoiceOnly)
                    _CallButton(
                      icon: Icons.volume_up,
                      onTap: () {},
                      color: Colors.white24,
                      label: 'سماعة',
                    )
                  else
                    _CallButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      onTap: _toggleCamera,
                      color: _isCameraOff ? Colors.red.shade700 : Colors.white24,
                      label: _isCameraOff ? 'كاميرا متوقفة' : 'كاميرا',
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Remote video / avatar area
class _RemoteArea extends StatelessWidget {
  final RtcEngine? engine;
  final int? remoteUid;
  final String? roomId;
  final bool isVoiceOnly;

  const _RemoteArea({
    required this.engine,
    required this.remoteUid,
    required this.roomId,
    required this.isVoiceOnly,
  });

  @override
  Widget build(BuildContext context) {
    // Show remote video if available and not voice-only
    if (!isVoiceOnly && engine != null && remoteUid != null && roomId != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: engine!,
          canvas: VideoCanvas(uid: remoteUid!),
          connection: RtcConnection(channelId: roomId!),
        ),
      );
    }

    // Avatar fallback (voice only or remote not yet joined)
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 70,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.3),
              child: Icon(
                isVoiceOnly ? Icons.mic : Icons.person,
                size: 70,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'الكوتش',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.successColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  remoteUid == null
                      ? 'في انتظار الكوتش...'
                      : (isVoiceOnly ? 'مكالمة صوتية جارية' : 'مكالمة فيديو جارية'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String msg;
  final String? debug;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry, this.debug});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text('تعذر بدء الجلسة',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (msg.isNotEmpty)
                Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center),
              if (debug != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SelectableText(
                    debug!,
                    style: const TextStyle(color: Colors.orange, fontSize: 11, fontFamily: 'monospace'),
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final String label;

  const _CallButton({
    required this.icon,
    required this.onTap,
    required this.color,
    required this.label,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
