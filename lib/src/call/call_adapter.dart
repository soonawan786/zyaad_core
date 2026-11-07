import 'call_models.dart';

/// What an adapter reports upward. The screens only ever see these.
enum CallAdapterEventType { connected, reconnecting, disconnected, failed, mutedChanged, speakerChanged }

class CallAdapterEvent {
  const CallAdapterEvent(this.type, {this.message});

  final CallAdapterEventType type;
  final String? message;
}

/// The ONE seam between this package and a media provider.
///
/// Concrete adapters (Agora, LiveKit, ...) live in the host apps, because only the
/// app knows which SDK it ships. Nothing above this file — no screen, no controller —
/// imports a provider package, so the provider in use is data, not code.
abstract class CallAdapter {
  /// The provider name this adapter serves ('agora', 'livekit', ...).
  String get provider;

  Stream<CallAdapterEvent> get events;

  Future<void> join(CallJoinCredentials credentials);

  Future<void> setMuted(bool muted);

  Future<void> setSpeaker(bool enabled);

  Future<void> leave();
}

/// Builds the adapter for whichever provider the backend returned.
/// The host app passes one of these to [CallController]; it is the only place a
/// concrete SDK is named.
typedef CallAdapterFactory = CallAdapter Function(String provider);
