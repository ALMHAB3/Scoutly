import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../core/services/location_settings_service.dart';
import '../../../../global_widgets/booking_loading_overlay.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/flight_model.dart';
import '../../../../models/hotel_destination_suggestion.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/hotel_controller.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../car_rental/presentation/widgets/car_widgets.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../hotel_labels.dart';

/// مفتاح تخزين آخر مدينة تم البحث عنها، يُستخدم من شاشة SearchHotelsScreen
/// (لعرض اقتراح "كرر آخر بحث") ومن هذه الشاشة نفسها.
class HotelSearchHistory {
  static const _cityKey = 'last_hotel_city';

  static Future<String?> lastCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  static Future<void> saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }
}

class HotelSearchScreen extends StatefulWidget {
  /// مدينة مبدئية تُملأ تلقائيًا (قادمة من باقة سياحية أو من آخر بحث).
  final String? initialCity;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;
  final int? initialGuests;
  final CurrentLocationService locationService;
  final HotelController? controller;
  const HotelSearchScreen({
    super.key,
    this.initialCity,
    this.initialCheckIn,
    this.initialCheckOut,
    this.initialGuests,
    this.locationService = const CurrentLocationService(),
    this.controller,
  });

  @override
  State<HotelSearchScreen> createState() => _HotelSearchScreenState();
}

