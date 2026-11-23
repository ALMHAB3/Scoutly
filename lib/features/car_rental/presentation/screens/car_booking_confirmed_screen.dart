import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';

/// "Booking Confirmed!": booking ID, the car and dates, and next steps.
class CarBookingConfirmedScreen extends StatelessWidget {
  final CarModel car;
  final CarSearchParams params;
  final String reference;
  final String pickupLocation;
  final String dropoffLocation;
  final String paidText;

  const CarBookingConfirmedScreen({
    super.key,
    required this.car,
    required this.params,
    required this.reference,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.paidText,
  });

  static const _tripsTab = 3;

  /// Calendar event (iCalendar) from the pickup time to the drop-off time,
  /// in the device's local time.
  static String calendarEvent({
    required String uid,
    required String title,
    required String location,
    required String description,
    required DateTime start,
    required DateTime end,
  }) {
    String date(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    String local(DateTime d) => '${date(d)}T'
        '${d.hour.toString().padLeft(2, '0')}'
        '${d.minute.toString().padLeft(2, '0')}00';
    String escape(String text) => text
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\n', r'\n');
    final now = DateTime.now().toUtc();
    final stamp = '${date(now)}T'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}Z';
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Zentrip//Car rental//EN',
      'BEGIN:VEVENT',
      'UID:${escape(uid)}@zentrip',
      'DTSTAMP:$stamp',
      'DTSTART:${local(start)}',
      'DTEND:${local(end)}',
      'SUMMARY:${escape(title)}',
      'LOCATION:${escape(location)}',
      'DESCRIPTION:${escape(description)}',
      'END:VEVENT',
      'END:VCALENDAR',
      '',
    ].join('\r\n');
  }

  Future<void> _addToCalendar(BuildContext context, CarLabels labels) async {
    final name = '${car.brand} ${car.model}'.trim();
    final ics = calendarEvent(
      uid: reference,
      title: labels.calendarTitle(name),
      location: pickupLocation,
      description: '${labels.bookingId}: $reference',
      start: params.pickupDate,
      end: params.returnDate,
    );
    try {
      await Share.shareXFiles([
        XFile.fromData(
          Uint8List.fromList(utf8.encode(ics)),
          name: 'zentrip-$reference.ics',
          mimeType: 'text/calendar',
        ),
      ], fileNameOverrides: [
        'zentrip-$reference.ics'
      ]);
    } catch (_) {
      if (context.mounted) AppSnackbar.error(context, labels.calendarFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = CarLabels(AppLocalizations.of(context));
    final name = '${car.brand} ${car.model}'.trim();
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
                labels.bookingConfirmed,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: carInk(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                labels.allSet,
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
                            labels.bookingId,
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
                      tooltip: labels.copy,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: reference));
                        if (context.mounted) {
                          AppSnackbar.success(context, labels.copied);
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
                    SizedBox(
                      width: 104,
                      child: CarPhoto(
                        car: car,
                        height: 70,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _IconLine(
                            icon: Icons.calendar_today_outlined,
                            maxLines: 2,
                            text: '${labels.dayMonth(params.pickupDate)} '
                                '${labels.time(params.pickupDate)} – '
                                '${labels.dayMonth(params.returnDate)} '
                                '${labels.time(params.returnDate)}',
                          ),
                          const SizedBox(height: 4),
                          _IconLine(
                            icon: Icons.location_on_outlined,
                            text: dropoffLocation == pickupLocation
                                ? pickupLocation
                                : '$pickupLocation → $dropoffLocation',
                          ),
                          const SizedBox(height: 4),
                          CarProviderLine(car: car, labels: labels),
                          const SizedBox(height: 4),
                          _IconLine(
                            icon: Icons.payments_outlined,
                            text: paidText,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  key: const ValueKey('car-view-booking'),
                  onPressed: () => AppDockBar.leaveTo(context, _tripsTab),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.06),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(labels.viewBookingDetails),
                ),
              ),
              const SizedBox(height: 12),
              CarCtaButton(
                buttonKey: const ValueKey('car-add-calendar'),
                label: labels.addToCalendar,
                onPressed: () => _addToCalendar(context, labels),
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
