import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
              CarCtaButton(
                buttonKey: const ValueKey('car-view-booking'),
                label: labels.viewBookingDetails,
                onPressed: () => AppDockBar.leaveTo(context, _tripsTab),
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
