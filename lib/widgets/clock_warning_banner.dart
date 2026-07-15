import 'package:flutter/material.dart';
import '../core/config/date_time_service.dart';

/// Displays a dismissible warning banner at the top of any screen when the
/// system clock is found to be drifted or unverified.
///
/// Usage — place inside your Scaffold body or wrap your page content:
///
///   Column(children: [
///     ClockWarningBanner(),
///     Expanded(child: yourPageContent),
///   ])
///
/// Or use [ClockWarningBanner.maybeWrap] for a one-liner:
///
///   ClockWarningBanner.maybeWrap(child: yourPage)
class ClockWarningBanner extends StatelessWidget {
  const ClockWarningBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DateTimeService.instance,
      builder: (context, _) {
        final svc = DateTimeService.instance;
        if (!svc.hasWarning) return const SizedBox.shrink();

        final isDrifted = svc.status == ClockStatus.drifted;

        return Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDrifted
                    ? [const Color(0xFFDC2626), const Color(0xFFB91C1C)]
                    : [const Color(0xFFD97706), const Color(0xFFB45309)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  isDrifted ? Icons.error_outline : Icons.warning_amber_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    svc.warningMessage ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Re-sync button
                TextButton(
                  onPressed: () => DateTimeService.instance.resync(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.18),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Re-sync',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Wraps [child] with this banner at the top.
  static Widget maybeWrap({required Widget child}) {
    return Column(
      children: [
        const ClockWarningBanner(),
        Expanded(child: child),
      ],
    );
  }
}
