import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// The package's own snackbar, so it does not depend on a host app's theming helper.
///
/// A failure here is almost always something the user can act on — a permission, a
/// trip that has to finish first, the daily limit — so the message is the point.
void showPrayerMessage(String message, {bool isError = false}) {
  if (message.isEmpty) return;

  Get.snackbar(
    isError ? 'Could not do that' : 'Prayer',
    message,
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 4),
    margin: const EdgeInsets.all(12),
  );
}

/// Maps the API's machine-readable refusals onto a sentence the user can act on.
///
/// The backend answers a disabled feature with `islamic_features_disabled`, and a
/// refused prayer stop or break with `error.details.reason`. Showing the raw code
/// would be useless; showing nothing would be worse.
String prayerRefusalMessage(Object? body) {
  if (body is! Map || body['error'] is! Map) return 'Something went wrong.';

  final error = Map<String, dynamic>.from(body['error'] as Map);
  final code = error['code'];
  final details = error['details'];
  final reason = details is Map ? details['reason'] : null;

  if (code == 'islamic_features_disabled') {
    return 'Islamic features are not available for this city.';
  }

  if (code == 'prayer_stop_not_allowed') {
    return switch (reason) {
      'not_a_ride' => 'A prayer stop is only available on a ride.',
      'trip_not_in_progress' => 'The trip has to be in progress.',
      'already_requested' => 'A prayer stop has already been requested for this trip.',
      'not_the_responder' => 'Only the other party can answer this request.',
      'not_pending' => 'This request has already been answered.',
      'not_accepted' => 'This prayer stop has not been accepted.',
      'not_started' => 'This prayer stop has not been started.',
      'max_duration_exceeded' => 'The prayer stop was longer than allowed.',
      'disabled' => 'Prayer stops are disabled for this city.',
      _ => 'A prayer stop is not available on this trip.',
    };
  }

  if (code == 'prayer_break_not_allowed') {
    return switch (reason) {
      'active_trip_with_passenger' => 'Finish the trip with the passenger first.',
      'active_delivery_picked_up' => 'Deliver the parcel you are carrying first.',
      'heading_to_pickup_not_allowed' => 'Not allowed while heading to a pickup.',
      'daily_limit_reached' => 'You have used all your breaks for today.',
      'invalid_duration' => 'Choose a duration within the allowed range.',
      'driver_offline' => 'Go online before taking a prayer break.',
      'already_on_break' => 'A prayer break is already running.',
      _ => 'A prayer break is not allowed right now.',
    };
  }

  return 'Something went wrong.';
}
