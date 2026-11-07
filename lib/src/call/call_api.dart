import 'call_models.dart';

/// Raised for any refused call. [code] mirrors the backend error code.
class CallApiException implements Exception {
  CallApiException(this.message, [this.code]);

  final String message;
  final String? code;

  /// When true the UI should show "Call failed, use chat" and nothing more.
  bool get useChat => const {
        'calls_unavailable',
        'calls_disabled',
        'call_not_available_for_order',
        'caller_blocked',
        'not_a_participant',
      }.contains(code);

  @override
  String toString() => 'CallApiException($code): $message';
}

/// The backend calls the feature needs. The host app implements this over its own
/// HTTP client + auth token, so this package stays free of http and base URLs.
abstract class CallApi {
  /// Start a ringing session for an order ('trip' | 'delivery').
  Future<CallSessionInfo> start({required String orderType, required String orderId});

  /// Short-lived join credentials for THIS participant.
  Future<CallJoinCredentials> token(String callSessionId);

  Future<void> answer(String callSessionId);

  Future<void> end(String callSessionId);

  Future<void> reject(String callSessionId);

  Future<void> report(String callSessionId, {required String reason, String? notes});

  /// Optional: the metadata for one session (used by the incoming-call screen).
  Future<CallSessionInfo> session(String callSessionId);
}
