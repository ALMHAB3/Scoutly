import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';

/// What the Search & Filters screen hands back to the Browse screen.
class CarSearchResult {
  final CarSearchParams params;
  final CarFilters filters;

  const CarSearchResult({required this.params, required this.filters});
}

/// "Search Cars": the customer's city (fixed: only cars there are shown),
/// drop-off point, pickup/drop-off date and time, car type, price range and
/// features, with a live count of matching cars.
class CarSearchScreen extends StatefulWidget {
  final String city;
  final CarSearchParams params;
  final CarFilters filters;

  /// Cars of [city] (already limited to the customer's city).
  final List<CarModel> cars;

  const CarSearchScreen({
    super.key,
    required this.city,
    required this.params,
    this.filters = const CarFilters(),
    this.cars = const [],
  });

  @override
  State<CarSearchScreen> createState() => _CarSearchScreenState();
}

class _CarSearchScreenState extends State<CarSearchScreen> {
  late final _dropoffCtrl =
      TextEditingController(text: widget.params.dropoffCity);
  late DateTime _pickup = widget.params.pickupDate;
  late DateTime _return = widget.params.returnDate;
  late String _type = widget.filters.carType;
  late final Set<CarFeature> _features = {...widget.filters.features};
  late double? _minPrice = widget.filters.minPricePerDay;
  late double? _maxPrice = widget.filters.maxPricePerDay;

  List<CarModel> get _cars => widget.cars;

  @override
  void dispose() {
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

  // Price bounds (USD per day) of the cars in the customer's city.
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

  Future<void> _pickPickup() async {
    final picked = await pickCarDateTime(
      context,
      initial: _pickup,
      first: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickup = picked;
      if (!_return.isAfter(picked)) {
        _return = DateTime(picked.year, picked.month, picked.day + 1,
            picked.hour, picked.minute);
      }
    });
  }

  Future<void> _pickReturn(CarLabels labels) async {
    final picked = await pickCarDateTime(
      context,
      initial: _return,
      first: _pickup,
    );
    if (picked == null || !mounted) return;
    if (!picked.isAfter(_pickup)) {
      AppSnackbar.error(context, labels.dropoffAfterPickup);
      return;
    }
    setState(() => _return = picked);
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
    Navigator.pop(
      context,
      CarSearchResult(
        params: CarSearchParams(
          city: widget.city,
          dropoffCity: _dropoffCtrl.text.trim(),
          pickupDate: _pickup,
          returnDate: _return,
        ),
        filters: _filters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = CarLabels(AppLocalizations.of(context));
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.radio_button_checked_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels.pickupLocation,
                            style: TextStyle(
                              fontSize: 11,
                              color: carMuted(context),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            labels.city(widget.city),
                            key: const ValueKey('car-pickup-city'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: carInk(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            labels.yourLocation,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: carBorder(context)),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 20,
                      color: carMuted(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labels.dropoffLocation,
                            style: TextStyle(
                              fontSize: 11,
                              color: carMuted(context),
                            ),
                          ),
                          TextField(
                            controller: _dropoffCtrl,
                            maxLength: 120,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: carInk(context),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: labels.sameAsPickup,
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
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 6, top: 8),
            child: Text(
              labels.pickupCityNote,
              style: TextStyle(fontSize: 11.5, color: carMuted(context)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CarDateTimeCard(
                  label: labels.pickupDate,
                  date: labels.shortDate(_pickup),
                  time: labels.time(_pickup),
                  onTap: _pickPickup,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CarDateTimeCard(
                  label: labels.dropoffDate,
                  date: labels.shortDate(_return),
                  time: labels.time(_return),
                  onTap: () => _pickReturn(labels),
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
            onPressed: count == 0 ? null : _showResults,
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

/// Card with a label, a date and a time; tap to change both.
class CarDateTimeCard extends StatelessWidget {
  final String label;
  final String date;
  final String time;
  final VoidCallback onTap;

  const CarDateTimeCard({
    super.key,
    required this.label,
    required this.date,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$label $date $time',
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
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 17,
                      color: carMuted(context),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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
