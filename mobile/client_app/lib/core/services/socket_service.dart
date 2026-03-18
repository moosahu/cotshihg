import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'storage_service.dart';

class SocketService {
  IO.Socket? _socket;
  final StorageService _storage;

  SocketService(this._storage);

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    final token = _storage.getToken();
    if (token == null) return;

    _socket = IO.io(
      'https://coaching-backend-ft67.onrender.com',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => print('Socket connected'));
    _socket!.onDisconnect((_) => print('Socket disconnected'));
    _socket!.onError((err) => print('Socket error: $err'));
  }

  void joinBooking(String bookingId) {
    _socket?.emit('join_booking', bookingId);
  }

  void sendMessage(String bookingId, String content, {String type = 'text', String? mediaUrl}) {
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

  void onNewMessage(Function(dynamic) callback) {
    _socket?.on('new_message', callback);
  }

  void onTyping(Function(dynamic) callback) {
    _socket?.on('user_typing', callback);
  }

  void onIncomingCall(Function(dynamic) callback) {
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

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
