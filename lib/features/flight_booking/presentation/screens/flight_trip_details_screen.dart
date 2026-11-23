import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_result.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_booking_model.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/flight_seat_map.dart';
import '../../../../models/travel_package_model.dart';
import '../../../../models/trip_model.dart';
import '../../logic/flight_checkout_passenger.dart';
import '../../logic/flight_controller.dart';
import 'booking_confirmed_screen.dart';
import 'flight_checkout_shared_components.dart';
import 'flight_review_pay_screen.dart';
import 'flight_seat_map_view.dart';
import 'flight_seat_widgets.dart';
import '../../../../global_widgets/ui/ui.dart';

typedef FlightSeatMapLoader = Future<ApiResult<FlightSeatMap>> Function(String);
typedef FlightPaymentLauncher = Future<bool> Function(
  BuildContext context, {
  required double amount,
  required String currencyCode,
  required String description,
  required String referenceId,
});
typedef FlightTripCreator = Future<ApiResult<TripModel>> Function(TripModel);

/// One screen for the whole "Details" step: trip summary, fare, travelers and
/// seats. It replaces the former Fare, Passengers and Seats screens; the
/// "Pay" step is [FlightReviewPayScreen].
class FlightTripDetailsScreen extends StatefulWidget {
  final FlightController? controller;
  final FlightSeatMapLoader? seatMapLoader;
  final FlightPaymentLauncher? paymentLauncher;
  final FlightTripCreator? tripCreator;
  final TravelPackage? packageOffer;

  const FlightTripDetailsScreen({
    super.key,
    this.controller,
    this.seatMapLoader,
    this.paymentLauncher,
    this.tripCreator,
    this.packageOffer,
  });

  static const int maxTravelers = 9;

  @override
  State<FlightTripDetailsScreen> createState() =>
      _FlightTripDetailsScreenState();
}

