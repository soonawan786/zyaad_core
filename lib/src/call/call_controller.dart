import 'dart:async';

import 'package:get/get.dart';

import 'call_adapter.dart';
import 'call_api.dart';
import 'call_models.dart';

/// Provider-agnostic call session controller, shared by the rider and driver apps.
///
/// It owns: the backend calls, the microphone-permission gate, the current
/// [CallAdapter], and the observable state the screens render. It never imports a
/// provider SDK — the host app injects the [CallAdapterFactory] and the permission
/// prompt, so the same controller drives Agora, LiveKit, or a future provider with
/// no change here.
class CallController extends GetxController {
  CallController({
    required this.api,
    required this.adapterFactory,
    Future<bool> Function()? requestMicrophone,
  }) : _requestMicrophone = requestMicrophone;

  final CallApi api;
  final CallAdapterFactory adapterFactory;
  final Future<bool> Function()? _requestMicrophone;

  final status = CallConnectionStatus.idle.obs;
  final muted = false.obs;
  final speaker = false.obs;
  final error = RxnString();
  final sessionId = RxnString();
  final providerName = RxnString();
  final callerRole = CallRole.unknown.obs;
  final useChatFallback = false.obs;
  final elapsedSeconds = 0.obs;

  /// True while an incoming ring is waiting for the user to accept/decline.
  final incoming = false.obs;

  CallAdapter? _adapter;
  StreamSubscription<CallAdapterEvent>? _subscription;
  Timer? _ticker;

  bool get isBusy =>
      status.value == CallConnectionStatus.connecting ||
      status.value == CallConnectionStatus.connected ||
      status.value == CallConnectionStatus.reconnecting;

  /// Start an outgoing call. Returns false (and sets [useChatFallback] or [error])
  /// when refused.
  Future<bool> start({required String orderType, required String orderId}) async {
    error.value = null;
    useChatFallback.value = false;

    if (!await _ensureMicrophone()) {
      error.value = 'Microphone permission is required to call.';
      status.value = CallConnectionStatus.failed;
      return false;
    }

    try {
      final session = await api.start(orderType: orderType, orderId: orderId);
      sessionId.value = session.id;
      providerName.value = session.provider;
      callerRole.value = session.callerRole;
      await _join();
      return true;
    } on CallApiException catch (e) {
      if (e.useChat) {
        useChatFallback.value = true;
      } else {
        error.value = e.message;
      }
      status.value = CallConnectionStatus.failed;
      return false;
    } catch (_) {
      useChatFallback.value = true;
      status.value = CallConnectionStatus.failed;
      return false;
    }
  }

  /// Accept an incoming call (the callee side).
  Future<bool> accept() async {
    final id = sessionId.value;
    if (id == null) return false;

    if (!await _ensureMicrophone()) {
      error.value = 'Microphone permission is required to call.';
      return false;
    }

    incoming.value = false;

    try {
      await api.answer(id);
      await _join();
      return true;
    } on CallApiException catch (e) {
      useChatFallback.value = e.useChat;
      error.value = e.useChat ? null : e.message;
      status.value = CallConnectionStatus.failed;
      return false;
    }
  }

  Future<void> decline() async {
    final id = sessionId.value;
    incoming.value = false;
    if (id != null) {
      await _safe(() => api.reject(id));
    }
    await _teardown();
  }

  Future<void> hangUp() async {
    final id = sessionId.value;
    if (id != null) {
      await _safe(() => api.end(id));
    }
    await _teardown();
  }

  Future<void> toggleMute() async {
    muted.value = !muted.value;
    await _adapter?.setMuted(muted.value);
  }

  Future<void> toggleSpeaker() async {
    speaker.value = !speaker.value;
    await _adapter?.setSpeaker(speaker.value);
  }

  Future<void> report(String reason, {String? notes}) async {
    final id = sessionId.value;
    if (id != null) {
      await _safe(() => api.report(id, reason: reason, notes: notes));
    }
  }

  /// Called by the incoming-call listener (the Reverb event while foregrounded, the
  /// FCM data message while backgrounded). The mic prompt happens on Accept.
  ///
  /// This does NOT navigate: it sets [incoming] and the host shows its own incoming
  /// screen (or the shared `IncomingCallScreen`), so routing stays in the app.
  void onIncomingRing({
    required String sessionIdValue,
    required String provider,
    CallRole role = CallRole.unknown,
  }) {
    // A ring for a call already on screen is ignored.
    if (isBusy && sessionId.value == sessionIdValue) return;

    sessionId.value = sessionIdValue;
    providerName.value = provider;
    callerRole.value = role;
    status.value = CallConnectionStatus.idle;
    error.value = null;
    useChatFallback.value = false;
    incoming.value = true;
  }

  /// Reset everything. Safe to call when nothing is active.
  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _adapter?.leave();
    _adapter = null;
    _ticker?.cancel();
    _ticker = null;
    elapsedSeconds.value = 0;
    sessionId.value = null;
    providerName.value = null;
    status.value = CallConnectionStatus.idle;
    muted.value = false;
    speaker.value = false;
    error.value = null;
    useChatFallback.value = false;
    callerRole.value = CallRole.unknown;
    incoming.value = false;
  }

  // --- internals --------------------------------------------------------------

  Future<void> _join() async {
    final id = sessionId.value;
    if (id == null) return;

    final credentials = await api.token(id);
    providerName.value = credentials.provider;

    // The ONLY place a provider is chosen, and it is data-driven.
    final adapter = adapterFactory(credentials.provider);
    _adapter = adapter;

    _subscription = adapter.events.listen(_onAdapterEvent);

    status.value = CallConnectionStatus.connecting;

    await adapter.join(credentials);
  }

  void _onAdapterEvent(CallAdapterEvent event) {
    switch (event.type) {
      case CallAdapterEventType.connected:
        status.value = CallConnectionStatus.connected;
        _startTicker();
      case CallAdapterEventType.reconnecting:
        status.value = CallConnectionStatus.reconnecting;
      case CallAdapterEventType.disconnected:
        status.value = CallConnectionStatus.disconnected;
        _ticker?.cancel();
      case CallAdapterEventType.failed:
        status.value = CallConnectionStatus.failed;
        error.value = event.message;
      case CallAdapterEventType.mutedChanged:
      case CallAdapterEventType.speakerChanged:
        break;
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    elapsedSeconds.value = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => elapsedSeconds.value++);
  }

  Future<void> _teardown() async {
    _ticker?.cancel();
    _ticker = null;
    if (_adapter != null) {
      await _safe(_adapter!.leave);
    }
    await _subscription?.cancel();
    _subscription = null;
    _adapter = null;
    status.value = CallConnectionStatus.disconnected;
  }

  Future<bool> _ensureMicrophone() async {
    if (_requestMicrophone == null) return true;
    return _requestMicrophone();
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A failed provider call must never crash the UI; the state machine recovers.
    }
  }

  @override
  void onClose() {
    _subscription?.cancel();
    _ticker?.cancel();
    _adapter?.leave();
    super.onClose();
  }
}

