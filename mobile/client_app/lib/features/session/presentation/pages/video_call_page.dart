import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/storage_service.dart';

const _agoraAppId = '45772ce780f046808740a6d07c34781b';

class VideoCallPage extends StatefulWidget {
  final String bookingId;
  final bool isCoach;

  const VideoCallPage({
    super.key,
    required this.bookingId,
    this.isCoach = false,
  });

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isCameraOff = _startWithCameraOff;
  bool _loading = true;
  String? _errorMsg;
  String? _debugInfo; // shows full error for diagnosis
  String? _roomId;
  String? _sessionId;
  String? _coachName;

  // Timer — 45 minutes countdown
  static const _totalSeconds = 45 * 60;
  int _remainingSeconds = _totalSeconds;
  Timer? _timer;
  bool _showWarning = false;

  bool _isEnding = false; // prevent recursive end
  bool _isWaiting = false; // waiting for second party

  // Camera starts OFF — user enables manually (audio-first approach)
  static const _startWithCameraOff = true;

  // Chat
  bool _showChat = false;
  final List<Map<String, dynamic>> _messages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  int _unreadCount = 0;
  bool _isUploading = false;
  String? _myUserId;

  // Always false — all sessions support video (camera off by default, user toggles)
  bool get _isVoiceOnly => false;

  @override
  void initState() {
    super.initState();
    _loadMyId();
    _initSession();
  }

  void _loadMyId() {
    final raw = getIt<StorageService>().getUser();
    if (raw != null) {
      try {
        final user = jsonDecode(raw) as Map<String, dynamic>;
        _myUserId = user['id']?.toString();
      } catch (_) {}
    }
  }

