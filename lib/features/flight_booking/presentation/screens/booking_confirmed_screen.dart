import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../global_widgets/currency_amount_text.dart';
import '../../../../features/notifications/logic/notifications_store.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_booking_model.dart';
import '../../logic/flight_checkout_passenger.dart';
import '../../logic/tickets_pdf.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../models/flight_model.dart';
import 'flight_checkout_shared_components.dart';
import '../../../../global_widgets/ui/ui.dart';

class BookingConfirmedScreen extends StatefulWidget {
  final FlightBookingDraft draft;
  final FlightBookingConfirmation? initialConfirmation;

  const BookingConfirmedScreen({
    super.key,
    required this.draft,
    this.initialConfirmation,
  });

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> {
  FlightBookingConfirmation? _confirmation;
  String? _error;
  bool _loading = true;
  bool _savingPdf = false;

  /// Saves every ticket of this booking in ONE PDF (a page per traveler).
  Future<void> _saveTicketsPdf({
    required FlightBookingConfirmation confirmation,
    required List<String> seats,
    required String totalText,
    required String? passengerName,
  }) async {
    if (_savingPdf) return;
    final l10n = AppLocalizations.of(context);
    final labels = CheckoutLabels(l10n);
    final ar = l10n.localeName.startsWith('ar');
    final locale = Localizations.localeOf(context).languageCode;
    setState(() => _savingPdf = true);
    try {
      final tickets = ticketEntries(
        reference: confirmation.reference,
        travelers: widget.draft.travelers,
        fallbackSeats: seats,
        typeLabel: (t) => switch (t) {
          FlightTravelerType.adult => labels.adult,
          FlightTravelerType.child => labels.child,
          FlightTravelerType.infant => labels.infant,
        },
        onLap: labels.onLap,
        fallbackName: passengerName,
      );
      final bytes = await buildTicketsPdf(
        flight: widget.draft.flight,
        reference: confirmation.reference,
        seatClassLabel: widget.draft.seatClass.isEmpty
            ? ''
            : widget.draft.seatClass[0].toUpperCase() +
                widget.draft.seatClass.substring(1),
        totalText: totalText,
        tickets: tickets,
        rtl: ar,
        locale: locale,
        labels: TicketPdfLabels(
          title: ar ? 'تذاكر' : 'Tickets',
          passenger: ar ? 'المسافر' : 'Passenger',
          seat: ar ? 'المقعد' : 'Seat',
          seatClass: ar ? 'الدرجة' : 'Class',
          flight: ar ? 'الرحلة' : 'Flight',
          date: ar ? 'التاريخ' : 'Date',
          departure: ar ? 'الإقلاع' : 'Departure',
          arrival: ar ? 'الوصول' : 'Arrival',
          duration: ar ? 'المدة' : 'Duration',
          reference: l10n.flightBookingReferenceLabel,
          total: labels.travellerPrice(widget.draft.travelers.length),
          ticket: ar ? 'التذكرة' : 'Ticket',
        ),
      );
      await shareTicketsPdf(bytes, confirmation.reference);
    } catch (_) {
      if (mounted) {
        AppSnackbar.error(
          context,
          ar ? 'تعذّر إنشاء ملف PDF' : 'Could not create the PDF',
        );
      }
    } finally {
      if (mounted) setState(() => _savingPdf = false);
    }
  }

  String get _flightId {
    final flight = widget.draft.flight;
    return flight.partnerListingId?.toString() ??
        flight.id.replaceFirst(RegExp(r'^partner-'), '');
  }

  @override
  void initState() {
    super.initState();
    final initialConfirmation = widget.initialConfirmation;
    if (initialConfirmation != null) {
      _confirmation = initialConfirmation;
      _loading = false;
    } else {
      _confirmBooking();
    }
  }

  Future<void> _confirmBooking() async {
    if (_loading && _confirmation != null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ApiService.instance.confirmFlightBooking(
        flightId: _flightId,
        seats: widget.draft.seats,
        seatClass: widget.draft.seatClass,
        returnDate: widget.draft.returnDate,
        extras: widget.draft.extras,
        paymentAttemptId: widget.draft.paymentAttemptId,
        packageOfferId: widget.draft.packageOffer?.id,
        bookingCurrencyCode: widget.draft.currencyCode,
        bookingDisplayAmount: widget.draft.totalPrice,
        passengers: [for (final t in widget.draft.travelers) t.toJson()],
      );
      if (!mounted) return;
      if (result.isFailure || result.data == null) {
        setState(() {
          _loading = false;
          _error = result.errorMessage ??
              AppLocalizations.of(context).flightConfirmationError;
        });
        return;
      }
      setState(() {
        _confirmation = result.data;
        _loading = false;
      });
      unawaited(NotificationsStore.instance.refreshAfterBooking(
        title: AppLocalizations.of(context).notifBookingConfirmedTitle,
        subtitle:
            '${widget.draft.flight.originCity} → ${widget.draft.flight.destinationCity}',
        bookingRef: result.data!.reference,
      ));
    } catch (error, stackTrace) {
      debugPrint('Flight booking confirmation failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _backToHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.white,
        // The theme's title colour (dark text) overrides foregroundColor, so
        // the title was invisible on the dark background.
        titleTextStyle: Theme.of(context)
            .appBarTheme
            .titleTextStyle
            ?.copyWith(color: AppColors.white),
        title: Text(l10n.flightBookingConfirmed),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.white),
                  const SizedBox(height: 16),
                  Text(
                    l10n.flightBookingInProgress,
                    style: const TextStyle(color: AppColors.white),
                  ),
                ],
              ),
            )
          : _error != null
              ? _ConfirmationError(
                  message: _error!,
                  onRetry: _confirmBooking,
                  onBack: _backToHome,
                )
              : _confirmation == null
                  ? _ConfirmationError(
                      message: l10n.flightConfirmationError,
                      onRetry: _confirmBooking,
                      onBack: _backToHome,
                    )
                  : _receipt(context, _confirmation!, l10n),
    );
  }

  String _ticketHeading(
    AppLocalizations l10n,
    List<FlightCheckoutPassenger> travelers,
    int index,
  ) {
    final labels = CheckoutLabels(l10n);
    final type = switch (travelers[index].type) {
      FlightTravelerType.adult => labels.adult,
      FlightTravelerType.child => labels.child,
      FlightTravelerType.infant => labels.infant,
    };
    final ar = l10n.localeName.startsWith('ar');
    final heading = ar
        ? 'التذكرة ${index + 1} من ${travelers.length}'
        : 'Ticket ${index + 1} of ${travelers.length}';
    return '$heading · $type';
  }

  Widget _receipt(
    BuildContext context,
    FlightBookingConfirmation confirmation,
    AppLocalizations l10n,
  ) {
    final flight = widget.draft.flight;
    final seats =
        confirmation.seats.isEmpty ? widget.draft.seats : confirmation.seats;
    final extras =
        confirmation.extras.isEmpty ? widget.draft.extras : confirmation.extras;
    final travelers = widget.draft.travelers;
    // Show what was actually charged. The partner confirm API returns its own
    // total in USD (total_price) without the display amount, which was then
    // shown with the booking currency's label (e.g. "LYD 118.400" for 118.40
    // USD), so use the charged amount from the draft. A Duffel confirmation is
    // built in the app from the saved trip and is already in that currency.
    final fromServer = widget.initialConfirmation == null;
    final paidAmount =
        fromServer ? widget.draft.totalPrice : confirmation.totalPrice;
    final paidCurrency = fromServer
        ? widget.draft.currencyCode
        : confirmation.trip.bookingCurrencyCode;
    final passengerName =
        ApiService.instance.currentUser?.name.trim().isNotEmpty == true
            ? ApiService.instance.currentUser!.name
            : null;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            MaterialLocalizations.of(context)
                .formatMediumDate(flight.departureTime),
            style: const TextStyle(
              color: AppColors.darkTextSecondary,
              fontSize: 12,
            ),
          ),
          if (flight.isDuffelOffer) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  l10n.flightSimulationBadge,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${flight.originCity} to ${flight.destinationCity}',
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          if (travelers.length <= 1)
            FlightTicketCard(
              flight: flight,
              reference: confirmation.reference,
              seats: seats,
              seatClass: widget.draft.seatClass,
              totalPrice: paidAmount,
              currencyCode: paidCurrency,
              passengerName:
                  travelers.isNotEmpty && travelers.first.name.trim().isNotEmpty
                      ? travelers.first.name
                      : passengerName,
            )
          else ...[
            // A ticket for every traveler (own name, seat and code) under
            // one booking reference; the total is shown once below.
            for (var i = 0; i < travelers.length; i++) ...[
              if (i > 0) const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                child: Text(
                  _ticketHeading(l10n, travelers, i),
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FlightTicketCard(
                key: ValueKey('ticket-$i'),
                flight: flight,
                reference: confirmation.reference,
                ticketCode: '${confirmation.reference}-${i + 1}',
                seats: [
                  travelers[i].seat ??
                      (travelers[i].type == FlightTravelerType.infant
                          ? CheckoutLabels(l10n).onLap
                          : '—'),
                ],
                seatClass: widget.draft.seatClass,
                totalPrice: null,
                currencyCode: paidCurrency,
                passengerName: travelers[i].name,
              ),
            ],
            const SizedBox(height: 22),
            Container(
              key: const ValueKey('booking-total'),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.flightBookingReferenceLabel,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        Text(confirmation.reference,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        CheckoutLabels(l10n).travellerPrice(travelers.length),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11),
                      ),
                      Text(
                        checkoutMoney(
                          paidCurrency,
                          paidAmount,
                          locale: Localizations.localeOf(context).languageCode,
                        ),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (widget.draft.packageOffer case final offer?) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.displayTitle(
                      Localizations.localeOf(context).languageCode,
                    ),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.hotelNightsSummary(offer.durationNights),
                    style: const TextStyle(
                      color: AppColors.darkTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CurrencyAmountText(
                    amount: offer.hotelPricePerNight *
                        offer.durationNights *
                        widget.draft.passengerCount,
                    prefix: '${l10n.packageStayTotal}: ',
                    decimalDigits: 2,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (extras.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final extra in extras)
                  _TicketExtraChip(
                    label: extra == 'extra_baggage'
                        ? l10n.flightExtraBaggage
                        : l10n.flightFlexibleTicket,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Center(
            child: AppButton.icon(
              key: const ValueKey('save-tickets-pdf'),
              onPressed: _savingPdf
                  ? null
                  : () => _saveTicketsPdf(
                        confirmation: confirmation,
                        seats: seats,
                        totalText: checkoutMoney(
                          paidCurrency,
                          paidAmount,
                          locale: Localizations.localeOf(context).languageCode,
                        ),
                        passengerName: passengerName,
                      ),
              icon: _savingPdf
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 20),
              label: Text(
                l10n.localeName.startsWith('ar')
                    ? (travelers.length > 1
                        ? 'حفظ كل التذاكر (PDF)'
                        : 'حفظ التذكرة (PDF)')
                    : (travelers.length > 1
                        ? 'Save all tickets (PDF)'
                        : 'Save ticket (PDF)'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.white54),
                minimumSize: const Size(260, 50),
                shape: const StadiumBorder(),
              ),
              variant: AppButtonVariant.secondary,
            ),
          ),
          const SizedBox(height: 14),
          AppButton.label(
            text: l10n.flightBackToHome,
            onPressed: _backToHome,
            iconData: Icons.home_rounded,
          ),
        ],
      ),
    );
  }
}

