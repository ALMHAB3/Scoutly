import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../core/utils/money_format.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_confirmed_view.dart';
import '../../../../global_widgets/booking_loading_overlay.dart';
import '../../../../global_widgets/currency_amount_text.dart';
import '../../../../global_widgets/payment_checkout_screen.dart';
import '../../../../global_widgets/ui/ui.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/transfer_model.dart';
import '../../../car_rental/presentation/car_labels.dart';
import '../../logic/transfers_controller.dart';
import '../widgets/taxi_ride_status_card.dart';

class TransferSearchRouteArgs {
  final String initialFromLocation;
  final String initialToLocation;

  const TransferSearchRouteArgs({
    required this.initialFromLocation,
    required this.initialToLocation,
  });
}

enum _Point { pickup, destination }

/// Taxi booking: 1 Route (map + pickup/destination) → 2 Car (partner rides
/// for the route) → 3 Payment ("How would you like to pay?" when the gateway
/// offers methods, then the payment page) → Booking confirmed.
class TransfersScreen extends StatefulWidget {
  final String? initialFromLocation;
  final String? initialToLocation;
  final CurrentLocationService locationService;

  /// Tests turn the map tiles off (no network).
  final bool showMapTiles;

  const TransfersScreen({
    super.key,
    this.initialFromLocation,
    this.initialToLocation,
    this.locationService = const CurrentLocationService(),
    @visibleForTesting this.showMapTiles = true,
  });

  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  static const _defaultCenter = LatLng(32.3754, 15.0925); // Misrata

  final _ctrl = TransferController();
  final _map = MapController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  LatLng? _pickupPoint;
  LatLng? _dropoffPoint;

  /// Supported city of each point, used to match partner rides.
  String? _pickupCity;
  String? _dropoffCity;
  bool _pickupIsCurrent = false;
  _Point _mapTarget = _Point.destination;
  DateTime _pickupDateTime = DateTime.now().add(const Duration(days: 3));
  int _passengers = 1;
  bool _showRides = false;
  bool _locating = false;
  bool _mapReady = false;
  String? _bookingId;