  Future<void> _initSession() async {
    try {
      final res = await getIt<ApiClient>().startSession(widget.bookingId);
      final data = res['data'] as Map<String, dynamic>;
      _roomId = data['room_id'] as String? ?? widget.bookingId;
      final token = data['agora_token'] as String? ?? '';
      final session = data['session'] as Map<String, dynamic>?;
      _sessionId = session?['id'] as String?;
      _coachName = data['coach_name'] as String? ??
          (session?['therapist_name'] as String?) ??
          'الكوتش';
      final isFirstParty = data['is_first_party'] as bool? ?? true;
      if (isFirstParty) {
        _isWaiting = true;
      } else {
        // Joining an existing session — compute actual remaining time
        final startedAtStr = session?['started_at'] as String?;
        if (startedAtStr != null) {
          final startedAt = DateTime.tryParse(startedAtStr);
          if (startedAt != null) {
            final elapsed = DateTime.now().difference(startedAt.toLocal()).inSeconds;
            _remainingSeconds = (_totalSeconds - elapsed).clamp(0, _totalSeconds);
          }
        }
      }
      _debugInfo = 'API ✓ | room: ${_roomId?.substring(0, 8)}... | token: ${token.isEmpty ? "EMPTY" : token.substring(0, 10) + "..."}';

      // Load existing chat messages (in case user rejoins after killing app)
      await _syncMissedMessages();

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
    // Keep screen on during call
    WakelockPlus.enable();

    // Request permissions
    if (_isVoiceOnly) {
      await Permission.microphone.request();
    } else {
      await [Permission.microphone, Permission.camera].request();
    }

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(const RtcEngineContext(appId: _agoraAppId));

    _engine!.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
        if (mounted) setState(() { _isJoined = true; _loading = false; });
        // Both coach and client join booking room for chat
        final socket = getIt<SocketService>();
        await socket.connect(); // wait until socket is actually connected
        socket.joinBooking(widget.bookingId);
        socket.onNewMessage(_onNewMessage);
        socket.onSocketError((err) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في الدردشة: ${err['message'] ?? err}'), backgroundColor: Colors.red));
        });
        // Listen for remote party ending the call
        socket.onCallEnded((_) {
          if (!_isEnding) _endCall(notifyRemote: false);
        });
        // On every reconnect: re-join booking room + fill in missed messages
        socket.onReconnect(() {
          socket.joinBooking(widget.bookingId);
          socket.onNewMessage(_onNewMessage); // re-register listener
          _syncMissedMessages();
        });
        // Only client notifies coach of incoming call
        if (!widget.isCoach) {
          socket.initiateCall(widget.bookingId, 'voice');
        }
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (mounted) setState(() {
          _remoteUid = remoteUid;
          _isWaiting = false;
        });
        _startTimer(); // countdown starts only when second party joins
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

    await _engine!.enableVideo();
    await _engine!.startPreview();

    await _engine!.joinChannel(
      token: token,
      channelId: _roomId!,
      uid: 0,
      options: const ChannelMediaOptions(
        publishMicrophoneTrack: true,
        publishCameraTrack: false, // camera off by default — user enables manually
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );

    // Mute camera track on entry (audio-first)
    await _engine!.muteLocalVideoStream(true);
  }

  void _startTimer() {
    if (_timer != null) return; // already running — prevent double timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds == 5 * 60) {
          _showWarning = true;
          _showTimeWarningDialog(5);
        }
        if (_remainingSeconds == 60) {
          _showTimeWarningDialog(1);
        }
        if (_remainingSeconds <= 0) {
          t.cancel();
          _endCall();
        }
      });
    });
  }

  void _showTimeWarningDialog(int minutes) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.red.shade900,
        title: Row(children: [
          const Icon(Icons.timer_outlined, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            minutes == 1 ? 'دقيقة واحدة متبقية!' : 'تبقى $minutes دقائق!',
            style: const TextStyle(color: Colors.white),
          ),
        ]),
        content: Text(
          minutes == 1
              ? 'الجلسة ستنتهي تلقائياً بعد دقيقة واحدة.'
              : 'الجلسة ستنتهي تلقائياً بعد $minutes دقائق.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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

  Future<void> _confirmEndCall() async {
    if (_isEnding) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنهاء المكالمة'),
        content: const Text('هل أنت متأكد من إنهاء المكالمة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('إنهاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) _endCall();
  }

  Future<void> _endCall({bool notifyRemote = true}) async {
    if (_isEnding) return;
    _isEnding = true;
    _timer?.cancel();
    WakelockPlus.disable();

    // Notify the other party
    if (notifyRemote) {
      getIt<SocketService>().endCall(widget.bookingId);
    }
    final socket = getIt<SocketService>();
    socket.offCallEnded();
    socket.offNewMessage();
    socket.offReconnect();

    // Navigate immediately — don't block on cleanup
    if (mounted) {
      if (widget.isCoach) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/coach/dashboard');
        }
      } else {
        context.go(
          '/rating/${widget.bookingId}',
          extra: {'coachName': _coachName ?? 'الكوتش'},
        );
      }
    }

    // Cleanup in background (after navigation)
    final engine = _engine;
    _engine = null;
    final sessionId = _sessionId;
    Future(() async {
      try { await engine?.leaveChannel(); } catch (_) {}
      try { await engine?.release(); } catch (_) {}
      if (sessionId != null) {
        try {
          await getIt<ApiClient>().endSession(sessionId)
              .timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
    });
  }

  void _toggleMute() async {
    final muted = !_isMuted;
    await _engine?.muteLocalAudioStream(muted);
    setState(() => _isMuted = muted);
  }

  void _toggleCamera() async {
    final off = !_isCameraOff;
    if (!off) {
      // Turning camera ON — enable track first if needed
      await _engine?.enableLocalVideo(true);
    }
    await _engine?.muteLocalVideoStream(off);
    setState(() => _isCameraOff = off);
  }

  void _onNewMessage(dynamic data) {
    if (!mounted) return;
    final msg = Map<String, dynamic>.from(data as Map);
    setState(() {
      _messages.add(msg);
      if (!_showChat) _unreadCount++;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    getIt<SocketService>().sendMessage(widget.bookingId, text);
    _chatController.clear();
  }

  /// Fetches messages from API and appends any that aren't already shown.
  /// Called on init and on every socket reconnect to fill gaps.
  Future<void> _syncMissedMessages() async {
    try {
      final msgs = await getIt<ApiClient>().getChatMessages(widget.bookingId);
      if (!mounted || msgs.isEmpty) return;
      setState(() {
        final existingIds = _messages.map((m) => m['id']).toSet();
        final newMsgs = msgs.where((m) => !existingIds.contains(m['id'])).toList();
        if (newMsgs.isNotEmpty) {
          _messages.addAll(newMsgs);
          _messages.sort((a, b) {
            final ta = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
            final tb = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
            return ta.compareTo(tb);
          });
        }
      });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
        }
      });
    } catch (_) {}
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إرسال مرفق', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(icon: Icons.image_outlined, label: 'صورة', color: Colors.blue, onTap: () { Navigator.pop(context); _pickAndUploadImage(); }),
                  _AttachOption(icon: Icons.picture_as_pdf_outlined, label: 'PDF', color: Colors.red, onTap: () { Navigator.pop(context); _pickAndUploadPdf(); }),
                  if (widget.isCoach)
                    _AttachOption(icon: Icons.assignment_outlined, label: 'استبيان', color: Colors.purple, onTap: () { Navigator.pop(context); _sendQuestionnaire(); }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    await _uploadAndSend(picked.path, 'image/jpeg', 'image');
  }

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.single.path == null) return;
    await _uploadAndSend(result.files.single.path!, 'application/pdf', 'file');
  }

  Future<void> _uploadAndSend(String filePath, String mimeType, String msgType) async {
    if (_isUploading) return;
    if (mounted) setState(() => _isUploading = true);
    try {
      final res = await getIt<ApiClient>().uploadFile(widget.bookingId, filePath, mimeType);
      final fileUrl = res['data']?['file_url'] as String?;
      if (fileUrl != null) {
        getIt<SocketService>().sendMessage(widget.bookingId, msgType == 'image' ? '📷 صورة' : '📄 ملف PDF', type: msgType, mediaUrl: fileUrl);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل رفع الملف: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _sendQuestionnaire() async {
    try {
      final res = await getIt<ApiClient>().getAvailableQuestionnaireSets();
      final sets = (res['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (sets.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا توجد استبيانات متاحة')));
        return;
      }
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: const Color(0xFF1A1A2E),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('اختر استبياناً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...sets.map((s) => ListTile(
              leading: const Icon(Icons.assignment_outlined, color: Colors.purple),
              title: Text(s['name'] as String? ?? '', style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, s),
            )),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      await getIt<ApiClient>().sendSetToClient(selected['id'].toString(), widget.bookingId);
      getIt<SocketService>().sendMessage(widget.bookingId, '📋 ${selected['name']}', type: 'questionnaire');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WakelockPlus.disable();
    getIt<SocketService>().offCallEnded();
    getIt<SocketService>().offNewMessage();
    getIt<SocketService>().offSocketError();
    getIt<SocketService>().offReconnect();
    _engine?.leaveChannel();
    _engine?.release();
    _chatController.dispose();
    _chatScrollController.dispose();
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
          else if (_isWaiting)
            _WaitingView(isCoach: widget.isCoach)
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
                      onPressed: _confirmEndCall,
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
                    onTap: _confirmEndCall,
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
                  // Chat button with unread badge
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _CallButton(
                        icon: Icons.chat_bubble_outline,
                        onTap: () => setState(() {
                          _showChat = !_showChat;
                          if (_showChat) _unreadCount = 0;
                        }),
                        color: _showChat ? AppTheme.primaryColor : Colors.white24,
                        label: 'دردشة',
                      ),
                      if (_unreadCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            width: 18, height: 18,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$_unreadCount',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Chat panel — slides up from bottom
          if (_showChat && !_loading && _errorMsg == null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.45,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F0F20),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  children: [
                    // Handle + header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 18),
                          const SizedBox(width: 8),
                          const Text('دردشة الجلسة',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setState(() => _showChat = false),
                            child: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // Messages list
                    Expanded(
                      child: _messages.isEmpty
                          ? const Center(
                              child: Text('لا توجد رسائل بعد',
                                  style: TextStyle(color: Colors.white38, fontSize: 13)),
                            )
                          : ListView.builder(
                              controller: _chatScrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final msg = _messages[i];
                                final isMe = _myUserId != null &&
                                    msg['sender_id']?.toString() == _myUserId;
                                final text = msg['content'] as String? ?? '';
                                final msgType = msg['message_type'] as String? ?? 'text';
                                final mediaUrl = msg['media_url'] as String?;
                                final time = msg['created_at'] != null
                                    ? _formatTime(msg['created_at'].toString())
                                    : '';
                                return Align(
                                  alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: msgType == 'image' ? 4 : 12,
                                      vertical: msgType == 'image' ? 4 : 8,
                                    ),
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                    decoration: BoxDecoration(
                                      color: isMe ? AppTheme.primaryColor.withOpacity(0.85) : Colors.white12,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (msgType == 'image' && mediaUrl != null)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: CachedNetworkImage(imageUrl: mediaUrl, width: 200, fit: BoxFit.cover),
                                          )
                                        else if (msgType == 'file' && mediaUrl != null)
                                          GestureDetector(
                                            onTap: () => launchUrl(Uri.parse(mediaUrl), mode: LaunchMode.externalApplication),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                                              const SizedBox(width: 8),
                                              const Text('فتح PDF', style: TextStyle(color: Colors.white, fontSize: 13, decoration: TextDecoration.underline)),
                                            ]),
                                          )
                                        else if (msgType == 'questionnaire')
                                          Row(mainAxisSize: MainAxisSize.min, children: [
                                            const Icon(Icons.assignment_outlined, color: Colors.purple, size: 20),
                                            const SizedBox(width: 6),
                                            Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
                                          ])
                                        else
                                          Text(text, style: const TextStyle(color: Colors.white, fontSize: 14)),
                                        if (time.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(time, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Input row
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(12, 8, 12,
                            MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 12),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: _isUploading ? null : _showAttachmentOptions,
                                child: Container(
                                  width: 42, height: 42,
                                  decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                                  child: _isUploading
                                      ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.attach_file, color: Colors.white70, size: 20),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'اكتب رسالة...',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: Colors.white10,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendChatMessage(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _sendChatMessage,
                                child: Container(
                                  width: 42, height: 42,
                                  decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
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


class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _WaitingView extends StatelessWidget {
  final bool isCoach;
  const _WaitingView({required this.isCoach});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            const SizedBox(height: 24),
            Text(
              isCoach ? 'في انتظار العميل...' : 'في انتظار الكوتش...',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيبدأ العد التنازلي عند دخول الطرف الآخر',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
