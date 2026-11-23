import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_loading_overlay.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/car_model.dart';
import '../../../notifications/logic/notifications_store.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';
import 'car_booking_confirmed_screen.dart';
import 'car_rental_screen.dart' show CarDailyPrice;

/// Opens the payment page for [amount] in [currency]; returns the payment
/// attempt id when paid, null otherwise. Replaceable in tests.
typedef CarPaymentLauncher = Future<({bool paid, int? attemptId})?> Function(
  BuildContext context, {
  required double amount,
  required String currency,
  required String description,
  required String reference,
});

/// "Booking & Payment": order summary, price details and Pay.
class CarBookingScreen extends StatefulWidget {
  final CarModel car;
  final CarSearchParams params;
  final CarPaymentLauncher? paymentLauncher;

  const CarBookingScreen({
    super.key,
    required this.car,
    required this.params,
    this.paymentLauncher,
  });

  @override
  State<CarBookingScreen> createState() => _CarBookingScreenState();
}

class _CarBookingScreenState extends State<CarBookingScreen> {
  bool _submitting = false;

  CarModel get _car => widget.car;
  CarRentalPriceBreakdown get _pricing =>
      _car.pricingForDays(widget.params.days);

  String get _pickupLocation => _car.pickupLocation.trim().isNotEmpty
      ? _car.pickupLocation
      : widget.params.city;
  String get _dropoffLocation => widget.params.dropoffCity.trim().isNotEmpty
      ? widget.params.dropoffCity
      : _pickupLocation;

  /// Amount and currency actually charged: the profile currency when a rate
  /// is available (rounded to its minor units), otherwise USD.
  ({double amount, String currency}) _charge(BuildContext context) {
    final converted = convertPrice(context, _pricing.totalPrice);
    final currency = converted == null ? 'USD' : userCurrencyCode(context);
    final amount = converted ?? _pricing.totalPrice;
    final digits = currencyDecimalDigits(currency);
    return (
      amount: double.parse(amount.toStringAsFixed(digits)),
      currency: currency,
    );
  }

  Future<({bool paid, int? attemptId})?> _openPayment(
    BuildContext context, {
    required double amount,
    required String currency,
    required String description,
    required String reference,
  }) async {
    final receipt = await PaymentCheckoutScreen.start(
      context,
      amountUsd: amount,
      currencyCode: currency,
      description: description,
      referenceId: reference,
    );
    if (receipt == null) return null;
    return (paid: receipt.paid, attemptId: receipt.attemptId);
  }

