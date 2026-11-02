import 'dart:io';
import 'dart:typed_data';

/// Where rendered cards live between rendering and sharing.
///
/// Uses `Directory.systemTemp` from `dart:io` rather than `path_provider`, because
/// the system temp directory is already the correct place for a file that only has
/// to survive until the share sheet has read it — and it keeps this package free of
/// a dependency for one call.
///
/// Two rules, both learned from how share sheets actually behave:
///
///   - **A file is never deleted right after sharing.** Android's receiving app may
///     read the content lazily, after the share call has already returned; deleting
///     immediately produces a truncated or empty image in the target app. Files are
///     therefore left in place and reaped later.
///   - **Every share gets a unique name.** A stable filename lets a receiving app
///     serve a cached copy of a previous card, so the name carries a timestamp and a
///     counter.
class ShareCardFileStore {
  ShareCardFileStore({Directory? root, this.maxAge = const Duration(hours: 1)})
      : _rootOverride = root;

  /// How long a rendered card is kept before it can be reaped.
  final Duration maxAge;

  final Directory? _rootOverride;

  int _sequence = 0;

  /// `<system temp>/zyaad_share_cards`.
  Directory get directory =>
      _rootOverride ?? Directory('${Directory.systemTemp.path}/zyaad_share_cards');

  /// Writes PNG bytes and returns the file.
  ///
  /// Reaps stale files first, so the directory cannot grow without bound on a
  /// device that shares a card every day for a year.
  Future<File> write(
    Uint8List bytes, {
    required String stem,
    DateTime? now,
  }) async {
    final dir = directory;

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    await cleanStale(now: now);

    final stamp = (now ?? DateTime.now()).microsecondsSinceEpoch;
    final name = '${stem}_${stamp}_${_sequence++}.png';
    final file = File('${dir.path}/$name');

    return file.writeAsBytes(bytes, flush: true);
  }

  /// Deletes rendered cards older than [maxAge].
  ///
  /// Never deletes a file it has just written, and never throws: a device with an
  /// unwritable temp directory must still be able to share, so a failure here is
  /// swallowed rather than allowed to break the share.
  Future<int> cleanStale({DateTime? now, Duration? maxAge}) async {
    final cutoff = (now ?? DateTime.now()).subtract(maxAge ?? this.maxAge);
    var removed = 0;

    try {
      final dir = directory;

      if (!await dir.exists()) {
        return 0;
      }

      await for (final entity in dir.list()) {
        if (entity is! File) {
          continue;
        }

        try {
          final stat = await entity.stat();

          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            removed++;
          }
        } on FileSystemException {
          // Another isolate may have reaped it first. Nothing to do.
        }
      }
    } on FileSystemException {
      return removed;
    }

    return removed;
  }

  /// Removes every card this store has written.
  ///
  /// Exposed for tests and for a "clear cache" affordance. Not called as part of
  /// sharing, for the reason in the class doc.
  Future<void> clear() async {
    try {
      final dir = directory;

      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } on FileSystemException {
      // Best effort.
    }
  }
}
