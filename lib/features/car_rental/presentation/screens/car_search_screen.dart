import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../../../models/flight_model.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';

/// What the Search & Filters screen hands back to the Browse screen.
class CarSearchResult {
  final CarSearchParams params;
  final CarFilters filters;
  final List<CarModel> cars;

  const CarSearchResult({
    required this.params,
    required this.filters,
    required this.cars,
  });
}

/// "Search Cars": locations, dates, car type, price range and features, with
/// a live count of matching cars.
class CarSearchScreen extends StatefulWidget {
  final CarSearchParams params;
  final CarFilters filters;
  final List<CarModel> initialCars;
  final CurrentLocationService locationService;

  const CarSearchScreen({
    super.key,
    required this.params,
    this.filters = const CarFilters(),
    this.initialCars = const [],
    this.locationService = const CurrentLocationService(),
  });

  @override
  State<CarSearchScreen> createState() => _CarSearchScreenState();
}

class _CarSearchScreenState extends State<CarSearchScreen> {
  late final _pickupCtrl = TextEditingController(text: widget.params.city);
  late final _dropoffCtrl =
      TextEditingController(text: widget.params.dropoffCity);
  late DateTime _pickupDate = widget.params.pickupDate;
  late DateTime _returnDate = widget.params.returnDate;
  late String _type = widget.filters.carType;
  late final Set<CarFeature> _features = {...widget.filters.features};
  double? _minPrice;
  double? _maxPrice;