  Future<void> _pay() async {
    if (_submitting) return;
    final l10n = AppLocalizations.of(context);
    final labels = CarLabels(l10n);
    final car = _car;
    final name = '${car.brand} ${car.model}'.trim();
    if (car.availableVehicles < 1) {
      AppSnackbar.error(context, labels.soldOut);
      return;
    }
    setState(() => _submitting = true);
    final params = widget.params;

    final availability = await ApiService.instance.checkBookingAvailability(
      type: BookingType.car,
      title: name,
      startDate: params.pickupDate,
      endDate: params.returnDate,
    );
    if (!mounted) return;
    if (availability.isFailure || availability.data != true) {
      setState(() => _submitting = false);
      AppSnackbar.error(
        context,
        availability.isFailure
            ? availability.errorMessage ?? l10n.genericError
            : l10n.bookingScheduleConflict,
      );
      return;
    }

    final reference =
        'ZT-C-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final charge = _charge(context);
    final payment = await (widget.paymentLauncher ?? _openPayment)(
      context,
      amount: charge.amount,
      currency: charge.currency,
      description: name,
      reference: reference,
    );
    if (!mounted) return;
    if (payment?.paid != true) {
      setState(() => _submitting = false);
      AppSnackbar.error(context, l10n.paymentFailedMessage);
      return;
    }

    final booking = BookingModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: BookingType.car,
      title: name,
      subtitle: _dropoffLocation == _pickupLocation
          ? _pickupLocation
          : '$_pickupLocation → $_dropoffLocation',
      date: params.pickupDate,
      endDate: params.returnDate,
      price: _pricing.totalPrice,
      refCode: reference,
      status: 'upcoming',
      imageUrl: car.imageUrl,
      partnerListingId: car.partnerListingId,
      bookingCurrencyCode: charge.currency,
      bookingDisplayAmount: charge.amount,
    );
    final created = await BookingLoadingOverlay.run(
      context,
      title: l10n.hotelBookingInProgress,
      subtitle: name,
      serviceIcon: Icons.directions_car_rounded,
      action: () => ApiService.instance.createBooking(
        booking,
        paymentAttemptId: payment!.attemptId,
      ),
    );
    if (!mounted) return;
    if (created.isFailure) {
      setState(() => _submitting = false);
      AppSnackbar.error(
        context,
        created.errorMessage == 'BOOKING_SCHEDULE_CONFLICT'
            ? l10n.bookingScheduleConflict
            : created.errorMessage ?? l10n.genericError,
      );
      return;
    }
    unawaited(NotificationsStore.instance.refreshAfterBooking(
      title: l10n.notifBookingConfirmedTitle,
      subtitle: name,
      bookingRef: reference,
    ));
    final paidText = formatCurrencyAmount(
      charge.amount,
      charge.currency,
      locale: Localizations.localeOf(context).languageCode,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CarBookingConfirmedScreen(
          car: car,
          params: params,
          reference: created.data?.refCode?.isNotEmpty == true
              ? created.data!.refCode!
              : reference,
          pickupLocation: _pickupLocation,
          dropoffLocation: _dropoffLocation,
          paidText: paidText,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = CarLabels(AppLocalizations.of(context));
    final params = widget.params;
    final pricing = _pricing;
    final charge = _charge(context);
    final totalText = formatCurrencyAmount(
      charge.amount,
      charge.currency,
      locale: Localizations.localeOf(context).languageCode,
    );
    final name = '${_car.brand} ${_car.model}'.trim();

    return Scaffold(
      backgroundColor: carPageBackground(context),
      appBar: AppBar(
        backgroundColor: carPageBackground(context),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          labels.bookingPayment,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: carInk(context),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          CarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 110,
                      child: CarPhoto(
                        car: _car,
                        height: 72,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          CarDailyPrice(
                            car: _car,
                            labels: labels,
                            fontSize: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: carBorder(context)),
                _Stop(
                  title: labels.pickup,
                  date: labels.shortDate(params.pickupDate),
                  place: _pickupLocation,
                ),
                Divider(height: 1, color: carBorder(context)),
                _Stop(
                  title: labels.dropoff,
                  date: labels.shortDate(params.returnDate),
                  place: _dropoffLocation,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Heading(labels.priceDetails),
                const SizedBox(height: 10),
                _PriceRow(
                  labels.daysLine(
                    formatPrice(context, pricing.pricePerDay),
                    pricing.numberOfDays,
                  ),
                  formatPrice(context, pricing.subtotal),
                ),
                _PriceRow(
                  labels.insurance,
                  formatPrice(context, pricing.insuranceFee),
                ),
                _PriceRow(
                  labels.l10n.carServiceFee,
                  formatPrice(context, pricing.serviceFee),
                ),
                const SizedBox(height: 6),
                Divider(height: 1, color: carBorder(context)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels.totalAmount,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: carInk(context),
                        ),
                      ),
                    ),
                    Text(
                      totalText,
                      key: const ValueKey('car-total'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: carCtaColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CarCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Heading(labels.paymentMethod),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels.cardPayment,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: carInk(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            labels.cardPaymentNote,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: carMuted(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: carMuted(context),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        labels.secureNote,
                        style: TextStyle(
                          fontSize: 11,
                          color: carMuted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: carSurface(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: CarCtaButton(
              buttonKey: const ValueKey('car-pay'),
              label: labels.pay(totalText),
              loading: _submitting,
              onPressed: _pay,
            ),
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: carInk(context),
        ),
      );
}

class _Stop extends StatelessWidget {
  final String title;
  final String date;
  final String place;

  const _Stop({required this.title, required this.date, required this.place});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 12, color: carMuted(context))),
            const SizedBox(height: 4),
            Text(
              date,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: carInk(context),
              ),
            ),
            const SizedBox(height: 2),
            Text(place,
                style: TextStyle(fontSize: 12.5, color: carMuted(context))),
          ],
        ),
      );
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  const _PriceRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 13, color: carMuted(context)),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: carInk(context),
              ),
            ),
          ],
        ),
      );
}
