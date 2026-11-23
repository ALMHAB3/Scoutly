import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_confirmed_view.dart';
import '../../../../global_widgets/booking_loading_overlay.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/booking_model.dart';
import '../../../../models/hotel_model.dart';
import '../../../car_rental/presentation/widgets/car_widgets.dart';
import '../../../notifications/logic/notifications_store.dart';
import '../../logic/hotel_controller.dart';
import '../hotel_labels.dart';
import '../widgets/hotel_widgets.dart';

/// Opens the payment page for [amount] in [currency]. Replaceable in tests.
typedef HotelPaymentLauncher = Future<({bool paid, int? attemptId})?> Function(
  BuildContext context, {
  required double amount,
  required String currency,
  required String description,
  required String reference,
});

/// "Booking & Payment" for a hotel: the stay, price details and Pay
/// (same design as the car booking screen). Charged in the profile currency.
class HotelBookingScreen extends StatefulWidget {
  final HotelModel hotel;
  final HotelSearchParams params;
  final HotelPaymentLauncher? paymentLauncher;

  const HotelBookingScreen({
    super.key,
    required this.hotel,
    required this.params,
    this.paymentLauncher,
  });

  @override
  State<HotelBookingScreen> createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends State<HotelBookingScreen> {
  bool _submitting = false;

  HotelModel get _hotel => widget.hotel;
  int get _nights => widget.params.nights.clamp(1, 99).toInt();
  int get _rooms => widget.params.rooms;
  HotelPriceBreakdown get _pricing => _hotel.pricingFor(_nights, rooms: _rooms);

  String _price(double amount) =>
      formatPrice(context, amount, from: _hotel.priceCurrencyCode);

  /// Amount and currency actually charged: the profile currency when a rate
  /// is available (rounded to its minor units), otherwise the hotel's.
  ({double amount, String currency}) _charge() {
    final total = _pricing.totalPrice;
    final converted =
        convertPrice(context, total, from: _hotel.priceCurrencyCode);
    final currency = converted == null
        ? _hotel.priceCurrencyCode.toUpperCase()
        : userCurrencyCode(context);
    final digits = currencyDecimalDigits(currency);
    return (
      amount: double.parse((converted ?? total).toStringAsFixed(digits)),
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
    final hotel = _hotel;
    final params = widget.params;
    if (hotel.availabilityKnown && hotel.availableRooms < _rooms) {
      AppSnackbar.error(context, l10n.hotelSoldOut);
      return;
    }
    setState(() => _submitting = true);
    final availability = await ApiService.instance.checkBookingAvailability(
      type: BookingType.hotel,
      title: hotel.name,
      startDate: params.checkIn,
      endDate: params.checkOut,
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
        'ZT-H-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final charge = _charge();
    final payment = await (widget.paymentLauncher ?? _openPayment)(
      context,
      amount: charge.amount,
      currency: charge.currency,
      description: hotel.name,
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
      type: BookingType.hotel,
      title: hotel.name,
      subtitle: hotel.address.isEmpty ? hotel.city : hotel.address,
      date: params.checkIn,
      endDate: params.checkOut,
      price: _pricing.totalPrice,
      refCode: reference,
      status: 'upcoming',
      imageUrl: hotel.imageUrl,
      partnerListingId: hotel.partnerListingId,
      rooms: _rooms,
      bookingCurrencyCode: charge.currency,
      bookingDisplayAmount: charge.amount,
    );
    final created = await BookingLoadingOverlay.run(
      context,
      title: l10n.hotelBookingInProgress,
      subtitle: hotel.name,
      serviceIcon: Icons.hotel_rounded,
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
            : created.errorMessage == 'HOTEL_SOLD_OUT'
                ? l10n.hotelSoldOut
                : created.errorMessage ?? l10n.genericError,
      );
      return;
    }
    unawaited(NotificationsStore.instance.refreshAfterBooking(
      title: l10n.notifBookingConfirmedTitle,
      subtitle: hotel.name,
      bookingRef: reference,
    ));
    final paidText = formatCurrencyAmount(
      charge.amount,
      charge.currency,
      locale: Localizations.localeOf(context).languageCode,
    );
    final labels = HotelLabels(l10n);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BookingConfirmedView(
          title: labels.bookingConfirmed,
          subtitle: labels.allSet,
          bookingIdLabel: labels.bookingId,
          copyTooltip: labels.copy,
          copiedMessage: labels.copied,
          viewDetailsLabel: labels.viewBookingDetails,
          okLabel: labels.ok,
          reference: created.data?.refCode?.isNotEmpty == true
              ? created.data!.refCode!
              : reference,
          name: hotel.name,
          photo: HotelPhoto(
            hotel: hotel,
            height: 70,
            borderRadius: BorderRadius.circular(12),
          ),
          lines: [
            (
              Icons.calendar_today_outlined,
              '${labels.dayMonth(params.checkIn)} – '
                  '${labels.shortDate(params.checkOut)}',
            ),
            (
              Icons.bed_rounded,
              labels.stay(_nights, _rooms, params.guests),
            ),
            if (hotel.address.isNotEmpty)
              (Icons.location_on_outlined, hotel.address),
            (Icons.payments_outlined, paidText),
          ],
          provider: HotelProviderLine(hotel: hotel, labels: labels),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = HotelLabels(AppLocalizations.of(context));
    final params = widget.params;
    final pricing = _pricing;
    final charge = _charge();
    final totalText = formatCurrencyAmount(
      charge.amount,
      charge.currency,
      locale: Localizations.localeOf(context).languageCode,
    );

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
                      child: HotelPhoto(
                        hotel: _hotel,
                        height: 76,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hotel.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          HotelNightlyPrice(
                            hotel: _hotel,
                            labels: labels,
                            fontSize: 15,
                          ),
                          const SizedBox(height: 6),
                          HotelProviderLine(hotel: _hotel, labels: labels),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: carBorder(context)),
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stop(
                          title: labels.checkIn,
                          value: labels.weekdayDate(params.checkIn),
                          icon: Icons.login_rounded,
                        ),
                      ),
                      VerticalDivider(width: 1, color: carBorder(context)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stop(
                          title: labels.checkOut,
                          value: labels.weekdayDate(params.checkOut),
                          icon: Icons.logout_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: carBorder(context)),
                _Stop(
                  title: labels.yourStay,
                  value: labels.stay(_nights, _rooms, params.guests),
                  icon: Icons.bed_rounded,
                ),
                if (_hotel.address.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 15, color: carMuted(context)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _hotel.address,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: carMuted(context),
                          ),
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
                _Heading(labels.priceDetails),
                const SizedBox(height: 10),
                _PriceRow(
                  labels.nightsLine(
                      _price(_hotel.pricePerNight), _nights, _rooms),
                  _price(pricing.subtotal),
                ),
                _PriceRow(
                  labels.taxes(_hotel.taxAndFeesPercentage),
                  _price(pricing.taxAndFees),
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
                      key: const ValueKey('hotel-total'),
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
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.credit_card_rounded,
                          color: Colors.white, size: 18),
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
                                fontSize: 11.5, color: carMuted(context)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.radio_button_checked_rounded,
                        color: AppColors.primary),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 14, color: carMuted(context)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        labels.secureNote,
                        style:
                            TextStyle(fontSize: 11, color: carMuted(context)),
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
              buttonKey: const ValueKey('hotel-pay'),
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
  final String value;
  final IconData icon;

  const _Stop({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(fontSize: 12, color: carMuted(context))),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: carInk(context),
                    ),
                  ),
                ),
              ],
            ),
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
            const SizedBox(width: 8),
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
