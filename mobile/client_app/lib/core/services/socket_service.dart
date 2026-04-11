import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'storage_service.dart';

class SocketService {
  IO.Socket? _socket;
  final StorageService _storage;

  SocketService(this._storage);

  bool get isConnected => _socket?.connected ?? false;

  /// Connects and returns a Future that completes when the socket is connected
  Future<void> connect() async {
    if (_socket != null) {
      if (!_socket!.connected) _socket!.connect();
      // Wait until connected (max 5s)
      if (!_socket!.connected) {
        await Future.any([
          Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 100));
            return !(_socket?.connected ?? false);
          }),
          Future.delayed(const Duration(seconds: 5)),
        ]);
      }
      return;
    }

    final token = await _storage.getToken();
    if (token == null) return;

    _socket = IO.io(
      'https://coaching-backend-ft67.onrender.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => print('✅ Socket connected'));
    _socket!.onDisconnect((_) => print('🔌 Socket disconnected'));
    _socket!.onError((err) => print('❌ Socket error: $err'));

    // Wait until connected (max 5s)
    await Future.any([
      Future.doWhile(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return !(_socket?.connected ?? false);
      }),
      Future.delayed(const Duration(seconds: 5)),
    ]);
  }

  /// Joins booking room — waits for connection if not yet connected
  void joinBookingWhenReady(String bookingId) {
    if (_socket == null) return;
    if (_socket!.connected) {
      _socket!.emit('join_booking', bookingId);
    } else {
      _socket!.once('connect', (_) => _socket?.emit('join_booking', bookingId));
    }
  }

  /// Legacy alias
  void joinBooking(String bookingId) => joinBookingWhenReady(bookingId);

  void sendMessage(String bookingId, String content,
      {String type = 'text', String? mediaUrl}) {
    _socket?.emit('send_message', {
      'booking_id': bookingId,
      'content': content,
      'message_type': type,
      'media_url': mediaUrl,
    });
  }

  void emitTyping(String bookingId, bool isTyping) {
    _socket?.emit('typing', {'booking_id': bookingId, 'is_typing': isTyping});
  }

  /// Registers new_message listener — replaces any previous one
  void onNewMessage(Function(dynamic) callback) {
    _socket?.off('new_message');
    _socket?.on('new_message', callback);
  }

  void onTyping(Function(dynamic) callback) {
    _socket?.off('user_typing');
    _socket?.on('user_typing', callback);
  }

  void onIncomingCall(Function(dynamic) callback) {
    _socket?.off('incoming_call');
    _socket?.on('incoming_call', callback);
  }

  void initiateCall(String bookingId, String callType) {
    _socket?.emit('call_initiated', {'booking_id': bookingId, 'call_type': callType});
  }

  void acceptCall(String bookingId) {
    _socket?.emit('call_accepted', {'booking_id': bookingId});
  }

  void rejectCall(String bookingId) {
    _socket?.emit('call_rejected', {'booking_id': bookingId});
  }

  void endCall(String bookingId) {
    _socket?.emit('call_ended', {'booking_id': bookingId});
  }

  void onCallEnded(Function(dynamic) callback) {
    _socket?.off('call_ended');
    _socket?.on('call_ended', callback);
  }

  void offCallEnded() {
    _socket?.off('call_ended');
  }

  void offNewMessage() {
    _socket?.off('new_message');
  }

  void onSocketError(Function(dynamic) callback) {
    _socket?.off('error');
    _socket?.on('error', callback);
  }

  void offSocketError() {
    _socket?.off('error');
  }

  /// Called every time the socket successfully reconnects after a drop.
  /// Use this to re-join rooms and re-sync state.
  void onReconnect(Function() callback) {
    _socket?.off('connect'); // 'connect' fires on every (re)connection
    _socket?.on('connect', (_) => callback());
  }

  void offReconnect() {
    _socket?.off('connect');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
