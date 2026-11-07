import 'dart:convert';

/// A stable connection state the UI can render, independent of the provider.
enum CallConnectionStatus { idle, connecting, connected, reconnecting, disconnected, failed }

/// Who is on the line. The role is opaque to the UI: it is used only to decide
/// "driver calling" vs "customer calling" text. It is never a name or a number.
enum CallRole { customer, driver, receiver, unknown }

CallRole callRoleFromString(String? value) {
  switch (value) {
    case 'driver':
      return CallRole.driver;
    case 'customer':
      return CallRole.customer;
    case 'receiver':
      return CallRole.receiver;
    default:
      return CallRole.unknown;
  }
}

/// Secret-free credentials for joining ONE room, returned by the backend.
///
/// `provider` decides which [CallAdapter] the app builds. `url` is set for LiveKit;
/// `appId`/`uid`/`channel` are set for Agora. Eyeball that there is never a phone
/// number in here — the backend guarantees it.
class CallJoinCredentials {
  const CallJoinCredentials({
    required this.provider,
    required this.room,
    required this.participantId,
    required this.token,
    required this.expiresAt,
    this.url,
    this.appId,
    this.uid,
    this.channel,
    this.sessionId,
    this.role,
    this.iceServers = const [],
  });

  final String provider;
  final String room;
  final String participantId;
  final String token;
  final DateTime expiresAt;
  final String? url;
  final String? appId;
  final String? uid;
  final String? channel;

  /// The backend call session id — needed by the WebRTC signalling relay.
  final String? sessionId;

  /// 'caller' | 'callee' for the p2p (webrtc) provider; decides the SDP offerer.
  final String? role;

  /// STUN/TURN server list for WebRTC (`[{urls: ..., username?, credential?}]`).
  final List<dynamic> iceServers;

  factory CallJoinCredentials.fromJson(Map<String, dynamic> json) {
    return CallJoinCredentials(
      provider: (json['provider'] as String?) ?? '',
      room: (json['room'] as String?) ?? '',
      participantId: (json['participant_id'] as String?) ?? '',
      token: (json['token'] as String?) ?? '',
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? '') ??
          DateTime.now().add(const Duration(minutes: 5)),
      url: json['url'] as String?,
      appId: json['app_id'] as String?,
      uid: json['uid'] as String?,
      channel: json['channel'] as String?,
      sessionId: json['session_id'] as String?,
      role: json['role'] as String?,
      iceServers: (json['ice_servers'] as List<dynamic>?) ?? const [],
    );
  }

  static String encodeList(List<CallJoinCredentials> list) =>
      jsonEncode(list.map((c) => c.toJson()).toList());

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'room': room,
        'participant_id': participantId,
        'token': token,
        'expires_at': expiresAt.toIso8601String(),
        'url': url,
        'app_id': appId,
        'uid': uid,
        'channel': channel,
      };
}

/// The metadata for one call session, as the backend reports it.
class CallSessionInfo {
  const CallSessionInfo({
    required this.id,
    required this.status,
    required this.provider,
    required this.callerRole,
    required this.calleeRole,
    this.expiresAt,
  });

  final String id;
  final String status;
  final String provider;
  final CallRole callerRole;
  final CallRole calleeRole;
  final DateTime? expiresAt;

  factory CallSessionInfo.fromJson(Map<String, dynamic> json) {
    return CallSessionInfo(
      id: (json['id'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      provider: (json['provider'] as String?) ?? '',
      callerRole: callRoleFromString(json['caller_role'] as String?),
      calleeRole: callRoleFromString(json['callee_role'] as String?),
      expiresAt: DateTime.tryParse((json['expires_at'] as String?) ?? ''),
    );
  }
}

/// A WebRTC signalling message (SDP offer/answer or an ICE candidate) exchanged
/// through the backend relay. Used by the `webrtc` provider only.
class SignalingMessage {
  const SignalingMessage({
    required this.id,
    required this.kind,
    required this.fromRole,
    required this.payload,
  });

  final int id;
  final String kind; // offer | answer | ice
  final String fromRole; // caller | callee
  final Map<String, dynamic> payload;

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] as String?) ?? '',
      fromRole: (json['from_role'] as String?) ?? '',
      payload: (json['payload'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }
}