  @override
  void initState() {
    super.initState();
    final from = widget.initialFromLocation?.trim() ?? '';
    final to = widget.initialToLocation?.trim() ?? '';
    _fromCtrl.text = from;
    _toCtrl.text = to;
    _matchCity(_Point.pickup, from);
    _matchCity(_Point.destination, to);
    if (from.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _useMyLocation());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // ── Points ────────────────────────────────────────────────────────────

  /// A typed or preset supported city also places its point on the map.
  void _matchCity(_Point which, String text) {
    final airport = AirportOption.byCity(text);
    final c = airport?.coordinates;
    final point = c == null ? null : LatLng(c.$1, c.$2);
    if (which == _Point.pickup) {
      _pickupPoint = point;
      _pickupCity = airport?.city;
    } else {
      _dropoffPoint = point;
      _dropoffCity = airport?.city;
    }
  }

  void _onTyped(_Point which) {
    setState(() {
      if (which == _Point.pickup) _pickupIsCurrent = false;
      _matchCity(
          which, (which == _Point.pickup ? _fromCtrl : _toCtrl).text.trim());
    });
    _fitRoute();
  }

  Future<String?> _addressOf(LatLng point) async {
    try {
      final places = await Geocoding()
          .placemarkFromCoordinates(point.latitude, point.longitude);
      final place = places.isEmpty ? null : places.first;
      final address = [place?.name, place?.street, place?.locality]
          .whereType<String>()
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toSet()
          .join(', ');
      return address.isEmpty ? null : address;
    } catch (_) {
      return null;
    }
  }

  Future<void> _setPoint(_Point which, LatLng point,
      {bool current = false}) async {
    final city = AirportOption.nearestTo(point.latitude, point.longitude)?.city;
    setState(() {
      if (which == _Point.pickup) {
        _pickupPoint = point;
        _pickupCity = city;
        _pickupIsCurrent = current;
      } else {
        _dropoffPoint = point;
        _dropoffCity = city;
      }
      // After the pickup is set, the next map tap sets the destination.
      _mapTarget = _Point.destination;
    });
    _fitRoute();
    final address = await _addressOf(point);
    if (!mounted) return;
    final text = address ??
        city ??
        '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
    setState(() => (which == _Point.pickup ? _fromCtrl : _toCtrl).text = text);
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await widget.locationService.getPosition();
      if (!mounted) return;
      await _setPoint(
        _Point.pickup,
        LatLng(position.latitude, position.longitude),
        current: true,
      );
    } on CurrentLocationException catch (error) {
      if (!mounted) return;
      AppSnackbar.error(
        context,
        switch (error.reason) {
          CurrentLocationError.serviceDisabled =>
            _l10n.taxiLocationServiceDisabled,
          CurrentLocationError.permissionDenied =>
            _l10n.taxiLocationPermissionDenied,
          CurrentLocationError.permissionDeniedForever =>
            _l10n.taxiLocationPermissionDeniedForever,
          CurrentLocationError.unableToDetermine =>
            _l10n.taxiLocationUnavailable,
        },
      );
    } catch (_) {
      if (mounted) AppSnackbar.error(context, _l10n.taxiLocationUnavailable);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _swap() {
    setState(() {
      final text = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = text;
      final point = _pickupPoint;
      _pickupPoint = _dropoffPoint;
      _dropoffPoint = point;
      final city = _pickupCity;
      _pickupCity = _dropoffCity;
      _dropoffCity = city;
      _pickupIsCurrent = false;
    });
    _fitRoute();
  }

  void _fitRoute() {
    if (!_mapReady) return;
    final a = _pickupPoint;
    final b = _dropoffPoint;
    if (a != null && b != null) {
      if (a == b) {
        _map.move(a, 15);
        return;
      }
      _map.fitCamera(CameraFit.coordinates(
        coordinates: [a, b],
        padding: const EdgeInsets.fromLTRB(60, 130, 60, 430),
        maxZoom: 16,
      ));
    } else if ((a ?? b) != null) {
      _map.move((a ?? b)!, 15);
    }
  }

  double? get _distanceKm {
    final a = _pickupPoint;
    final b = _dropoffPoint;
    if (a == null || b == null) return null;
    return const Distance().as(LengthUnit.Meter, a, b) / 1000;
  }

  /// Rough driving time: straight-line distance × 1.3 for the roads, at
  /// ~35 km/h in town and ~80 km/h between cities.
  int _driveMinutes(double km) {
    final roadKm = km * 1.3;
    return (roadKm / (km > 30 ? 80 : 35) * 60).round().clamp(1, 1440);
  }

  String _driveTime(double km) {
    final minutes = _driveMinutes(km);
    final text = minutes < 60
        ? _l10n.transferMinutes(minutes)
        : _l10n.flightDurationShort(minutes ~/ 60, minutes % 60);
    return _l10n.taxiDriveMinutes(text);
  }

  // ── Steps ─────────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _pickupDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_pickupDateTime),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(_pickupDateTime);
    setState(() => _pickupDateTime =
        DateTime(date.year, date.month, date.day, t.hour, t.minute));
  }

  Future<void> _findRides() async {
    final from = _fromCtrl.text.trim();
    final to = _toCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      AppSnackbar.error(context, _l10n.transferLocationRequired);
      return;
    }
    _ctrl
      ..fromLocation = _pickupCity ?? from
      ..toLocation = _dropoffCity ?? to
      ..date = _pickupDateTime
      ..passengers = _passengers;
    await BookingLoadingOverlay.run<void>(
      context,
      title: _l10n.quickActionTransfers,
      subtitle: '$from  →  $to',
      serviceIcon: Icons.local_taxi_rounded,
      action: _ctrl.search,
    );
    if (mounted) setState(() => _showRides = true);
  }

  List<TransferModel> get _rides => _ctrl.results
      .map((ride) => ride.copyWith(
            pickupLocation: _fromCtrl.text.trim(),
            dropoffLocation: _toCtrl.text.trim(),
            pickupTime: _pickupDateTime,
          ))
      .toList();

