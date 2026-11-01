import 'package:flutter/material.dart';

import '../prayer/prayer.dart';
import '../prayer/prayer_day.dart';

/// The home card: the next prayer, its time, and a live countdown.
///
/// Parameterised rather than reading a host-app controller, so the rider app and
/// the driver app share it and each supplies its own data. Everything it shows comes
/// from the cached prayer window, so it works with no network.
///
/// The caller decides whether to render it at all: when the user has switched
/// Islamic features off, the section must disappear, not merely grey out.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    super.key,
    required this.nextPrayer,
    this.ramadan,
    this.isLoading = false,
    this.localeCode = 'en',
    this.onTap,
    this.emptyMessage = 'Prayer times are not available for this city',
    this.title = 'Next Prayer',
  });

  /// The next obligatory prayer, or null when there is no data yet.
  final NextPrayer? nextPrayer;

  /// Present only inside a confirmed Ramadan period.
  final RamadanWindow? ramadan;

  final bool isLoading;

  /// Drives the prayer label (English or Urdu).
  final String localeCode;

  final VoidCallback? onTap;
  final String emptyMessage;
  final String title;

  @override
  Widget build(BuildContext context) {
    final next = nextPrayer;

    if (next == null) {
      if (isLoading) {
        return const SizedBox(
          height: 96,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      // No data (never loaded, or the city has the feature disabled): say so rather
      // than showing an empty card.
      return _Shell(
        child: Text(emptyMessage, style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return _Shell(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      next.prayer.label(localeCode),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(next.wallClock, style: Theme.of(context).textTheme.titleMedium),
                    if (next.tomorrow) ...[
                      const SizedBox(width: 6),
                      Text('· ${next.date}', style: Theme.of(context).textTheme.labelSmall),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  next.countdown,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (ramadan != null) ...[
                  const SizedBox(height: 8),
                  _RamadanRow(ramadan: ramadan!),
                ],
              ],
            ),
          ),
          const Icon(Icons.explore_outlined),
        ],
      ),
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

/// Sehri ends at Fajr and iftar is Maghrib, shown only inside a confirmed period.
class _RamadanRow extends StatelessWidget {
  const _RamadanRow({required this.ramadan});

  final RamadanWindow ramadan;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        Text('Sehri ends: ${ramadan.sehriEndsWallClock}', style: style),
        Text('Iftar: ${ramadan.iftarWallClock}', style: style),
      ],
    );
  }
}

/// The five prayers with their times, for a "today's timetable" list.
class PrayerTimesList extends StatelessWidget {
  const PrayerTimesList({
    super.key,
    required this.day,
    this.localeCode = 'en',
    this.nowUtc,
  });

  final PrayerDay day;
  final String localeCode;
  final DateTime? nowUtc;

  @override
  Widget build(BuildContext context) {
    final now = (nowUtc ?? DateTime.now().toUtc()).toUtc();
    final next = day.nextAfter(now);

    return Column(
      children: [
        for (final entry in day.ordered)
          if (entry.prayer.isRemindable || entry.prayer == Prayer.sunrise)
            ListTile(
              dense: true,
              title: Text(entry.prayer.label(localeCode)),
              trailing: Text(
                entry.wallClock,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: next?.prayer == entry.prayer ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ),
      ],
    );
  }
}
