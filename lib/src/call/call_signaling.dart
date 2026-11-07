import 'dart:async';

import 'call_api.dart';
import 'call_models.dart';

/// Carries WebRTC signalling between the two peers. Implemented here so a provider
/// adapter (which lives in the app) never needs to know how signals travel.
abstract class CallSignalTransport {
  Stream<SignalingMessage> get incoming;

  Future<void> start();

  Future<void> send(String kind, Map<String, dynamic> payload);

  Future<void> stop();
}

/// A transport backed by the backend relay, polled for incoming signals.
///
/// Polling (not a WebSocket subscription) is deliberate: it needs nothing new in the
/// host app's realtime layer, tolerates a dropped socket, and the relay de-dupes by
/// id so a missed poll is simply picked up next tick. An app that prefers a live push
/// can implement [CallSignalTransport] over its Reverb channel instead — the adapter
/// does not care.
class PollingCallSignalTransport implements CallSignalTransport {
  PollingCallSignalTransport({
    required this.api,
    required this.sessionId,
    this.pollInterval = const Duration(milliseconds: 400),
  });

  final CallApi api;
  final String sessionId;
  final Duration pollInterval;

  final StreamController<SignalingMessage> _controller =
      StreamController<SignalingMessage>.broadcast();
  Timer? _timer;
  int _lastId = 0;
  bool _started = false;

  @override
  Stream<SignalingMessage> get incoming => _controller.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await _drain();
    _timer = Timer.periodic(pollInterval, (_) => _drain());
  }

  Future<void> _drain() async {
    try {
      final messages = await api.signals(sessionId, afterId: _lastId);
      for (final message in messages) {
        if (message.id > _lastId) {
          _lastId = message.id;
        }
        _controller.add(message);
      }
    } catch (_) {
      // A dropped poll is retried on the next tick; never surface it to the UI.
    }
  }

  @override
  Future<void> send(String kind, Map<String, dynamic> payload) {
    return api.sendSignal(sessionId, kind: kind, payload: payload);
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _started = false;
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
