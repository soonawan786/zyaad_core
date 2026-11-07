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
