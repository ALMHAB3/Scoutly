import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants/app_colors.dart';
import '../features/car_rental/presentation/widgets/car_widgets.dart';
import 'app_shell.dart';
import 'app_snackbar.dart';

/// "Booking Confirmed!" screen shared by car and hotel bookings: booking ID
/// (copy), the booked item with its details, "View Booking Details" (opens
/// My Trips) and the app's navigation bar.
class BookingConfirmedView extends StatelessWidget {
  final String title;
  final String subtitle;
  final String bookingIdLabel;
  final String copyTooltip;
  final String copiedMessage;
  final String viewDetailsLabel;
  final String okLabel;
  final String reference;
  final Widget photo;
  final String name;
  final List<(IconData, String)> lines;
  final Widget? provider;

  const BookingConfirmedView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bookingIdLabel,
    required this.copyTooltip,
    required this.copiedMessage,
    required this.viewDetailsLabel,
    required this.okLabel,
    required this.reference,
    required this.photo,
    required this.name,
    required this.lines,
    this.provider,
  });

  static const _homeTab = 0;
  static const _tripsTab = 3;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back returns to the app rather than to the payment screen.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) AppDockBar.leaveTo(context, 0);
      },
      child: Scaffold(
        backgroundColor: carPageBackground(context),
        bottomNavigationBar: AppDockBar(
          selectedIndex: _tripsTab,
          onSelected: (index) => AppDockBar.leaveTo(context, index),
        ),
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              const _SuccessBadge(),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: carInk(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: carMuted(context)),
              ),
              const SizedBox(height: 24),
              CarCard(
                padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bookingIdLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: carMuted(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SelectableText(
                            '#$reference',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: copyTooltip,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: reference));
                        if (context.mounted) {
                          AppSnackbar.success(context, copiedMessage);
                        }
                      },
                      icon: Icon(Icons.copy_rounded, color: carMuted(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CarCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    SizedBox(width: 104, child: photo),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                          for (final (icon, text) in lines) ...[
                            const SizedBox(height: 4),
                            _IconLine(icon: icon, text: text, maxLines: 2),
                          ],
                          if (provider != null) ...[
                            const SizedBox(height: 4),
                            provider!,
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // OK closes the booking flow and returns to the home screen.
              CarCtaButton(
                buttonKey: const ValueKey('booking-ok'),
                label: okLabel,
                onPressed: () => AppDockBar.leaveTo(context, _homeTab),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  key: const ValueKey('booking-view-details'),
                  onPressed: () => AppDockBar.leaveTo(context, _tripsTab),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(viewDetailsLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;
  const _IconLine({required this.icon, required this.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: carMuted(context)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: carMuted(context)),
            ),
          ),
        ],
      );
}

/// Green check with a ring of confetti dots.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  static const _colors = [
    AppColors.accentGreen,
    AppColors.accentOrange,
    AppColors.accentTeal,
    AppColors.accentYellow,
    AppColors.primaryLight,
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < 12; i++)
              Transform.translate(
                offset: Offset(
                  math.cos(i * math.pi / 6) * (58 + (i.isEven ? 10 : 0)),
                  math.sin(i * math.pi / 6) * (58 + (i.isEven ? 10 : 0)),
                ),
                child: Transform.rotate(
                  angle: i * 0.6,
                  child: Container(
                    width: i.isEven ? 7 : 5,
                    height: i.isEven ? 3.5 : 5,
                    decoration: BoxDecoration(
                      color: _colors[i % _colors.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 48,
              ),
            ).animate().scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1, 1),
                  duration: 350.ms,
                  curve: Curves.easeOutBack,
                ),
          ],
        ),
      );
}
