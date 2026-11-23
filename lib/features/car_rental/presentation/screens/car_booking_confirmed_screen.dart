import 'package:flutter/material.dart';

import '../../../../global_widgets/booking_confirmed_view.dart';
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

  @override
  Widget build(BuildContext context) {
    final labels = CarLabels(AppLocalizations.of(context));
    return BookingConfirmedView(
      title: labels.bookingConfirmed,
      subtitle: labels.allSet,
      bookingIdLabel: labels.bookingId,
      copyTooltip: labels.copy,
      copiedMessage: labels.copied,
      viewDetailsLabel: labels.viewBookingDetails,
      okLabel: labels.ok,
      reference: reference,
      name: '${car.brand} ${car.model}'.trim(),
      photo: CarPhoto(
        car: car,
        height: 70,
        borderRadius: BorderRadius.circular(12),
      ),
      lines: [
        (
          Icons.calendar_today_outlined,
          '${labels.dayMonth(params.pickupDate)} '
              '${labels.time(params.pickupDate)} – '
              '${labels.dayMonth(params.returnDate)} '
              '${labels.time(params.returnDate)}',
        ),
        (
          Icons.location_on_outlined,
          dropoffLocation == pickupLocation
              ? pickupLocation
              : '$pickupLocation → $dropoffLocation',
        ),
        (Icons.payments_outlined, paidText),
      ],
      provider: CarProviderLine(car: car, labels: labels),
    );
  }
}