class FlightTicketCard extends StatelessWidget {
  final FlightModel flight;
  final String reference;
  final List<String> seats;
  final String seatClass;

  /// Null on a per-traveler ticket: the booking total is shown once below.
  final double? totalPrice;
  final String currencyCode;
  final String? passengerName;

  /// Code encoded in this ticket's QR/barcode; defaults to the reference.
  final String? ticketCode;

  const FlightTicketCard({
    super.key,
    required this.flight,
    required this.reference,
    required this.seats,
    required this.seatClass,
    required this.totalPrice,
    required this.currencyCode,
    this.passengerName,
    this.ticketCode,
  });

  String get _code => ticketCode ?? reference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizations = MaterialLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.flight_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        flight.airline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        seatClass.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      TimeOfDay.fromDateTime(flight.departureTime)
                          .format(context),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TicketFlightLine(
                        duration: _formatDuration(flight.durationMinutes),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      TimeOfDay.fromDateTime(flight.arrivalTime)
                          .format(context),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TicketRoutePoint(
                      code: flight.originCode,
                      city: flight.originCity,
                    ),
                    _TicketRoutePoint(
                      code: flight.destinationCode,
                      city: flight.destinationCity,
                      alignEnd: true,
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localizations.formatMediumDate(flight.departureTime),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Flexible(
                      child: _TicketDetail(
                        alignEnd: true,
                        label: l10n.flightAircraft,
                        value: flight.aircraftName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TicketDetail(
                        label: l10n.flightPassengerInfo,
                        value: passengerName ?? l10n.flightDemoUser,
                      ),
                    ),
                    Expanded(
                      child: _TicketDetail(
                        label: l10n.flightSelectedSeats,
                        value: seats.isEmpty ? '—' : seats.join(', '),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TicketDetail(
                        label: l10n.flightNumber,
                        value: flight.flightNumber,
                      ),
                    ),
                    Expanded(
                      child: _TicketDetail(
                        label: l10n.flightDuration,
                        value: _formatDuration(flight.durationMinutes),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 26,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final dashCount = (constraints.maxWidth / 9).floor();
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          dashCount,
                          (_) => Container(
                            width: 4,
                            height: 1.2,
                            color: AppColors.border,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned(
                  left: -12,
                  child: _TicketNotch(),
                ),
                Positioned(
                  right: -12,
                  child: _TicketNotch(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _TicketDetail(
                        label: l10n.flightBookingReferenceLabel,
                        value: reference,
                        valueSize: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (totalPrice != null) ...[
                      _TicketDetail(
                        label: l10n.flightTotal,
                        value: checkoutMoney(
                          currencyCode,
                          totalPrice!,
                          locale: Localizations.localeOf(context).languageCode,
                        ),
                        valueSize: 17,
                        alignEnd: true,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Semantics(
                      button: true,
                      label: '${l10n.yourTicket}: $_code',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () => _showTicketQr(context, _code, l10n),
                        child: QrImageView(
                          data: _code,
                          size: 54,
                          padding: EdgeInsets.zero,
                          backgroundColor: AppColors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 58,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarcodePainter(_code),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return hours == 0
        ? '${remainingMinutes}m'
        : '${hours}h ${remainingMinutes}m';
  }

  static Future<void> _showTicketQr(
    BuildContext context,
    String reference,
    AppLocalizations l10n,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: reference,
                size: 240,
                backgroundColor: AppColors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.flightBookingReferenceLabel,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              SelectableText(
                reference,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TicketRoutePoint extends StatelessWidget {
  final String code;
  final String city;
  final bool alignEnd;

  const _TicketRoutePoint({
    required this.code,
    required this.city,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            city,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      );
}

class _TicketDetail extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  final double valueSize;

  const _TicketDetail({
    required this.label,
    required this.value,
    this.alignEnd = false,
    this.valueSize = 13,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: valueSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _TicketFlightLine extends StatelessWidget {
  final String duration;

  const _TicketFlightLine({required this.duration});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            duration,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 5),
          // On narrow phones (long localized times) keep only the plane so
          // the ticket never overflows.
          LayoutBuilder(
            builder: (context, constraints) {
              const plane = DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.flight_rounded,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              );
              if (constraints.maxWidth < 60) {
                return const FittedBox(fit: BoxFit.scaleDown, child: plane);
              }
              return Row(
                children: [
                  const _TicketRouteDot(),
                  Expanded(
                    child: Container(height: 1, color: AppColors.border),
                  ),
                  plane,
                  Expanded(
                    child: Container(height: 1, color: AppColors.border),
                  ),
                  const _TicketRouteDot(),
                ],
              );
            },
          ),
        ],
      );
}

class _TicketRouteDot extends StatelessWidget {
  const _TicketRouteDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          shape: BoxShape.circle,
        ),
      );
}

class _TicketNotch extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: AppColors.darkBackground,
          shape: BoxShape.circle,
        ),
      );
}

class _BarcodePainter extends CustomPainter {
  final String seed;

  const _BarcodePainter(this.seed);

  @override
  void paint(Canvas canvas, Size size) {
    if (seed.isEmpty || size.isEmpty) return;
    final paint = Paint()..color = AppColors.textPrimary;
    // Seeded Random: same bars for the same code on every platform. The old
    // LCG multiply exceeded JavaScript number precision on web and drew a
    // single bar.
    final random = math.Random(seed.hashCode & 0x7fffffff);
    var x = 0.0;
    while (x < size.width) {
      final width = 1.2 + random.nextInt(3).toDouble();
      if (random.nextBool()) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, width, size.height),
          paint,
        );
      }
      x += width + 1.4;
    }
  }

  @override
  bool shouldRepaint(_BarcodePainter oldDelegate) => oldDelegate.seed != seed;
}

class _TicketExtraChip extends StatelessWidget {
  final String label;

  const _TicketExtraChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceSecondary,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _ConfirmationError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _ConfirmationError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.accentRed, size: 52),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white),
            ),
            const SizedBox(height: 20),
            AppButton.label(
              text: l10n.retry,
              iconData: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
            const SizedBox(height: 10),
            AppButton(
              onPressed: onBack,
              child: Text(l10n.flightBackToHome),
              variant: AppButtonVariant.text,
            ),
          ],
        ),
      ),
    );
  }
}
