import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_loading_overlay.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../global_widgets/payment_methods_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/car_model.dart';
import '../../../notifications/logic/notifications_store.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';
import 'car_booking_confirmed_screen.dart';
import 'car_rental_screen.dart' show CarDailyPrice;
import '../../../../global_widgets/ui/ui.dart';

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
  late CarSearchParams _params = widget.params;

  Future<void> _changePickup() async {
    final picked = await pickCarDateTime(
      context,
      initial: _params.pickupDate,
      first: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    var back = _params.returnDate;
    if (!back.isAfter(picked)) {
      back = DateTime(picked.year, picked.month, picked.day + 1, picked.hour,
          picked.minute);
    }
    setState(
        () => _params = _params.copyWith(pickupDate: picked, returnDate: back));
  }

  Future<void> _changeReturn() async {
    final labels = CarLabels(AppLocalizations.of(context));
    final picked = await pickCarDateTime(
      context,
      initial: _params.returnDate,
      first: _params.pickupDate,
    );
    if (picked == null || !mounted) return;
    if (!picked.isAfter(_params.pickupDate)) {
      AppSnackbar.error(context, labels.dropoffAfterPickup);
      return;
    }
    setState(() => _params = _params.copyWith(returnDate: picked));
  }

  CarModel get _car => widget.car;
  CarRentalPriceBreakdown get _pricing => _car.pricingForDays(_params.days);

  String get _pickupLocation =>
      _car.pickupPlace.trim().isNotEmpty ? _car.pickupPlace : _params.city;
  String get _dropoffLocation => _params.dropoffCity.trim().isNotEmpty
      ? _params.dropoffCity
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
    final params = _params;

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
    final params = _params;
    final pricing = _pricing;
    final charge = _charge(context);
    final totalText = formatCurrencyAmount(
      charge.amount,
      charge.currency,
      locale: Localizations.localeOf(context).languageCode,
    );
    final name = '${_car.brand} ${_car.model}'.trim();

    return Scaffold(
      backgroundColor: context.uiPageBackground,
      appBar: AppBar(
        backgroundColor: context.uiPageBackground,
        surfaceTintColor: AppColors.transparent,
        centerTitle: true,
        title: Text(
          labels.bookingPayment,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: context.uiInk,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AppCard(
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
                              color: context.uiInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          CarDailyPrice(
                            car: _car,
                            labels: labels,
                            fontSize: 15,
                          ),
                          const SizedBox(height: 6),
                          CarProviderLine(car: _car, labels: labels),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: context.uiBorder),
                _Stop(
                  title: labels.pickup,
                  date: labels.dateTime(params.pickupDate),
                  place: _pickupLocation,
                  changeLabel: labels.changeTime,
                  onTap: _submitting ? null : _changePickup,
                ),
                Divider(height: 1, color: context.uiBorder),
                _Stop(
                  title: labels.dropoff,
                  date: labels.dateTime(params.returnDate),
                  place: _dropoffLocation,
                  changeLabel: labels.changeTime,
                  onTap: _submitting ? null : _changeReturn,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
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
                Divider(height: 1, color: context.uiBorder),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        labels.totalAmount,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.uiInk,
                        ),
                      ),
                    ),
                    Text(
                      totalText,
                      key: const ValueKey('car-total'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PaymentMethodsCard(
            title: labels.paymentMethod,
            cardTitle: labels.cardPayment,
            cardNote: labels.cardPaymentNote,
            secureNote: labels.secureNote,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: context.uiSurface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: AppButton.label(
              key: const ValueKey('car-pay'),
              text: labels.pay(totalText),
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
          color: context.uiInk,
        ),
      );
}

class _Stop extends StatelessWidget {
  final String title;
  final String date;
  final String place;
  final String changeLabel;
  final VoidCallback? onTap;

  const _Stop({
    required this.title,
    required this.date,
    required this.place,
    required this.changeLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title $date, $place. $changeLabel',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 12, color: context.uiMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: context.uiInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place,
                        style:
                            TextStyle(fontSize: 12.5, color: context.uiMuted),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_calendar_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
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
                style: TextStyle(fontSize: 13, color: context.uiMuted),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.uiInk,
              ),
            ),
          ],
        ),
      );
}