class _HotelSearchScreenState extends State<HotelSearchScreen> {
  late final HotelController _ctrl;
  bool _ownsController = false;
  final _cityCtrl = TextEditingController();
  final _destinationFocusNode = FocusNode();
  HotelDestinationSuggestion? _selectedDestination;
  bool _destinationError = false;
  bool _cityInitialized = false;
  bool _isLoadingNearby = false;
  String? _locationMessage;
  CurrentLocationError? _locationError;

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? HotelController();
    _ownsController = widget.controller == null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_cityInitialized) {
      final initialCity = widget.initialCity?.trim();
      if (initialCity != null && initialCity.isNotEmpty) {
        _cityCtrl.text = initialCity;
      }
      final today = _dateOnly(DateTime.now());
      final lastBookableDate = today.add(const Duration(days: 330));
      _checkIn = _dateOnly(widget.initialCheckIn ?? _checkIn);
      _checkOut = _dateOnly(widget.initialCheckOut ?? _checkOut);
      if (_checkIn.isBefore(today)) _checkIn = today;
      if (!_checkIn.isBefore(lastBookableDate)) {
        _checkIn = lastBookableDate.subtract(const Duration(days: 1));
      }
      if (_checkOut.isAfter(lastBookableDate)) {
        _checkOut = lastBookableDate;
      }
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(days: 1));
      }
      _guests = (widget.initialGuests ?? _guests).clamp(_rooms, 20).toInt();
      _cityInitialized = true;
    }
  }

  DateTime _checkIn = DateTime.now().add(const Duration(days: 7));
  DateTime _checkOut = DateTime.now().add(const Duration(days: 10));
  int _rooms = 1;
  int _guests = 2;
  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  int get _nightCount =>
      DateTime.utc(_checkOut.year, _checkOut.month, _checkOut.day)
          .difference(DateTime.utc(_checkIn.year, _checkIn.month, _checkIn.day))
          .inDays
          .clamp(1, 99)
          .toInt();

  void _onDestinationChanged(String value) {
    _selectedDestination = null;
    _destinationError = false;
    _ctrl.updateDestinationQuery(
      value,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (_locationMessage != null || _locationError != null) {
      setState(() {
        _locationMessage = null;
        _locationError = null;
      });
    } else {
      setState(() {});
    }
  }

  void _selectDestination(HotelDestinationSuggestion suggestion) {
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _selectedDestination = suggestion;
      _cityCtrl.text = suggestion.displayName(language);
      _destinationError = false;
      _locationMessage = null;
      _locationError = null;
    });
    _ctrl.clearDestinationSuggestions();
    _destinationFocusNode.unfocus();
  }

  Future<void> _loadDestinationSuggestions() async {
    if (_selectedDestination != null || _cityCtrl.text.trim().length < 2) {
      return;
    }
    await _ctrl.loadDestinationSuggestionsNow(
      _cityCtrl.text,
      languageCode: Localizations.localeOf(context).languageCode,
    );
  }

  Future<void> _search() async {
    if (_selectedDestination == null) {
      await _loadDestinationSuggestions();
      if (!mounted) return;
      setState(() => _destinationError = true);
      return;
    }
    final selected = _selectedDestination;
    if (selected == null) return;
    final language = Localizations.localeOf(context).languageCode;
    final visibleCity = selected.displayName(language);
    final city = selected.name;
    if (_checkOut.isBefore(_checkIn.add(const Duration(days: 1)))) {
      setState(() => _checkOut = _checkIn.add(const Duration(days: 1)));
    }
    final params = HotelSearchParams(
      city: city,
      destinationCode: selected.destinationCode,
      countryCode: selected.countryCode,
      placeId: selected.placeId,
      latitude: selected.latitude,
      longitude: selected.longitude,
      checkIn: _checkIn,
      checkOut: _checkOut,
      rooms: _rooms,
      guests: _guests,
    );
    setState(() {
      _destinationError = false;
      _locationMessage = null;
      _locationError = null;
    });
    await BookingLoadingOverlay.run<void>(
      context,
      title: AppLocalizations.of(context).hotelSearching,
      subtitle: visibleCity,
      serviceIcon: Icons.hotel_rounded,
      action: () => _ctrl.search(params),
    );
    unawaited(HotelSearchHistory.saveCity(visibleCity));
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.hotelResults, arguments: _ctrl);
  }

  Future<void> _searchNearby() async {
    setState(() {
      _isLoadingNearby = true;
      _locationMessage = null;
      _locationError = null;
      _destinationError = false;
    });
    try {
      late final CurrentPlace place;
      try {
        place = await widget.locationService.getCurrentPlace();
      } on CurrentLocationException catch (error) {
        if (mounted) {
          setState(() {
            _locationMessage = _locationErrorMessage(
              error.reason,
              AppLocalizations.of(context),
            );
            _locationError = error.reason;
          });
        }
        return;
      }
      final position = place.position;
      final nearestAirport = AirportOption.nearestTo(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      final city = AirportOption.byCity(place.city ?? '')?.city ??
          nearestAirport?.city ??
          place.city ??
          AppLocalizations.of(context).hotelNearbyTitle;
      final detected = HotelDestinationSuggestion(
        name: city,
        localizedName: place.city,
        countryName: place.country,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _selectDestination(detected);
      final params = HotelSearchParams(
        city: city,
        checkIn: _checkIn,
        checkOut: _checkOut,
        rooms: _rooms,
        guests: _guests,
      );
      await BookingLoadingOverlay.run<void>(
        context,
        title: AppLocalizations.of(context).hotelSearching,
        subtitle: city,
        serviceIcon: Icons.hotel_rounded,
        action: () async {
          await _ctrl.searchNearby(
            params,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        },
      );
      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.hotelResults, arguments: _ctrl);
    } finally {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  String _locationErrorMessage(
    CurrentLocationError error,
    AppLocalizations l10n,
  ) =>
      switch (error) {
        CurrentLocationError.serviceDisabled =>
          l10n.nearbyLocationServiceDisabled,
        CurrentLocationError.permissionDenied =>
          l10n.nearbyLocationPermissionDenied,
        CurrentLocationError.permissionDeniedForever =>
          l10n.nearbyLocationPermissionDeniedForever,
        CurrentLocationError.unableToDetermine =>
          l10n.nearbyLocationUnableToDetermine,
      };

  Future<void> _openLocationSettings() async {
    if (!LocationSettingsService.isSupported) return;
    final reason = _locationError;
    if (reason == CurrentLocationError.serviceDisabled) {
      await LocationSettingsService.openLocationSettings();
    } else {
      await LocationSettingsService.openAppSettings();
    }
  }

  Future<void> _pickDateRange() async {
    final today = _dateOnly(DateTime.now());
    final lastDate = today.add(const Duration(days: 330));
    final latestStart = lastDate.subtract(const Duration(days: 1));
    final initialStart = _checkIn.isBefore(today)
        ? today
        : _checkIn.isAfter(latestStart)
            ? latestStart
            : _checkIn;
    final requestedEnd = _checkOut.isAfter(initialStart)
        ? _checkOut
        : initialStart.add(const Duration(days: 1));
    final initialEnd = requestedEnd.isAfter(lastDate) ? lastDate : requestedEnd;
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: lastDate,
      initialDateRange: DateTimeRange(
        start: initialStart,
        end: initialEnd,
      ),
    );
    if (range == null || !mounted) return;
    setState(() {
      _checkIn = _dateOnly(range.start);
      _checkOut = _dateOnly(range.end);
      if (!_checkOut.isAfter(_checkIn)) {
        _checkOut = _checkIn.add(const Duration(days: 1));
      }
    });
  }

  TextSpan _highlightSuggestion(String value) {
    final query = _cityCtrl.text.trim();
    final start = value.toLowerCase().indexOf(query.toLowerCase());
    if (query.isEmpty || start < 0) return TextSpan(text: value);
    final end = start + query.length;
    return TextSpan(children: [
      TextSpan(text: value.substring(0, start)),
      TextSpan(
        text: value.substring(start, end),
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
      TextSpan(text: value.substring(end)),
    ]);
  }

  @override
  void dispose() {
    if (_ownsController) _ctrl.dispose();
    _cityCtrl.dispose();
    _destinationFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = HotelLabels(l10n);

    return Scaffold(
      backgroundColor: carPageBackground(context),
      bottomNavigationBar: AppDockBar(
        selectedIndex: 0,
        onSelected: (index) => AppDockBar.leaveTo(context, index),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.maybePop(context),
                  icon: Icon(Icons.arrow_back_rounded, color: carInk(context)),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l10n.notificationsTitle,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  icon: Icon(Icons.notifications_none_rounded,
                      color: carInk(context)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${labels.findYour}\n'),
                TextSpan(
                  text: labels.perfectStay,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ]),
              style: TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: carInk(context),
              ),
            ).animate().fade(duration: 250.ms),
            const SizedBox(height: 18),

            // ── Destination ────────────────────────────────────────────
            CarCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labels.destination,
                          style:
                              TextStyle(fontSize: 11, color: carMuted(context)),
                        ),
                        TextField(
                          controller: _cityCtrl,
                          focusNode: _destinationFocusNode,
                          textInputAction: TextInputAction.search,
                          onChanged: _onDestinationChanged,
                          onSubmitted: (_) => _loadDestinationSuggestions(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: carInk(context),
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: l10n.hotelDestinationHint,
                            filled: false,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isLoadingNearby
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: l10n.useCurrentLocation,
                          onPressed: _searchNearby,
                          icon: const Icon(Icons.my_location_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                ],
              ),
            ).animate().fade(duration: 300.ms),
            ListenableBuilder(
              listenable: _ctrl,
              builder: (context, _) {
                final query = _cityCtrl.text.trim();
                if (query.length < 2 || _selectedDestination != null) {
                  return const SizedBox.shrink();
                }
                Widget content;
                if (_ctrl.isLoadingDestinationSuggestions) {
                  content = ListTile(
                    dense: true,
                    leading: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: Text(l10n.hotelLoadingDestinations),
                  );
                } else if (_ctrl.hasDestinationSuggestionError) {
                  content = ListTile(
                    dense: true,
                    leading: const Icon(Icons.error_outline_rounded),
                    title: Text(l10n.hotelDestinationSuggestionsError),
                  );
                } else if (_ctrl.destinationSuggestions.isEmpty) {
                  content = ListTile(
                    dense: true,
                    leading: const Icon(Icons.search_off_rounded),
                    title: Text(l10n.hotelNoDestinationSuggestions),
                  );
                } else {
                  content = ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: _ctrl.destinationSuggestions.map((suggestion) {
                        final language =
                            Localizations.localeOf(context).languageCode;
                        final displayName = suggestion.displayName(language);
                        final country = suggestion.displayCountry(language);
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text.rich(_highlightSuggestion(displayName)),
                          subtitle: country.isEmpty ? null : Text(country),
                          onTap: () => _selectDestination(suggestion),
                        );
                      }).toList(growable: false),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Material(
                    elevation: 5,
                    color: carSurface(context),
                    borderRadius: BorderRadius.circular(14),
                    child: content,
                  ),
                );
              },
            ),
            if (_destinationError)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                child: Text(
                  l10n.hotelSelectDestination,
                  style:
                      const TextStyle(color: AppColors.accentRed, fontSize: 12),
                ),
              ),
            if (_locationMessage != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, top: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _locationMessage!,
                        style: const TextStyle(
                            color: AppColors.accentRed, fontSize: 12),
                      ),
                    ),
                    if (_locationError != null)
                      TextButton.icon(
                        onPressed: _openLocationSettings,
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: Text(l10n.openLocationSettings),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // ── Dates ───────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: _DateCard(
                  label: labels.checkIn,
                  date: labels.weekdayDate(_checkIn),
                  icon: Icons.login_rounded,
                  onTap: _pickDateRange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateCard(
                  label: labels.checkOut,
                  date: labels.weekdayDate(_checkOut),
                  icon: Icons.logout_rounded,
                  onTap: _pickDateRange,
                ),
              ),
            ]).animate().fade(delay: 80.ms),
            const SizedBox(height: 12),

            // ── Rooms + guests ──────────────────────────────────────────
            CarCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _Counter(
                    icon: Icons.bed_rounded,
                    label: labels.rooms,
                    value: _rooms,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() {
                      _rooms = v;
                      if (_guests < v) _guests = v;
                    }),
                  ),
                  Divider(height: 1, color: carBorder(context)),
                  _Counter(
                    icon: Icons.people_outline_rounded,
                    label: labels.guests,
                    value: _guests,
                    min: _rooms,
                    max: 20,
                    onChanged: (v) => setState(() => _guests = v),
                  ),
                ],
              ),
            ).animate().fade(delay: 140.ms),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.nights_stay_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    labels.stay(_nightCount, _rooms, _guests),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Search ──────────────────────────────────────────────────
            ListenableBuilder(
              listenable: _ctrl,
              builder: (_, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CarCtaButton(
                    buttonKey: const ValueKey('hotel-search'),
                    label: _ctrl.isLoading && !_isLoadingNearby
                        ? l10n.hotelSearching
                        : labels.searchHotels,
                    loading: _ctrl.isLoading && !_isLoadingNearby,
                    onPressed:
                        _ctrl.isLoading || _isLoadingNearby ? null : _search,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _ctrl.isLoading || _isLoadingNearby
                          ? null
                          : _searchNearby,
                      icon: _isLoadingNearby
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.near_me_outlined),
                      label: Text(labels.searchNearby),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final String label;
  final String date;
  final IconData icon;
  final VoidCallback onTap;

  const _DateCard({
    required this.label,
    required this.date,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label $date',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: CarCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 11, color: carMuted(context))),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(icon, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: carInk(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value, min, max;
  final ValueChanged<int> onChanged;

  const _Counter({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: carInk(context),
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.remove_rounded,
              tooltip: '$label -',
              onTap: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: carInk(context),
                ),
              ),
            ),
            _RoundButton(
              icon: Icons.add_rounded,
              tooltip: '$label +',
              onTap: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      );
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoundButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
          disabledBackgroundColor: carBorder(context).withValues(alpha: 0.4),
        ),
        icon: Icon(icon,
            size: 18,
            color: onTap == null ? carMuted(context) : AppColors.primary),
      );
}