class _FlightTripDetailsScreenState extends State<FlightTripDetailsScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _seatSectionKey = GlobalKey();
  final List<_TravelerEntry> _travelers = [];

  FlightController? _controller;
  bool _initialized = false;

  FlightSeatMap? _seatMap;
  String? _selectedFareId;
  String? _selectedCabinId;
  final Set<String> _selectedExtras = {};
  final Set<String> _heldSeats = {};
  bool _loading = true;
  bool _refreshing = false;
  String? _seatError;
  String? _flowError;
  int _activeSeatTraveler = 0;
  bool _seatsSkipped = false;
  bool _showSeatError = false;
  bool _submitted = false;
  bool _submitting = false;
  bool _acceptedFareRules = false;
  bool _reviewPushed = false;
  Timer? _refreshTimer;

  FlightModel? get _flight => _controller?.selectedFlight;
  FlightSearchParams? get _params => _controller?.searchParams;
  int get _searchPassengers =>
      (_params?.passengers ?? 1).clamp(1, FlightTripDetailsScreen.maxTravelers);
  bool get _isDuffel => _flight?.isDuffelOffer ?? false;
  String get _sourceCurrency =>
      _isDuffel ? (_flight?.priceCurrencyCode ?? 'USD') : 'USD';

  List<_TravelerEntry> get _seated =>
      _travelers.where((t) => t.type != FlightTravelerType.infant).toList();
  int _count(FlightTravelerType type) =>
      _travelers.where((t) => t.type == type).length;

  String? get _flightId {
    final flight = _flight;
    if (flight == null) return null;
    final id = flight.partnerListingId?.toString() ??
        flight.id.replaceFirst(RegExp(r'^partner-'), '');
    return RegExp(r'^\d+$').hasMatch(id) ? id : null;
  }

  FlightSeatFare? get _fare {
    final map = _seatMap;
    if (map == null || map.fares.isEmpty) return null;
    for (final fare in map.fares) {
      if (fare.id == _selectedFareId) return fare;
    }
    return map.fares.first;
  }

  FlightSeatCabin? get _cabin {
    final map = _seatMap;
    if (map == null || map.cabins.isEmpty) return null;
    for (final cabin in map.cabins) {
      if (cabin.id == _selectedCabinId) return cabin;
    }
    return map.cabins.first;
  }

  /// Duffel fares are a quoted total for the searched travelers, so the
  /// per-traveler price is that quote divided by the searched count.
  double _farePerTraveler(FlightSeatFare fare) =>
      _isDuffel ? fare.price / _searchPassengers : fare.price;

  int get _maxSeated {
    final fare = _fare;
    final available = _isDuffel ? null : fare?.availableSeats;
    if (available != null && available < FlightTripDetailsScreen.maxTravelers) {
      return available < 1 ? 1 : available;
    }
    return FlightTripDetailsScreen.maxTravelers;
  }

  // ── Prices (source currency, same formula as the backend) ───────────────

  int get _premiumSeatCount {
    final map = _seatMap;
    if (map == null) return 0;
    return _seated.where((t) {
      final seat = t.seat;
      if (seat == null) return false;
      final row = int.tryParse(seat.substring(0, seat.length - 1));
      return row != null && map.extraLegroomRows.contains(row);
    }).length;
  }

  double get _fareAmount {
    final fare = _fare;
    if (fare == null) return 0;
    return _farePerTraveler(fare) * _seated.length;
  }

  double get _seatFeesAmount =>
      _premiumSeatCount * (_seatMap?.extraLegroomFee ?? 0);

  double get _extrasAmount => _selectedExtras.fold<double>(
        0,
        (sum, key) => sum + (_seatMap?.extras[key] ?? 0),
      );

  double get _taxAmount =>
      (_fareAmount + _seatFeesAmount + _extrasAmount) *
      (_seatMap?.taxRate ?? 0);

  double get _bookingFee => _seatMap?.bookingFee ?? 0;

  double get _sourceFlightTotal =>
      _fareAmount + _seatFeesAmount + _extrasAmount + _taxAmount + _bookingFee;

  /// Package hotel stay is priced in USD per seated traveler and night.
  double get _packageStayTotal => widget.packageOffer == null
      ? 0
      : widget.packageOffer!.hotelPricePerNight *
          widget.packageOffer!.durationNights *
          _seated.length;

  /// Total in the user's currency, or null when no exchange rate exists.
  double? _userTotal(BuildContext context) {
    final flight =
        convertPrice(context, _sourceFlightTotal, from: _sourceCurrency);
    final stay = convertPrice(context, _packageStayTotal);
    if (flight == null || stay == null) return null;
    return flight + stay;
  }

  /// Amount + currency actually charged: the user's currency when a rate is
  /// available; otherwise the provider's own currency (never mislabelled).
  ({double amount, String currency}) _chargeFor(BuildContext context) {
    final converted = _userTotal(context);
    final currency =
        converted != null ? userCurrencyCode(context) : _sourceCurrency;
    final amount = converted ?? _sourceFlightTotal + _packageStayTotal;
    // Charge exactly what is displayed: rounded to the currency's minor
    // units (LYD 3, USD/EUR 2), without floating-point noise.
    return (amount: _roundMinor(amount, currency), currency: currency);
  }

  static double _roundMinor(double amount, String currency) {
    final digits = currencyDecimalDigits(currency);
    return double.parse(amount.toStringAsFixed(digits));
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _controller = widget.controller ?? (args is FlightController ? args : null);
    if (_flight == null) {
      _flowError = AppLocalizations.of(context).flightSearchError;
      _loading = false;
      return;
    }
    _travelers.add(_TravelerEntry.fromAccount(FlightTravelerType.adult));
    for (var i = 1; i < _searchPassengers; i++) {
      _travelers.add(_TravelerEntry(FlightTravelerType.adult));
    }
    _loadSeatMap();
    if (!_isDuffel) {
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _loadSeatMap(),
      );
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final traveler in _travelers) {
      traveler.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDuffel) _loadSeatMap();
  }

  // ── Seat map / fares ─────────────────────────────────────────────────────

  Future<void> _loadSeatMap() async {
    final flight = _flight;
    if (flight == null || _submitting || _refreshing) return;
    if (flight.isDuffelOffer) {
      _applyDuffelMap(flight);
      return;
    }
    final flightId = _flightId;
    if (flightId == null) {
      setState(() {
        _loading = false;
        _seatError = AppLocalizations.of(context).seatListingMissing;
      });
      return;
    }
    setState(() {
      _refreshing = true;
      if (_seatMap == null) _loading = true;
    });
    final result = await (widget.seatMapLoader ??
        ApiService.instance.getFlightSeatMap)(flightId);
    if (!mounted) return;
    var lostSeat = false;
    setState(() {
      _refreshing = false;
      _loading = false;
      if (result.isFailure || result.data == null) {
        debugPrint('Seat map unavailable: ${result.errorMessage}');
        _seatError =
            result.errorMessage ?? AppLocalizations.of(context).seatLoadFailed;
        return;
      }
      _seatError = null;
      final map = result.data!;
      final validSeats = <String>{
        for (final cabin in map.cabins)
          for (final row in cabin.rows)
            for (final letter in map.seatLetters) '$row$letter',
      };
      for (final traveler in _seated) {
        final seat = traveler.seat;
        if (seat == null) continue;
        if (!validSeats.contains(seat) ||
            (map.occupiedSeats.contains(seat) && !_heldSeats.contains(seat))) {
          traveler.seat = null;
          lostSeat = true;
        }
      }
      _seatMap = map;
      _selectedExtras.removeWhere((key) => !map.extras.containsKey(key));
      if (!map.fares.any((fare) => fare.id == _selectedFareId)) {
        final seatClass = (_params?.seatClass ?? 'economy').toLowerCase();
        final match = map.fares.where((fare) =>
            fare.id.toLowerCase() == seatClass ||
            fare.label.toLowerCase() == seatClass);
        _selectedFareId =
            match.isNotEmpty ? match.first.id : map.fares.firstOrNull?.id;
      }
      if (!map.cabins.any((cabin) => cabin.id == _selectedCabinId)) {
        _selectedCabinId = map.cabins.firstOrNull?.id;
      }
    });
    if (lostSeat && mounted) {
      AppSnackbar.info(
          context, AppLocalizations.of(context).seatNoLongerAvailable);
    }
  }

  /// Duffel returns one quoted fare and no seat map: keep the existing
  /// simulated deck so travelers can still pick seat numbers for the demo.
  void _applyDuffelMap(FlightModel flight) {
    final seatClass = (_params?.seatClass ?? 'economy').toLowerCase();
    final total = flight.comparisonTotal(
          passengers: _searchPassengers,
          seatClass: seatClass,
        ) ??
        0;
    if (!total.isFinite || total <= 0) {
      setState(() {
        _loading = false;
        _flowError = AppLocalizations.of(context).flightProviderUnavailable;
      });
      return;
    }
    final rows = List<int>.generate(12, (index) => index + 1);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    setState(() {
      _seatMap = FlightSeatMap(
        rowCount: rows.length,
        seatLetters: letters,
        extraLegroomRows: const {},
        occupiedSeats: const {},
        fares: [
          FlightSeatFare(
            id: seatClass,
            label: CheckoutLabels(AppLocalizations.of(context))
                .fareForClass(seatClass),
            price: total,
            availableSeats: rows.length * letters.length,
            sharedInventory: false,
          ),
        ],
        cabins: [
          FlightSeatCabin(
            id: 'simulation',
            name: 'Simulation',
            rows: rows,
            totalSeats: rows.length * letters.length,
            availableSeats: rows.length * letters.length,
          ),
        ],
        extraLegroomFee: 0,
        taxRate: 0,
        bookingFee: 0,
        extras: const {},
      );
      _selectedFareId = seatClass;
      _selectedCabinId = 'simulation';
      _loading = false;
      _seatError = null;
    });
  }

  void _selectFare(FlightSeatFare fare) {
    if (_submitting || _refreshing || fare.availableSeats < _seated.length) {
      return;
    }
    setState(() => _selectedFareId = fare.id);
  }

  void _tapSeat(String seat) {
    final map = _seatMap;
    final seated = _seated;
    if (_submitting ||
        _loading ||
        _refreshing ||
        map == null ||
        seated.isEmpty ||
        (map.occupiedSeats.contains(seat) && !_heldSeats.contains(seat))) {
      return;
    }
    final active = _activeSeatTraveler.clamp(0, seated.length - 1).toInt();
    final owner = seated.indexWhere((t) => t.seat == seat);
    HapticFeedback.selectionClick();
    setState(() {
      _seatsSkipped = false;
      if (owner == active) {
        seated[active].seat = null;
        return;
      }
      if (owner != -1) seated[owner].seat = null;
      seated[active].seat = seat;
      final next = seated.indexWhere((t) => t.seat == null);
      if (next != -1) _activeSeatTraveler = next;
    });
  }

  // ── Travelers ────────────────────────────────────────────────────────────

  void _setCount(FlightTravelerType type, int count) {
    setState(() {
      var current = _count(type);
      while (current < count) {
        // Keep the list ordered: adults, then children, then infants.
        final insertAt = switch (type) {
          FlightTravelerType.adult => _count(FlightTravelerType.adult),
          FlightTravelerType.child =>
            _count(FlightTravelerType.adult) + _count(FlightTravelerType.child),
          FlightTravelerType.infant => _travelers.length,
        };
        _travelers.insert(insertAt, _TravelerEntry(type));
        current++;
      }
      while (current > count) {
        final index = _travelers.lastIndexWhere((t) => t.type == type);
        _travelers.removeAt(index).dispose();
        current--;
      }
      // Every infant travels on an adult's lap.
      while (_count(FlightTravelerType.infant) >
          _count(FlightTravelerType.adult)) {
        final index = _travelers
            .lastIndexWhere((t) => t.type == FlightTravelerType.infant);
        _travelers.removeAt(index).dispose();
      }
      final seatedCount = _seated.length;
      if (_activeSeatTraveler >= seatedCount) {
        _activeSeatTraveler = seatedCount - 1;
      }
    });
  }

  String _typeLabel(CheckoutLabels labels, FlightTravelerType type) =>
      switch (type) {
        FlightTravelerType.adult => labels.adult,
        FlightTravelerType.child => labels.child,
        FlightTravelerType.infant => labels.infant,
      };

  String _travelerTitle(CheckoutLabels labels, _TravelerEntry traveler) =>
      labels.travellerOfType(
          _travelers.indexOf(traveler), _typeLabel(labels, traveler.type));

  static int _ageOn(DateTime dob, DateTime on) {
    var age = on.year - dob.year;
    if (on.month < dob.month || (on.month == dob.month && on.day < dob.day)) {
      age--;
    }
    return age;
  }

  String? _validateName(CheckoutLabels labels, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return labels.fieldRequired;
    if (!RegExp(r"^[\p{L}][\p{L} .'\-]*$", unicode: true).hasMatch(text)) {
      return labels.invalidName;
    }
    return null;
  }

  String? _validateDob(CheckoutLabels labels, _TravelerEntry traveler) {
    final dob = DateTime.tryParse(traveler.dob.text);
    if (dob == null) return labels.fieldRequired;
    final age = _ageOn(dob, _flight!.departureTime);
    final ok = switch (traveler.type) {
      FlightTravelerType.adult => age >= 12,
      FlightTravelerType.child => age >= 2 && age < 12,
      FlightTravelerType.infant => age >= 0 && age < 2,
    };
    return ok ? null : labels.ageMismatch(_typeLabel(labels, traveler.type));
  }

  String? _validatePassport(CheckoutLabels labels, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return labels.fieldRequired;
    return RegExp(r'^[A-Za-z0-9]{5,20}$').hasMatch(text)
        ? null
        : labels.invalidPassport;
  }

  String? _validateExpiry(CheckoutLabels labels, _TravelerEntry traveler) {
    final expiry = DateTime.tryParse(traveler.expiry.text);
    if (expiry == null) return labels.fieldRequired;
    final lastTravelDay = _params?.returnDate ?? _flight!.arrivalTime;
    return expiry.isBefore(DateUtils.dateOnly(lastTravelDay))
        ? labels.passportExpired
        : null;
  }

  String? _validateEmail(CheckoutLabels labels, String? value, bool required) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? labels.fieldRequired : null;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)
        ? null
        : labels.invalidEmail;
  }

  String? _validatePhone(CheckoutLabels labels, String? value, bool required) {
    final text = (value ?? '').replaceAll(RegExp(r'[\s\-()]'), '');
    if (text.isEmpty) return required ? labels.fieldRequired : null;
    return RegExp(r'^\+?\d{7,15}$').hasMatch(text) ? null : labels.invalidPhone;
  }

  // ── Continue → Pay ───────────────────────────────────────────────────────

  void _scrollTo(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.15,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  bool get _seatMapUsable =>
      _seatMap != null && _seatError == null && !_loading;

  /// Partner flights need a seat per traveler (the booking API requires
  /// seats). Duffel's simulated map may be skipped.
  bool get _seatsComplete {
    if (_isDuffel && _seatsSkipped) return true;
    return _seated.every((t) => t.seat != null);
  }

  Future<void> _continue() async {
    if (_submitting) return;
    setState(() => _submitted = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid) {
      setState(() {
        for (final traveler in _travelers) {
          if (traveler.fieldKeys
              .any((k) => k.currentState?.hasError ?? false)) {
            traveler.editing = true;
          }
        }
      });
      final first = _travelers
          .expand((t) => t.fieldKeys)
          .where((k) => k.currentState?.hasError ?? false)
          .firstOrNull;
      FocusScope.of(context).unfocus();
      if (first != null) _scrollTo(first);
      return;
    }
    if (!_seatMapUsable || !_seatsComplete) {
      setState(() {
        _showSeatError = true;
        final missing = _seated.indexWhere((t) => t.seat == null);
        if (missing != -1) _activeSeatTraveler = missing;
      });
      FocusScope.of(context).unfocus();
      _scrollTo(_seatSectionKey);
      return;
    }
    await _openReview();
  }

  Future<void> _openReview() async {
    final map = _seatMap;
    final fare = _fare;
    if (map == null || fare == null || _reviewPushed) return;
    _reviewPushed = true;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (routeContext) => ListenableBuilder(
          // Rebuild prices if the user's currency changes while paying.
          listenable: CurrencyScope.of(routeContext),
          builder: (routeContext, _) {
            final charge = _chargeFor(routeContext);
            return FlightReviewPayScreen(
              flight: _flight!,
              passengers: [for (final t in _travelers) t.toPassenger()],
              seats:
                  _seatsSkipped ? const [] : [for (final t in _seated) t.seat!],
              fareLabel: fare.label,
              currencyCode: charge.currency,
              totalPrice: charge.amount,
              priceLines: _priceLines(routeContext, charge.currency),
              acceptedFareRules: _acceptedFareRules,
              onFareRulesChanged: (accepted) =>
                  setState(() => _acceptedFareRules = accepted),
              onPay: _proceedToPayment,
              onBack: () => Navigator.of(routeContext).pop(),
            );
          },
        ),
      ),
    );
    if (mounted) _reviewPushed = false;
  }

  /// Price lines shown on Pay, in the charged currency.
  List<FlightPriceLine> _priceLines(BuildContext context, String currency) {
    final l10n = AppLocalizations.of(context);
    final labels = CheckoutLabels(l10n);
    double inCharge(double amount, String from) => currency == from
        ? amount
        : (convertPrice(context, amount, from: from) ?? amount);
    final lines = <FlightPriceLine>[
      FlightPriceLine(
        label: '${l10n.flightTicketPrice} × ${_seated.length}',
        amount: inCharge(_fareAmount, _sourceCurrency),
      ),
      if (_seatFeesAmount > 0)
        FlightPriceLine(
          label: labels.seatFees,
          amount: inCharge(_seatFeesAmount, _sourceCurrency),
        ),
      if (_extrasAmount > 0)
        FlightPriceLine(
          label: labels.extrasLabel,
          amount: inCharge(_extrasAmount, _sourceCurrency),
        ),
      if (_taxAmount > 0)
        FlightPriceLine(
          label: l10n.flightTaxesFees,
          amount: inCharge(_taxAmount, _sourceCurrency),
        ),
      if (_bookingFee > 0)
        FlightPriceLine(
          label: l10n.flightServiceFee,
          amount: inCharge(_bookingFee, _sourceCurrency),
        ),
      if (_packageStayTotal > 0)
        FlightPriceLine(
          label: l10n.packageStayTotal,
          amount: inCharge(_packageStayTotal, 'USD'),
        ),
    ];
    return lines;
  }

  Future<void> _proceedToPayment() async {
    final flight = _flight;
    final fare = _fare;
    final map = _seatMap;
    final flightId = _flightId;
    final l10n = AppLocalizations.of(context);
    if (_submitting ||
        flight == null ||
        fare == null ||
        map == null ||
        (!_isDuffel && flightId == null)) {
      return;
    }
    if (!_seatsComplete) {
      AppSnackbar.error(context, CheckoutLabels(l10n).seatsMissing);
      return;
    }
    if (!_isDuffel && fare.availableSeats < _seated.length) {
      AppSnackbar.error(context, l10n.fareNotEnoughSeats);
      return;
    }
    final seats = _seatsSkipped
        ? <String>[]
        : ([for (final t in _seated) t.seat!]..sort());
    final extras = _selectedExtras.toList()..sort();
    final travelers = [for (final t in _travelers) t.toPassenger()];
    final charge = _chargeFor(context);
    if (!charge.amount.isFinite || charge.amount <= 0) {
      AppSnackbar.error(context, l10n.genericError);
      return;
    }
    final returnDate = _params?.returnDate;
    setState(() => _submitting = true);

    if (!_isDuffel) {
      final availability = await ApiService.instance.checkFlightAvailability(
        departureDate: flight.departureTime,
        arrivalDate: flight.arrivalTime,
        returnDate: returnDate,
      );
      if (!mounted) return;
      if (availability.isFailure || availability.data != true) {
        setState(() => _submitting = false);
        AppSnackbar.error(
          context,
          availability.isFailure
              ? availability.errorMessage ?? l10n.flightAvailabilityUnverified
              : l10n.flightConflictsBooking,
        );
        return;
      }
      final reservation = await ApiService.instance.reserveFlightSeats(
        flightId: flightId!,
        seats: seats,
      );
      if (!mounted) return;
      if (reservation.isFailure) {
        setState(() => _submitting = false);
        AppSnackbar.error(
          context,
          reservation.errorMessage ?? l10n.seatsNoLongerAvailable,
        );
        await _loadSeatMap();
        return;
      }
      setState(() {
        _heldSeats
          ..clear()
          ..addAll(seats);
      });
    }

    final description = widget.packageOffer == null
        ? '${flight.flightNumber} · ${travelers.length}'
        : '${widget.packageOffer!.title} · ${flight.flightNumber}';
    final reference = _isDuffel
        ? 'ZT-SIM-DUF-${DateTime.now().microsecondsSinceEpoch}'
        : 'flight-$flightId-${DateTime.now().microsecondsSinceEpoch}';
    int? paymentAttemptId;
    final bool paid;
    if (widget.paymentLauncher == null) {
      final payment = await PaymentCheckoutScreen.start(
        context,
        amountUsd: charge.amount,
        currencyCode: charge.currency,
        description: description,
        referenceId: reference,
      );
      paymentAttemptId = payment?.attemptId;
      paid = payment?.paid == true;
    } else {
      paid = await widget.paymentLauncher!(
        context,
        amount: charge.amount,
        currencyCode: charge.currency,
        description: description,
        referenceId: reference,
      );
    }
    if (!mounted) return;
    if (!paid) {
      if (_isDuffel) {
        setState(() => _submitting = false);
        AppSnackbar.error(context, l10n.paymentNotCompletedNoTrip);
        return;
      }
      final release =
          await ApiService.instance.releaseFlightSeatReservation(flightId!);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _heldSeats.clear();
      });
      AppSnackbar.error(
        context,
        release.isFailure
            ? l10n.paymentHoldNotReleased(release.errorMessage ?? '')
            : l10n.paymentHoldReleased,
      );
      await _loadSeatMap();
      return;
    }

    final draft = FlightBookingDraft(
      flight: flight,
      passengerCount: _seated.length,
      seatClass: fare.id,
      seats: seats,
      returnDate: returnDate,
      totalPrice: charge.amount,
      currencyCode: charge.currency,
      extras: extras,
      paymentAttemptId: paymentAttemptId,
      packageOffer: widget.packageOffer,
      travelers: travelers,
    );

    FlightBookingConfirmation? confirmation;
    if (_isDuffel) {
      final trip = TripModel(
        id: DateTime.now().millisecondsSinceEpoch,
        originCode: flight.originCode,
        originCity: flight.originCity,
        destinationCode: flight.destinationCode,
        destinationCity: flight.destinationCity,
        departureDate: flight.departureTime,
        arrivalDate: flight.arrivalTime,
        returnDate: returnDate,
        flightNumber: flight.flightNumber,
        airline: flight.airline,
        airlineLogoUrl: flight.airlineLogoUrl,
        isDirect: flight.isDirect,
        seatClass: fare.id,
        price: _sourceFlightTotal,
        bookingRef: reference,
        passengerCount: travelers.length,
        source: 'duffel',
        sourceOfferId: flight.duffelOfferId ?? flight.id,
        priceCurrencyCode: flight.priceCurrencyCode,
        bookingDisplayAmount: charge.amount,
        bookingCurrencyCode: charge.currency,
        isSimulated: true,
        selectedSeats: seats,
        extras: extras,
      );
      final saved = widget.tripCreator != null
          ? await widget.tripCreator!(trip)
          : await ApiService.instance.createFlightTrip(
              trip,
              paymentAttemptId: paymentAttemptId,
              passengers: [for (final t in travelers) t.toJson()],
            );
      if (!mounted) return;
      if (saved.isFailure || saved.data == null) {
        setState(() => _submitting = false);
        AppSnackbar.error(context, saved.errorMessage ?? l10n.genericError);
        return;
      }
      confirmation = FlightBookingConfirmation(
        trip: saved.data!,
        reference: saved.data!.bookingRef ?? reference,
        seats: seats,
        totalPrice: charge.amount,
        extras: extras,
      );
    }
    // The seats are booked now; going back must not return to this form.
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BookingConfirmedScreen(
          draft: draft,
          initialConfirmation: confirmation,
        ),
      ),
      (route) => route.isFirst,
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = CheckoutLabels(l10n);
    final flight = _flight;
    if (flight == null || _flowError != null) {
      return _FlowError(
        message: _flowError ?? l10n.flightSearchError,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    final fare = _fare;
    final userTotal = _userTotal(context);
    final totalText = userTotal == null
        ? formatCurrencyAmount(
            _sourceFlightTotal + _packageStayTotal,
            _sourceCurrency,
            locale: l10n.localeName.split('_').first,
          )
        : formatCurrencyAmount(
            userTotal,
            userCurrencyCode(context),
            locale: l10n.localeName.split('_').first,
          );
    return CheckoutScaffold(
      header: FlightBookingFlowHeader(
        title: labels.tripDetails,
        activeStep: 0,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      footer: CheckoutFooter(
        key: const ValueKey('trip-details-footer'),
        total: totalText,
        caption: '${fare?.label ?? ''} · '
            '${labels.travellerPrice(_travelers.length)}',
        buttonLabel: labels.continueLabel,
        onPressed: null,
        onAsyncPressed: _loading ? null : _continue,
        loading: _submitting,
      ),
      child: _loading && _seatMap == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 18),
                children: [
                  CheckoutRouteCaption(flight: flight),
                  const SizedBox(height: 18),
                  _fareSection(labels),
                  const SizedBox(height: 22),
                  _travelersSection(l10n, labels),
                  const SizedBox(height: 22),
                  _seatsSection(l10n, labels),
                ],
              ),
            ),
    );
  }

  Widget _fareSection(CheckoutLabels labels) {
    final map = _seatMap;
    final fares = map?.fares ?? const <FlightSeatFare>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.chooseYourFare,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(labels.fareSubheading,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 15),
        if (fares.isEmpty)
          CheckoutEmptyPanel(message: labels.noFareData)
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final columns = constraints.maxWidth < 350 ? 1 : 3;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final fare in fares)
                    SizedBox(
                      width: width,
                      child: _FareChoiceCard(
                        key: ValueKey('fare-${fare.id}'),
                        fare: fare,
                        price: formatPrice(
                          context,
                          _farePerTraveler(fare),
                          from: _sourceCurrency,
                        ),
                        caption: _isDuffel
                            ? labels.perTraveler
                            : '${labels.perTraveler}\n'
                                '${AppLocalizations.of(context).seatsLeft(fare.availableSeats)}',
                        selected: fare.id == _fare?.id,
                        enabled: !_submitting &&
                            (_isDuffel ||
                                fare.availableSeats >= _seated.length),
                        onTap: () => _selectFare(fare),
                      ),
                    ),
                ],
              );
            },
          ),
        if (map != null && map.extras.isNotEmpty) ...[
          const SizedBox(height: 14),
          FlightExtrasPanel(
            extras: map.extras,
            selectedExtras: _selectedExtras,
            enabled: !_submitting && !_refreshing,
            onChanged: (key, selected) => setState(() {
              if (selected) {
                _selectedExtras.add(key);
              } else {
                _selectedExtras.remove(key);
              }
            }),
          ),
        ],
      ],
    );
  }

  Widget _travelersSection(AppLocalizations l10n, CheckoutLabels labels) {
    final canAddSeated = _seated.length < _maxSeated;
    final adults = _count(FlightTravelerType.adult);
    final children = _count(FlightTravelerType.child);
    final infants = _count(FlightTravelerType.infant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.whosFlying,
            style: const TextStyle(
                fontSize: 22,
                height: 1.15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(labels.passportPrompt,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 14),
        CheckoutPanel(
          padding: const EdgeInsets.fromLTRB(13, 6, 13, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CounterRow(
                label: labels.adults,
                hint: labels.adultsHint,
                value: adults,
                onMinus: adults > 1 && !_submitting
                    ? () => _setCount(FlightTravelerType.adult, adults - 1)
                    : null,
                onPlus: canAddSeated && !_submitting
                    ? () => _setCount(FlightTravelerType.adult, adults + 1)
                    : null,
              ),
              _CounterRow(
                label: labels.children,
                hint: labels.childrenHint,
                value: children,
                onMinus: children > 0 && !_submitting
                    ? () => _setCount(FlightTravelerType.child, children - 1)
                    : null,
                onPlus: canAddSeated && !_submitting
                    ? () => _setCount(FlightTravelerType.child, children + 1)
                    : null,
              ),
              _CounterRow(
                label: labels.infants,
                hint: labels.infantsHint,
                value: infants,
                onMinus: infants > 0 && !_submitting
                    ? () => _setCount(FlightTravelerType.infant, infants - 1)
                    : null,
                onPlus: infants < adults && !_submitting
                    ? () => _setCount(FlightTravelerType.infant, infants + 1)
                    : null,
              ),
              if (!canAddSeated &&
                  _maxSeated < FlightTripDetailsScreen.maxTravelers)
                _Note(labels.notEnoughSeats(_maxSeated)),
              if (infants > 0) _Note(labels.infantsNeedAdults),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _travelers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TravelerCard(
              key: ValueKey(_travelers[i]),
              number: i + 1,
              title: _travelerTitle(labels, _travelers[i]),
              traveler: _travelers[i],
              contact: i == 0,
              enabled: !_submitting,
              labels: labels,
              l10n: l10n,
              validateName: (v) => _validateName(labels, v),
              validateDob: () => _validateDob(labels, _travelers[i]),
              validateNationality: (v) => _validateName(labels, v),
              validatePassport: (v) => _validatePassport(labels, v),
              validateExpiry: () => _validateExpiry(labels, _travelers[i]),
              validateEmail: (v) => _validateEmail(labels, v, i == 0),
              validatePhone: (v) => _validatePhone(labels, v, i == 0),
              onChanged: () => setState(() {}),
              onToggle: () => setState(
                  () => _travelers[i].editing = !_travelers[i].editing),
            ),
          ),
        CheckoutPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 15, color: AppColors.textHint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  labels.passportPrivacy,
                  style: const TextStyle(
                      color: AppColors.textHint, fontSize: 10, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seatsSection(AppLocalizations l10n, CheckoutLabels labels) {
    final map = _seatMap;
    final cabin = _cabin;
    final seated = _seated;
    final active = seated.isEmpty
        ? 0
        : _activeSeatTraveler.clamp(0, seated.length - 1).toInt();
    final seatNumbers = <String, int>{
      for (var i = 0; i < seated.length; i++)
        if (seated[i].seat != null) seated[i].seat!: i + 1,
    };
    final missing = !_seatsComplete;

    final Widget content;
    if (_seatError != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlightSeatErrorPanel(
            message:
                '${labels.seatNotAvailable}\n${labels.seatNotAvailableBody}',
            retrying: _refreshing,
            onRetry: _loadSeatMap,
          ),
        ],
      );
    } else if (map == null || cabin == null) {
      content = const FlightSeatMapSkeleton();
    } else if (_isDuffel && _seatsSkipped) {
      content = CheckoutPanel(
        child: Row(
          children: [
            const Icon(Icons.event_seat_outlined,
                size: 18, color: AppColors.textHint),
            const SizedBox(width: 9),
            Expanded(
              child: Text(labels.seatsSkipped,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            AppButton(
              onPressed: () => setState(() => _seatsSkipped = false),
              child: Text(labels.chooseSeatsAgain),
              variant: AppButtonVariant.text,
            ),
          ],
        ),
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isDuffel) ...[
            Text(
              l10n.flightSimulatedSeatMapNotice,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (seated.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < seated.length; i++)
                  _TravelerSeatChip(
                    label: '${i + 1}. ${_typeLabel(labels, seated[i].type)}',
                    seat: seated[i].seat,
                    selected: i == active,
                    onTap: () => setState(() => _activeSeatTraveler = i),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (seated.isNotEmpty)
            Text(
              labels.chooseSeatFor(_travelerTitle(labels, seated[active])),
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 10),
          if (map.cabins.length > 1) ...[
            FlightCabinSelector(
              cabin: cabin,
              cabins: map.cabins,
              selectedCabinId: cabin.id,
              enabled: !_submitting && !_refreshing,
              onCabinSelected: (selected) =>
                  setState(() => _selectedCabinId = selected.id),
            ),
            const SizedBox(height: 12),
          ],
          if (_refreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: AppColors.border,
            ),
          FlightSeatMapView(
            rows: cabin.rows,
            seatLetters: map.seatLetters,
            extraLegroomRows: map.extraLegroomRows,
            occupiedSeats: map.occupiedSeats.difference(_heldSeats),
            selectedSeats: {
              for (final t in seated)
                if (t.seat != null) t.seat!,
            },
            seatNumbers: seatNumbers,
            showPassengerNumbers: seated.length > 1,
            enabled: !_submitting && !_loading,
            onSeatTap: _tapSeat,
          ),
          const SizedBox(height: 14),
          const FlightSeatLegend(),
          if (_isDuffel)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _seatsSkipped = true;
                          for (final t in seated) {
                            t.seat = null;
                          }
                        }),
                child: Text(labels.skipSeats),
                variant: AppButtonVariant.text,
              ),
            ),
        ],
      );
    }

    return Column(
      key: _seatSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(labels.chooseSeats,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        // Error sits at the top so it is visible right after scrolling here.
        if (_showSeatError && (missing || _seatError != null))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _seatError != null
                  ? labels.seatNotAvailable
                  : labels.seatsMissing,
              key: const ValueKey('seat-error'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        content,
      ],
    );
  }
}

/// Mutable form state for one traveler card.
class _TravelerEntry {
  final FlightTravelerType type;
  final name = TextEditingController();
  final dob = TextEditingController();
  final nationality = TextEditingController();
  final passport = TextEditingController();
  final expiry = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final nameKey = GlobalKey<FormFieldState<String>>();
  final dobKey = GlobalKey<FormFieldState<String>>();
  final nationalityKey = GlobalKey<FormFieldState<String>>();
  final passportKey = GlobalKey<FormFieldState<String>>();
  final expiryKey = GlobalKey<FormFieldState<String>>();
  final emailKey = GlobalKey<FormFieldState<String>>();
  final phoneKey = GlobalKey<FormFieldState<String>>();
  String? seat;
  bool editing = true;

  _TravelerEntry(this.type);

  /// First traveler is the contact: prefilled from the signed-in account,
  /// shown collapsed like the former Passengers screen.
  factory _TravelerEntry.fromAccount(FlightTravelerType type) {
    final entry = _TravelerEntry(type);
    final user = ApiService.instance.currentUser;
    if (user != null) {
      entry.name.text = user.name;
      entry.email.text = user.email;
      entry.phone.text = user.phone;
      entry.editing = user.name.trim().isEmpty;
    }
    return entry;
  }

  List<GlobalKey<FormFieldState<String>>> get fieldKeys => [
        nameKey,
        dobKey,
        nationalityKey,
        passportKey,
        expiryKey,
        emailKey,
        phoneKey,
      ];

  FlightCheckoutPassenger toPassenger() => FlightCheckoutPassenger(
        type: type,
        name: name.text.trim(),
        dateOfBirth: dob.text.trim(),
        nationality: nationality.text.trim(),
        passportNumber: passport.text.trim().toUpperCase(),
        passportExpiry: expiry.text.trim(),
        email: email.text.trim(),
        phone: phone.text.trim(),
        seat: type == FlightTravelerType.infant ? null : seat,
      );

  void dispose() {
    for (final c in [name, dob, nationality, passport, expiry, email, phone]) {
      c.dispose();
    }
  }
}

/// Traveler card in the former Passengers-screen design: numbered header with
/// Edit/Done, a two-column summary when collapsed, and the form when editing.
/// Fields stay mounted (Offstage) while collapsed so validation covers them.
class _TravelerCard extends StatelessWidget {
  final int number;
  final String title;
  final _TravelerEntry traveler;
  final bool contact;
  final bool enabled;
  final CheckoutLabels labels;
  final AppLocalizations l10n;
  final FormFieldValidator<String> validateName;
  final String? Function() validateDob;
  final FormFieldValidator<String> validateNationality;
  final FormFieldValidator<String> validatePassport;
  final String? Function() validateExpiry;
  final FormFieldValidator<String> validateEmail;
  final FormFieldValidator<String> validatePhone;
  final VoidCallback onChanged;
  final VoidCallback onToggle;

  const _TravelerCard({
    super.key,
    required this.number,
    required this.title,
    required this.traveler,
    required this.contact,
    required this.enabled,
    required this.labels,
    required this.l10n,
    required this.validateName,
    required this.validateDob,
    required this.validateNationality,
    required this.validatePassport,
    required this.validateExpiry,
    required this.validateEmail,
    required this.validatePhone,
    required this.onChanged,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final name = traveler.name.text.trim();
    return CheckoutPanel(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: const BoxDecoration(
                    color: AppColors.primarySurface, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$number',
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: AppColors.textHint, fontSize: 10)),
                    Text(
                      name.isEmpty ? labels.nameLabel : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              AppButton(
                onPressed: enabled ? onToggle : null,
                child: Text(traveler.editing ? l10n.done : l10n.edit,
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700)),
                variant: AppButtonVariant.text,
              ),
            ],
          ),
          if (!traveler.editing) ...[
            const Divider(height: 18),
            CheckoutTwoColumnValues(
              firstLabel: labels.dateOfBirth,
              firstValue: traveler.dob.text,
              secondLabel: labels.nationality,
              secondValue: traveler.nationality.text,
            ),
            const SizedBox(height: 12),
            CheckoutTwoColumnValues(
              firstLabel: labels.passportNumber,
              firstValue: checkoutMaskPassport(traveler.passport.text),
              secondLabel: labels.passportExpiry,
              secondValue: traveler.expiry.text,
            ),
            if (traveler.email.text.isNotEmpty ||
                traveler.phone.text.isNotEmpty) ...[
              const Divider(height: 20),
              CheckoutValueLine(
                  label: l10n.emailLabel, value: traveler.email.text),
              CheckoutValueLine(
                  label: l10n.phoneLabel, value: traveler.phone.text),
            ],
          ],
          Offstage(
            offstage: !traveler.editing,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(height: 20),
                _field(
                  key: traveler.nameKey,
                  controller: traveler.name,
                  label: labels.nameLabel,
                  icon: Icons.person_outline_rounded,
                  validator: validateName,
                  capitalization: TextCapitalization.words,
                ),
                _dateField(
                  context,
                  key: traveler.dobKey,
                  controller: traveler.dob,
                  label: labels.dateOfBirth,
                  validator: validateDob,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  // Suggested start date for the picker, by age category.
                  initial: switch (traveler.type) {
                    FlightTravelerType.adult =>
                      DateTime(DateTime.now().year - 30),
                    FlightTravelerType.child =>
                      DateTime(DateTime.now().year - 6),
                    FlightTravelerType.infant =>
                      DateTime.now().subtract(const Duration(days: 180)),
                  },
                ),
                _field(
                  key: traveler.nationalityKey,
                  controller: traveler.nationality,
                  label: labels.nationality,
                  icon: Icons.public_rounded,
                  validator: validateNationality,
                  capitalization: TextCapitalization.words,
                ),
                _field(
                  key: traveler.passportKey,
                  controller: traveler.passport,
                  label: labels.passportNumber,
                  icon: Icons.badge_outlined,
                  validator: validatePassport,
                  capitalization: TextCapitalization.characters,
                  formatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(20),
                  ],
                ),
                _dateField(
                  context,
                  key: traveler.expiryKey,
                  controller: traveler.expiry,
                  label: labels.passportExpiry,
                  validator: validateExpiry,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(DateTime.now().year + 20),
                  initial: DateTime(DateTime.now().year + 5),
                ),
                _field(
                  key: traveler.emailKey,
                  controller: traveler.email,
                  label: l10n.emailLabel,
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                _field(
                  key: traveler.phoneKey,
                  controller: traveler.phone,
                  label: l10n.phoneLabel,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: validatePhone,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required GlobalKey<FormFieldState<String>> key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextFormField(
          key: key,
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          inputFormatters: formatters,
          onChanged: (_) => onChanged(),
          validator: validator,
          decoration:
              checkoutInputDecoration(label, icon).copyWith(errorMaxLines: 2),
        ),
      );

  /// Date fields use a controller so the picked date shows immediately (the
  /// former screen used initialValue, which never refreshed after picking).
  Widget _dateField(
    BuildContext context, {
    required GlobalKey<FormFieldState<String>> key,
    required TextEditingController controller,
    required String label,
    required String? Function() validator,
    required DateTime firstDate,
    required DateTime lastDate,
    required DateTime initial,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: TextFormField(
          key: key,
          controller: controller,
          enabled: enabled,
          readOnly: true,
          validator: (_) => validator(),
          onTap: () async {
            final current = DateTime.tryParse(controller.text) ?? initial;
            final picked = await showDatePicker(
              context: context,
              initialDate: current.isBefore(firstDate)
                  ? firstDate
                  : current.isAfter(lastDate)
                      ? lastDate
                      : current,
              firstDate: firstDate,
              lastDate: lastDate,
            );
            if (picked == null) return;
            controller.text = '${picked.year.toString().padLeft(4, '0')}-'
                '${picked.month.toString().padLeft(2, '0')}-'
                '${picked.day.toString().padLeft(2, '0')}';
            key.currentState?.didChange(controller.text);
            key.currentState?.validate();
            onChanged();
          },
          decoration: checkoutInputDecoration(
            label,
            Icons.calendar_today_outlined,
          ).copyWith(
            suffixIcon: const Icon(Icons.expand_more_rounded),
            errorMaxLines: 2,
          ),
        ),
      );
}

/// Fare card in the former Choose-fare design, with a ✓ on the selection.
class _FareChoiceCard extends StatelessWidget {
  final FlightSeatFare fare;
  final String price;
  final String caption;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _FareChoiceCard({
    super.key,
    required this.fare,
    required this.price,
    required this.caption,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 90),
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySurface : AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1),
            ),
            child: Opacity(
              opacity: enabled || selected ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(fare.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ),
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: selected ? AppColors.primary : AppColors.border,
                        size: 17,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    alignment: AlignmentDirectional.centerStart,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      price,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    caption,
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _CounterRow extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  const _CounterRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback? onTap, String semantics) =>
        Semantics(
          button: true,
          enabled: onTap != null,
          label: semantics,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: onTap == null
                    ? AppColors.surfaceSecondary
                    : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  size: 17,
                  color:
                      onTap == null ? AppColors.textHint : AppColors.primary),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                Text(hint,
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 10)),
              ],
            ),
          ),
          button(Icons.remove_rounded, onMinus, '$label −'),
          SizedBox(
            width: 34,
            child: Text('$value',
                key: ValueKey('count-$label'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
          button(Icons.add_rounded, onPlus, '$label +'),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        child: Text(text,
            style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
      );
}

class _TravelerSeatChip extends StatelessWidget {
  final String label;
  final String? seat;
  final bool selected;
  final VoidCallback onTap;

  const _TravelerSeatChip({
    required this.label,
    required this.seat,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            '$label · ${seat ?? '—'}',
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _FlowError extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _FlowError({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(AppLocalizations.of(context).flightConfirmBookingTitle),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.textHint, size: 34),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
}
