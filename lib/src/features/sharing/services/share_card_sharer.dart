import 'dart:io';
import 'dart:ui' show Rect;

/// Hands a rendered card to the OS share sheet.
///
/// **Deliberately an interface, with no `share_plus` dependency in this package.**
///
/// `share_plus` resolves `objective_c` transitively, whose build hook requires a
/// working Xcode native-assets toolchain. Declaring it here made `flutter test` in
/// this package fail before a single test ran on any machine without that
/// toolchain — including this one — which is a bad trade for a package whose whole
/// value is that its rules are testable without a device.
///
/// The concrete implementation therefore lives in the host apps, which already
/// depend on `share_plus` for their own sharing. `SharePlusShareCardSharer` is a
/// ~30-line adapter; see `INTEGRATION.md`, "Wiring the share sheet".
///
/// This is the same dependency-inversion the package already uses for the prayer
/// API (`PrayerRepositoryInterface` implemented per app).
abstract class ShareCardSharer {
  Future<ShareCardShareOutcome> share({
    required File file,
    required String fileName,
    required String text,
    String? subject,
    Rect? origin,
  });
}

/// How a share ended.
enum ShareCardShareOutcome {
  /// The user picked a destination.
  shared,

  /// The user dismissed the sheet without choosing.
  dismissed,

  /// The platform gave no result — normal on some Android versions.
  unavailable;

  bool get isShared => this == ShareCardShareOutcome.shared;
}

/// A sharer that does nothing, for tests and for a platform with no share sheet.
///
/// Returning [ShareCardShareOutcome.unavailable] rather than throwing means the
/// service's error path is exercised without a platform channel.
class NoopShareCardSharer implements ShareCardSharer {
  const NoopShareCardSharer();

  @override
  Future<ShareCardShareOutcome> share({
    required File file,
    required String fileName,
    required String text,
    String? subject,
    Rect? origin,
  }) async =>
      ShareCardShareOutcome.unavailable;
}