  Future<void> _book(TransferModel ride) async {
    if (_bookingId != null) return;
    final l10n = _l10n;
    setState(() => _bookingId = ride.id);
    try {
      final reference =
          'ZT-T-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      final availability = await ApiService.instance.checkTransferAvailability(
        pickupTime: ride.pickupTime,
        durationMinutes: ride.durationMinutes,
      );
      if (!mounted) return;
      if (availability.isFailure || availability.data != true) {
        AppSnackbar.error(
          context,
          availability.isFailure
              ? availability.errorMessage ?? l10n.genericError
              : l10n.transferScheduleConflict,
        );
        return;
      }

      // Charged in the profile currency when a rate is available (as cars
      // and hotels), otherwise in USD.
      final converted = convertPrice(context, ride.priceUSD);
      final currency = converted == null ? 'USD' : userCurrencyCode(context);
      final amount = double.parse((converted ?? ride.priceUSD)
          .toStringAsFixed(currencyDecimalDigits(currency)));
      final km = _distanceKm;
      final payment = await PaymentCheckoutScreen.start(
        context,
        amountUsd: amount,
        currencyCode: currency,
        description: '${ride.providerName} - ${ride.vehicleName}',
        referenceId: reference,
        methodHeader: const _TaxiSteps(current: 2),
        methodSummary: _RouteSummary(
          from: ride.pickupLocation,
          to: ride.dropoffLocation,
          distance:
              km == null ? null : l10n.taxiDistanceKm(km.toStringAsFixed(1)),
          duration: km == null ? null : _driveTime(km),
        ),
      );
      if (!mounted) return;
      if (payment?.paid != true) {
        AppSnackbar.error(context, l10n.paymentFailedMessage);
        return;
      }

      final result = await BookingLoadingOverlay.run(
        context,
        title: l10n.transferBookedSuccess,
        subtitle: '${ride.pickupLocation} → ${ride.dropoffLocation}',
        serviceIcon: Icons.local_taxi_rounded,
        action: () => ApiService.instance.createTransferBooking(
          ride,
          passengers: _passengers,
          referenceId: reference,
          paymentAttemptId: payment?.attemptId,
        ),
      );
      if (!mounted) return;
      if (result.isFailure) {
        AppSnackbar.error(
          context,
          result.errorMessage == 'TAXI_SCHEDULE_CONFLICT'
              ? l10n.transferScheduleConflict
              : result.errorMessage ?? l10n.genericError,
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TaxiBookingConfirmedScreen(
            ride: ride,
            reference: reference,
            passengers: _passengers,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _bookingId = null);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = _l10n;
    final a = _pickupPoint;
    final b = _dropoffPoint;
    return PopScope(
      canPop: !_showRides,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showRides = false);
      },
      child: Scaffold(
        backgroundColor: context.uiPageBackground,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: a ?? b ?? _defaultCenter,
                initialZoom: 13,
                onMapReady: () {
                  _mapReady = true;
                  _fitRoute();
                },
                onTap: _showRides
                    ? null
                    : (_, point) => _setPoint(_mapTarget, point),
              ),
              children: [
                if (widget.showMapTiles)
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zentrip.app',
                  ),
                if (a != null && b != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [a, b],
                        strokeWidth: 5,
                        color: AppColors.primary,
                        borderStrokeWidth: 2,
                        borderColor: AppColors.white,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (a != null)
                      Marker(
                        point: a,
                        width: 26,
                        height: 26,
                        child: const _PickupDot(),
                      ),
                    if (b != null)
                      Marker(
                        point: b,
                        width: 46,
                        height: 46,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on_rounded,
                          size: 46,
                          color: AppColors.accentRed,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    AppIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      onPressed: () => _showRides
                          ? setState(() => _showRides = false)
                          : Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _TaxiSteps(current: _showRides ? 1 : 0)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child:
                            _showRides ? _ridesSheet(l10n) : _routeSheet(l10n),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routeSheet(AppLocalizations l10n) {
    final km = _distanceKm;
    final date = MaterialLocalizations.of(context);
    return Column(
      key: const ValueKey('taxi-route'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _MapHint(
                  text: _mapTarget == _Point.pickup
                      ? l10n.taxiSelectPickupOnMap
                      : l10n.taxiTapMapHint,
                ),
              ),
            ),
            const SizedBox(width: 10),
            AppIconButton(
              key: const ValueKey('taxi-my-location'),
              icon: Icons.my_location_rounded,
              tooltip: l10n.taxiUseCurrentLocation,
              onPressed: _locating ? null : _useMyLocation,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppCard(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PointRow(
                key: const ValueKey('taxi-pickup'),
                icon: Icons.my_location_rounded,
                iconColor: AppColors.primary,
                label:
                    _pickupIsCurrent ? l10n.taxiPickupCurrent : l10n.taxiPickup,
                hint: _locating ? l10n.taxiMyLocation : l10n.taxiPickupHint,
                controller: _fromCtrl,
                mapTooltip: l10n.taxiSelectPickupOnMap,
                pickingOnMap: _mapTarget == _Point.pickup,
                onMapTap: () => setState(() => _mapTarget = _Point.pickup),
                onChanged: () => _onTyped(_Point.pickup),
              ),
              Row(
                children: [
                  const SizedBox(width: 18),
                  Container(width: 2, height: 18, color: context.uiBorder),
                  const SizedBox(width: 18),
                  Expanded(child: Divider(color: context.uiBorder, height: 1)),
                  AppIconButton(
                    icon: Icons.swap_vert_rounded,
                    tooltip: l10n.swapLocations,
                    onPressed: _swap,
                    size: 20,
                  ),
                ],
              ),
              _PointRow(
                key: const ValueKey('taxi-destination'),
                icon: Icons.location_on_rounded,
                iconColor: AppColors.accentRed,
                label: l10n.taxiDestination,
                hint: l10n.taxiWhereTo,
                controller: _toCtrl,
                mapTooltip: l10n.taxiSelectDropoffOnMap,
                pickingOnMap: false,
                onMapTap: () => setState(() => _mapTarget = _Point.destination),
                onChanged: () => _onTyped(_Point.destination),
              ),
              const SizedBox(height: 14),
              if (km != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.route_rounded,
                        text: l10n.taxiDistanceKm(km.toStringAsFixed(1)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.timer_outlined,
                        text: _driveTime(km),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: _InfoChip(
                      key: const ValueKey('taxi-when'),
                      icon: Icons.event_rounded,
                      text: '${date.formatShortMonthDay(_pickupDateTime)} · '
                          '${date.formatTimeOfDay(TimeOfDay.fromDateTime(_pickupDateTime))}',
                      onTap: _pickDateTime,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PassengersChip(
                    count: _passengers,
                    tooltip: l10n.transferPassengers,
                    onChanged: (value) => setState(() => _passengers = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListenableBuilder(
                listenable: _ctrl,
                builder: (_, __) => AppButton(
                  key: const ValueKey('taxi-choose-car'),
                  loading: _ctrl.isLoading,
                  onPressed: _findRides,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.taxiChooseCar),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fade(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _ridesSheet(AppLocalizations l10n) {
    final rides = _rides;
    return ConstrainedBox(
      key: const ValueKey('taxi-rides'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.66,
      ),
      child: AppCard(
        radius: 24,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.taxiChooseRideTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.uiInk,
                          ),
                        ),
                        if (rides.isNotEmpty)
                          Text(
                            l10n.taxiRidesCount(rides.length),
                            style: TextStyle(
                                fontSize: 12.5, color: context.uiMuted),
                          ),
                      ],
                    ),
                  ),
                  AppButton(
                    variant: AppButtonVariant.text,
                    onPressed: () => setState(() => _showRides = false),
                    child: Text(l10n.taxiChangeRoute),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                children: rides.isEmpty
                    ? [_EmptyRides(message: l10n.transferNoSuitableRides)]
                    : [
                        for (final (i, ride) in rides.indexed)
                          _RideOffer(
                            ride: ride,
                            passengers: _passengers,
                            booking: _bookingId == ride.id,
                            enabled: _bookingId == null,
                            onBook: () => _book(ride),
                          )
                              .animate(delay: (70 * i).ms)
                              .fade()
                              .slideY(begin: 0.06, end: 0),
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1 Route — 2 Car — 3 Payment" progress pill.
class _TaxiSteps extends StatelessWidget {
  final int current;
  const _TaxiSteps({required this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.taxiStepRoute, l10n.taxiStepCar, l10n.taxiStepPayment];
    return AppCard(
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // When the labels don't fit, only the current step keeps its own.
          const style = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800);
          final textWidth = labels.fold<double>(
            0,
            (sum, label) =>
                sum +
                (TextPainter(
                  text: TextSpan(text: label, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout())
                    .width,
          );
          final allLabels = textWidth + labels.length * (22 + 5) + 2 * 28 <=
              constraints.maxWidth;
          return Row(
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                if (i > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color:
                          i <= current ? AppColors.primary : context.uiBorder,
                    ),
                  ),
                _StepDot(
                    number: i + 1, done: i < current, active: i == current),
                if (allLabels || i == current) ...[
                  const SizedBox(width: 5),
                  Text(
                    labels[i],
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          i == current ? FontWeight.w800 : FontWeight.w500,
                      color: i == current ? context.uiInk : context.uiMuted,
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool done;
  final bool active;
  const _StepDot(
      {required this.number, required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    final filled = done || active;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary : context.uiBorder,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 14, color: AppColors.white)
          : Text(
              '$number',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: filled ? AppColors.white : context.uiMuted,
              ),
            ),
    );
  }
}

class _PickupDot extends StatelessWidget {
  const _PickupDot();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.25),
              blurRadius: 6,
            ),
          ],
        ),
      );
}

class _MapHint extends StatelessWidget {
  final String text;
  const _MapHint({required this.text});

  @override
  Widget build(BuildContext context) => AppCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_outlined,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.uiInk),
              ),
            ),
          ],
        ),
      );
}

class _PointRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String hint;
  final TextEditingController controller;
  final String mapTooltip;
  final bool pickingOnMap;
  final VoidCallback onMapTap;
  final VoidCallback onChanged;

  const _PointRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.hint,
    required this.controller,
    required this.mapTooltip,
    required this.pickingOnMap,
    required this.onMapTap,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11.5, color: context.uiMuted)),
                TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.uiInk,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    isDense: true,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: pickingOnMap ? Icons.pin_drop_rounded : Icons.map_outlined,
            tooltip: mapTooltip,
            onPressed: onMapTap,
            style: AppIconButtonStyle.tinted,
            size: 20,
          ),
        ],
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _InfoChip(
      {super.key, required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: context.uiIsDark
            ? AppColors.darkSurfaceSecondary
            : AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.uiInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PassengersChip extends StatelessWidget {
  final int count;
  final String tooltip;
  final ValueChanged<int> onChanged;

  const _PassengersChip({
    required this.count,
    required this.tooltip,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: context.uiIsDark
              ? AppColors.darkSurfaceSecondary
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: tooltip,
              visualDensity: VisualDensity.compact,
              onPressed: count > 1 ? () => onChanged(count - 1) : null,
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            const Icon(Icons.person_outline_rounded,
                size: 17, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.uiInk,
              ),
            ),
            IconButton(
              tooltip: tooltip,
              visualDensity: VisualDensity.compact,
              onPressed: count < 12 ? () => onChanged(count + 1) : null,
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
          ],
        ),
      );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
}

/// One ride for the route: who drives, the vehicle and the price.
class _RideOffer extends StatelessWidget {
  final TransferModel ride;
  final int passengers;
  final bool booking;
  final bool enabled;
  final VoidCallback onBook;

  const _RideOffer({
    required this.ride,
    required this.passengers,
    required this.booking,
    required this.enabled,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final who = ride.driverName ?? ride.partnerName ?? ride.providerName;
    final soft = context.uiIsDark
        ? AppColors.darkSurfaceSecondary
        : AppColors.surfaceSecondary;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      shadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  _initials(who),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: context.uiInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (ride.driverRating != null) ...[
                          const Icon(Icons.star_rounded,
                              size: 15, color: AppColors.amber),
                          Text(
                            ' ${ride.driverRating!.toStringAsFixed(1)} · ',
                            style:
                                TextStyle(fontSize: 12, color: context.uiMuted),
                          ),
                        ],
                        Flexible(
                          child: Text(
                            ride.driverName != null
                                ? ride.providerName
                                : l10n.transferRidePrivate,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: context.uiMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 96,
                    height: 60,
                    child: AppNetworkImage(
                      url: ride.vehicleImageUrl,
                      fallbackIcon: switch (ride.vehicleType) {
                        'van' || 'minivan' => Icons.airport_shuttle_rounded,
                        'bus' => Icons.directions_bus_rounded,
                        _ => Icons.local_taxi_rounded,
                      },
                      fallbackGradient: AppColors.destinationGradients[0],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (ride.vehicleType.isNotEmpty)
                        Text(
                          ride.vehicleType.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                            color: context.uiMuted,
                          ),
                        ),
                      Text(
                        ride.vehicleName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.uiInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${l10n.transferUpToPassengers(ride.maxPassengers)} · '
                        '${l10n.carBagsCount(ride.maxLuggage)} · '
                        '${l10n.transferMinutes(ride.durationMinutes)}',
                        maxLines: 2,
                        style:
                            TextStyle(fontSize: 11.5, color: context.uiMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (ride.includedServices.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final service in ride.includedServices.take(3))
                  AppPill(icon: Icons.check_circle_outline, text: service),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  '${l10n.transferRidePriceNote}\n'
                  '${l10n.transferPassengersCount(passengers)}',
                  style: TextStyle(fontSize: 11.5, color: context.uiMuted),
                ),
              ),
              CurrencyAmountText(
                amount: ride.priceUSD,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            key: ValueKey('taxi-book-${ride.id}'),
            loading: booking,
            onPressed: enabled ? onBook : null,
            child: Text(l10n.taxiBookFor(formatPrice(context, ride.priceUSD))),
          ),
        ],
      ),
    );
  }
}

class _EmptyRides extends StatelessWidget {
  final String message;
  const _EmptyRides({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        child: Column(
          children: [
            const Icon(Icons.local_taxi_rounded,
                color: AppColors.primary, size: 40),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.uiMuted),
            ),
          ],
        ),
      );
}

/// Route summary at the top of "How would you like to pay?".
class _RouteSummary extends StatelessWidget {
  final String from;
  final String to;
  final String? distance;
  final String? duration;

  const _RouteSummary({
    required this.from,
    required this.to,
    this.distance,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    Widget stop(Color color, String text) => Row(
          children: [
            Icon(Icons.radio_button_checked_rounded, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.uiInk,
                ),
              ),
            ),
          ],
        );
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                stop(AppColors.primary, from),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 7),
                  child:
                      Container(width: 2, height: 14, color: context.uiBorder),
                ),
                stop(AppColors.accentRed, to),
              ],
            ),
          ),
          if (distance != null) ...[
            Container(
              width: 1,
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              color: context.uiBorder,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  distance!,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: context.uiInk,
                  ),
                ),
                if (duration != null)
                  Text(duration!,
                      style: TextStyle(fontSize: 12, color: context.uiMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Booking Confirmed!" for a taxi ride (same screen as car and hotel).
class TaxiBookingConfirmedScreen extends StatelessWidget {
  final TransferModel ride;
  final String reference;
  final int passengers;

  const TaxiBookingConfirmedScreen({
    super.key,
    required this.ride,
    required this.reference,
    required this.passengers,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = CarLabels(l10n);
    final date = MaterialLocalizations.of(context);
    return BookingConfirmedView(
      title: labels.bookingConfirmed,
      subtitle: l10n.taxiConfirmedSubtitle,
      bookingIdLabel: labels.bookingId,
      copyTooltip: labels.copy,
      copiedMessage: labels.copied,
      viewDetailsLabel: labels.viewBookingDetails,
      okLabel: labels.ok,
      reference: reference,
      name: ride.vehicleName,
      photo: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 70,
          child: AppNetworkImage(
            url: ride.vehicleImageUrl,
            fallbackIcon: Icons.local_taxi_rounded,
            fallbackGradient: AppColors.destinationGradients[0],
          ),
        ),
      ),
      lines: [
        (
          Icons.calendar_today_outlined,
          '${date.formatMediumDate(ride.pickupTime)} · '
              '${date.formatTimeOfDay(TimeOfDay.fromDateTime(ride.pickupTime))}',
        ),
        (
          Icons.location_on_outlined,
          '${ride.pickupLocation} → ${ride.dropoffLocation}',
        ),
        (
          Icons.person_outline_rounded,
          l10n.transferPassengersCount(passengers)
        ),
        (Icons.payments_outlined, formatPrice(context, ride.priceUSD)),
      ],
      provider: AppIconLabel(
        icon: Icons.storefront_rounded,
        text: ride.partnerName ?? ride.providerName,
        color: AppColors.primary,
      ),
      extra: TaxiRideStatusCard(ride: ride),
    );
  }
}
