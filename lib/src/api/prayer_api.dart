import 'package:get/get_connect/http/src/response/response.dart';

/// The prayer-feature API surface.
///
/// Defined here, implemented per app: the host app owns its `ApiClient` and its
/// base URL, while the controller and the screens that call this live in this
/// package so the rider app and the driver app share them.
///
/// All of these are `/api/v1`, so the envelope is `{success, message, data}` and a
/// refusal is `error.code` (+ `error.details.reason` for a prayer stop or break).
abstract class PrayerRepositoryInterface {
  Future<Response> getPrayerTimes({required String cityId, String? date});

  Future<Response> getPrayerSettings();

  Future<Response> updatePrayerSettings(Map<String, dynamic> body);

  Future<Response> getNearbyMosques({
    required double latitude,
    required double longitude,
    String? cityId,
    double? radiusKm,
    int? limit,
  });

  /// Today's ayah and hadith, each with its reference, source and licence.
  ///
  /// `cityId` is required even though the content is not city-specific: the Islamic
  /// features rollout is per city, and without it the endpoint cannot answer "is
  /// this feature on for this caller?".
  Future<Response> getDailyContent({required String cityId, String? date});

  Future<Response> requestPrayerStop(String tripId, {String? reason});

  Future<Response> getPrayerStop(String tripId);

  Future<Response> respondToPrayerStop(String stopId, {required bool accept});
}

/// Thin pass-through so the controller depends on one type, and a test can fake the
/// repository without going through an HTTP client.
abstract class PrayerServiceInterface {
  Future<Response> getPrayerTimes({required String cityId, String? date});

  Future<Response> getPrayerSettings();

  Future<Response> updatePrayerSettings(Map<String, dynamic> body);

  Future<Response> getNearbyMosques({
    required double latitude,
    required double longitude,
    String? cityId,
    double? radiusKm,
    int? limit,
  });

  Future<Response> getDailyContent({required String cityId, String? date});

  Future<Response> requestPrayerStop(String tripId, {String? reason});

  Future<Response> getPrayerStop(String tripId);

  Future<Response> respondToPrayerStop(String stopId, {required bool accept});
}

class PrayerService implements PrayerServiceInterface {
  const PrayerService({required this.repository});

  final PrayerRepositoryInterface repository;

  @override
  Future<Response> getPrayerTimes({required String cityId, String? date}) =>
      repository.getPrayerTimes(cityId: cityId, date: date);

  @override
  Future<Response> getPrayerSettings() => repository.getPrayerSettings();

  @override
  Future<Response> updatePrayerSettings(Map<String, dynamic> body) =>
      repository.updatePrayerSettings(body);

  @override
  Future<Response> getNearbyMosques({
    required double latitude,
    required double longitude,
    String? cityId,
    double? radiusKm,
    int? limit,
  }) {
    return repository.getNearbyMosques(
      latitude: latitude,
      longitude: longitude,
      cityId: cityId,
      radiusKm: radiusKm,
      limit: limit,
    );
  }

  @override
  Future<Response> getDailyContent({required String cityId, String? date}) =>
      repository.getDailyContent(cityId: cityId, date: date);

  @override
  Future<Response> requestPrayerStop(String tripId, {String? reason}) =>
      repository.requestPrayerStop(tripId, reason: reason);

  @override
  Future<Response> getPrayerStop(String tripId) => repository.getPrayerStop(tripId);

  @override
  Future<Response> respondToPrayerStop(String stopId, {required bool accept}) =>
      repository.respondToPrayerStop(stopId, accept: accept);
}