  late List<CarModel> _cars = widget.initialCars;
  late String _loadedCity = widget.params.city.trim();
  bool _loadingCars = false;
  bool _locating = false;
  String? _message;
  Timer? _debounce;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _minPrice = widget.filters.minPricePerDay;
    _maxPrice = widget.filters.maxPricePerDay;
    if (_cars.isEmpty) _loadCars(_loadedCity);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pickupCtrl.dispose();
    _dropoffCtrl.dispose();
    super.dispose();
  }

  CarFilters get _filters => CarFilters(
        carType: _type,
        minPricePerDay: _minPrice,
        maxPricePerDay: _maxPrice,
        features: {..._features},
      );

  int get _matchCount => _cars.where(_filters.matches).length;

  // Price bounds (USD per day) of the cars at the chosen location.
  double get _floor => _cars.isEmpty
      ? 0
      : _cars
          .map((c) => c.pricePerDay)
          .reduce((a, b) => a < b ? a : b)
          .floorToDouble();
  double get _ceil => _cars.isEmpty
      ? 0
      : _cars
          .map((c) => c.pricePerDay)
          .reduce((a, b) => a > b ? a : b)
          .ceilToDouble();

  Future<void> _loadCars(String city) async {
    final token = ++_loadToken;
    setState(() {
      _loadingCars = true;
      _message = null;
    });
    try {
      final cars = await CarController.loadCars(city);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _cars = cars;
        _loadedCity = city.trim();
        _minPrice = null;
        _maxPrice = null;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _cars = const [];
        _message = AppLocalizations.of(context).carSearchFailed;
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _loadingCars = false);
      }
    }
  }

  void _onPickupChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.trim() != _loadedCity) _loadCars(value);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _message = null;
    });
    final l10n = AppLocalizations.of(context);
    try {
      final place = await widget.locationService.getCurrentPlace();
      final airport = AirportOption.nearestTo(
        place.position.latitude,
        place.position.longitude,
      );
      final city = AirportOption.byCity(place.city ?? '')?.city ??
          airport?.city ??
          place.city;
      if (!mounted) return;
      if (city == null) {
        setState(() => _message = l10n.currentCityUnavailable);
        return;
      }
      _pickupCtrl.text = city;
      _loadCars(city);
    } on CurrentLocationException catch (error) {
      if (!mounted) return;
      setState(() => _message = switch (error.reason) {
            CurrentLocationError.serviceDisabled =>
              l10n.nearbyLocationServiceDisabled,
            CurrentLocationError.permissionDenied =>
              l10n.nearbyLocationPermissionDenied,
            CurrentLocationError.permissionDeniedForever =>
              l10n.nearbyLocationPermissionDeniedForever,
            CurrentLocationError.unableToDetermine =>
              l10n.nearbyLocationUnableToDetermine,
          });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickDate({required bool pickup}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: pickup ? _pickupDate : _returnDate,
      firstDate: pickup ? today : _pickupDate.add(const Duration(days: 1)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (pickup) {
        _pickupDate = picked;
        if (!_returnDate.isAfter(picked)) {
          _returnDate = picked.add(const Duration(days: 1));
        }
      } else {
        _returnDate = picked;
      }
    });
  }

  void _reset() {
    setState(() {
      _type = 'all';
      _features.clear();
      _minPrice = null;
      _maxPrice = null;
      _dropoffCtrl.clear();
    });
  }

  void _showResults() {
    final pickup = _pickupCtrl.text.trim();
    if (pickup != _loadedCity) {
      _loadCars(pickup);
      return;
    }
    Navigator.pop(
      context,
      CarSearchResult(
        params: CarSearchParams(
          city: pickup,
          dropoffCity: _dropoffCtrl.text.trim(),
          pickupDate: _pickupDate,
          returnDate: _returnDate,
        ),
        filters: _filters,
        cars: _cars,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = CarLabels(l10n);
    final count = _matchCount;
    return Scaffold(
      backgroundColor: carPageBackground(context),
      appBar: AppBar(
        backgroundColor: carPageBackground(context),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          labels.searchCars,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: carInk(context),
          ),
        ),
        actions: [
          TextButton(onPressed: _reset, child: Text(labels.reset)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          CarCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Column(
              children: [
                _LocationField(
                  icon: Icons.radio_button_checked_rounded,
                  iconColor: AppColors.primary,
                  label: labels.pickupLocation,
                  hint: labels.pickupHint,
                  controller: _pickupCtrl,
                  onChanged: _onPickupChanged,
                  onSelected: (value) {
                    _debounce?.cancel();
                    _loadCars(value);
                  },
                  trailing: _locating
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
                          onPressed: _useCurrentLocation,
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 1.5,
                        height: 14,
                        color: carBorder(context),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Divider(height: 1, color: carBorder(context)),
                      ),
                    ],
                  ),
                ),
                _LocationField(
                  icon: Icons.location_on_outlined,
                  iconColor: carMuted(context),
                  label: labels.dropoffLocation,
                  hint: labels.sameAsPickup,
                  controller: _dropoffCtrl,
                ),
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6, top: 8),
              child: Text(
                _message!,
                style:
                    const TextStyle(color: AppColors.accentRed, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateCard(
                  label: labels.pickupDate,
                  value: labels.shortDate(_pickupDate),
                  onTap: () => _pickDate(pickup: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateCard(
                  label: labels.dropoffDate,
                  value: labels.shortDate(_returnDate),
                  onTap: () => _pickDate(pickup: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(labels.carTypeTitle),
          const SizedBox(height: 10),
          CarTypeChips(
            labels: labels,
            selected: _type,
            onSelected: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: 22),
          _SectionTitle(labels.priceRange, trailing: labels.perDayNote),
          const SizedBox(height: 4),
          _priceRange(context),
          const SizedBox(height: 18),
          _SectionTitle(labels.features),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final feature in CarFeature.values) ...[
                if (feature != CarFeature.values.first)
                  const SizedBox(width: 10),
                Expanded(
                  child: CarFeatureTile(
                    icon: carFeatureIcon(feature),
                    label: labels.feature(feature),
                    selected: _features.contains(feature),
                    onTap: () => setState(() => _features.contains(feature)
                        ? _features.remove(feature)
                        : _features.add(feature)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: CarCtaButton(
            buttonKey: const ValueKey('car-show-results'),
            label: labels.showResults(count),
            loading: _loadingCars,
            onPressed: count == 0 && _pickupCtrl.text.trim() == _loadedCity
                ? null
                : _showResults,
          ),
        ),
      ),
    );
  }

  Widget _priceRange(BuildContext context) {
    final floor = _floor;
    final ceil = _ceil;
    if (_cars.isEmpty || ceil <= floor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _cars.isEmpty ? '—' : formatPrice(context, floor),
          style: TextStyle(color: carMuted(context)),
        ),
      );
    }
    final values = RangeValues(
      (_minPrice ?? floor).clamp(floor, ceil),
      (_maxPrice ?? ceil).clamp(floor, ceil),
    );
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: AppColors.primary.withValues(alpha: 0.15),
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withValues(alpha: 0.12),
            rangeThumbShape: const _RingThumb(),
          ),
          child: RangeSlider(
            values: values,
            min: floor,
            max: ceil,
            labels: RangeLabels(
              formatPrice(context, values.start),
              formatPrice(context, values.end),
            ),
            onChanged: (range) => setState(() {
              _minPrice = range.start <= floor ? null : range.start;
              _maxPrice = range.end >= ceil ? null : range.end;
            }),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                formatPrice(context, values.start),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: carInk(context),
                ),
              ),
              const Spacer(),
              Text(
                formatPrice(context, values.end),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: carInk(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;
  const _SectionTitle(this.text, {this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: carInk(context),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(
              '($trailing)',
              style: TextStyle(fontSize: 12, color: carMuted(context)),
            ),
          ],
        ],
      );
}

class _LocationField extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSelected;
  final Widget? trailing;

  const _LocationField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSelected,
    this.trailing,
  });

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(widget.icon, size: 20, color: widget.iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 11, color: carMuted(context)),
                ),
                RawAutocomplete<String>(
                  textEditingController: widget.controller,
                  focusNode: _focusNode,
                  optionsBuilder: (value) =>
                      ApiService.instance.searchCarLocations(value.text),
                  onSelected: (value) => widget.onSelected?.call(value),
                  optionsViewBuilder: (context, select, options) => Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Material(
                      elevation: 5,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxHeight: 240, maxWidth: 320),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            for (final option in options)
                              ListTile(
                                dense: true,
                                leading: const Icon(Icons.place_outlined),
                                title: Text(option),
                                onTap: () => select(option),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  fieldViewBuilder: (context, textController, focusNode, _) =>
                      TextField(
                    controller: textController,
                    focusNode: focusNode,
                    onChanged: widget.onChanged,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: carInk(context),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.hint,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.trailing != null)
            widget.trailing!
          else
            const SizedBox(width: 8),
        ],
      );
}

class _DateCard extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateCard({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label $value',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: CarCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: carMuted(context)),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: carInk(context),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: carMuted(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

/// White thumb with a navy ring (as in the design).
class _RingThumb extends RangeSliderThumbShape {
  const _RingThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(11);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool isDiscrete = false,
    bool isEnabled = false,
    bool? isOnTop,
    required SliderThemeData sliderTheme,
    TextDirection? textDirection,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 11, Paint()..color = Colors.white);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }
}
