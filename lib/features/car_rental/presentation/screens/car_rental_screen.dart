import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../../../models/flight_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';
import 'car_search_screen.dart';

/// Car rental home: "Find Your Perfect Drive" with the cars of the city the
/// customer is in (never other cities), nearest first.
class CarRentalScreen extends StatefulWidget {
  final CurrentLocationService locationService;

  const CarRentalScreen({
    super.key,
    this.locationService = const CurrentLocationService(),
  });

  @override
  State<CarRentalScreen> createState() => _CarRentalScreenState();
}

class _CarRentalScreenState extends State<CarRentalScreen> {
  final _ctrl = CarController();
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Finds the customer's city (from the supported locations, like partner
  /// listings) and loads the cars there.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final place = await widget.locationService.getCurrentPlace();
      final position = place.position;
      final city = AirportOption.byCity(place.city ?? '')?.city ??
          AirportOption.nearestTo(position.latitude, position.longitude)?.city;
      if (!mounted) return;
      if (city == null) {
        setState(() => _locationError =
            AppLocalizations.of(context).currentCityUnavailable);
        return;
      }
      setState(() => _locating = false);
      await _ctrl.loadFor(CustomerLocation(
        city: city,
        latitude: position.latitude,
        longitude: position.longitude,
      ));
    } on CurrentLocationException catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() => _locationError = switch (error.reason) {
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
      if (mounted && _locating) setState(() => _locating = false);
    }
  }

  Future<void> _openSearch() async {
    final customer = _ctrl.customer;
    if (customer == null) {
      _locate();
      return;
    }
    final result = await Navigator.push<CarSearchResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CarSearchScreen(
          city: customer.city,
          params: _ctrl.searchParams,
          filters: _ctrl.filters,
          cars: _ctrl.results,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _ctrl.apply(params: result.params, filters: result.filters);
  }

  void _openCar(CarModel car) {
    _ctrl.selectCar(car);
    Navigator.pushNamed(context, AppRoutes.carDetail, arguments: _ctrl);
  }

  @override
  Widget build(BuildContext context) {
    final labels = CarLabels(AppLocalizations.of(context));
    return Scaffold(
      backgroundColor: carPageBackground(context),
      bottomNavigationBar: AppDockBar(
        selectedIndex: 0,
        onSelected: (index) => AppDockBar.leaveTo(context, index),
      ),
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _ctrl,
          builder: (context, _) {
            final cars = _ctrl.filteredResults;
            final city = _ctrl.customer?.city;
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList.list(children: [
                    _TopBar(
                      onBack: () => Navigator.maybePop(context),
                      onNotifications: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(text: '${labels.findYour}\n'),
                        TextSpan(
                          text: labels.perfectDrive,
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
                    _SearchBar(
                      labels: labels,
                      city: city,
                      filtersActive: _filtersActive,
                      onTap: _openSearch,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            labels.popularCars,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: carInk(context),
                            ),
                          ),
                        ),
                        if (city != null)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 170),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me_rounded,
                                  size: 14,
                                  color: carMuted(context),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    labels.city(city),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: carMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    CarTypeChips(
                      labels: labels,
                      selected: _ctrl.filters.carType,
                      onSelected: _ctrl.setCarType,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
                if (_locating || _ctrl.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 40),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          if (_locating) ...[
                            const SizedBox(height: 12),
                            Text(
                              labels.locating,
                              style: TextStyle(color: carMuted(context)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else if (_locationError != null || _ctrl.customer == null)
                  SliverToBoxAdapter(
                    child: _Message(
                      icon: Icons.location_off_outlined,
                      text: '${labels.needLocation}'
                          '${_locationError == null ? '' : '\n$_locationError'}',
                      action: labels.enableLocation,
                      onAction: _locate,
                    ),
                  )
                else if (_ctrl.loadFailed)
                  SliverToBoxAdapter(
                    child: _Message(
                      text: labels.loadFailed,
                      action: labels.retry,
                      onAction: () => _ctrl.loadFor(_ctrl.customer!),
                    ),
                  )
                else if (cars.isEmpty)
                  SliverToBoxAdapter(
                    child: _Message(
                      text: _ctrl.results.isEmpty
                          ? labels.noCarsInCity(city!)
                          : labels.noCars,
                      action: _ctrl.results.isEmpty || !_filtersActive
                          ? null
                          : labels.clearFilters,
                      onAction: () => _ctrl.apply(
                        params: _ctrl.searchParams,
                        filters: const CarFilters(),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.builder(
                      itemCount: cars.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _BrowseCarCard(
                          car: cars[index],
                          labels: labels,
                          onTap: () => _openCar(cars[index]),
                        )
                            .animate(
                              delay: Duration(milliseconds: 60 * (index % 6)),
                            )
                            .fade()
                            .slideY(begin: 0.04, end: 0),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  bool get _filtersActive {
    final f = _ctrl.filters;
    return f.minPricePerDay != null ||
        f.maxPricePerDay != null ||
        f.features.isNotEmpty;
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNotifications;

  const _TopBar({required this.onBack, required this.onNotifications});

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          tooltip: material.backButtonTooltip,
          onPressed: onBack,
          icon: Icon(Icons.arrow_back_rounded, color: carInk(context)),
        ),
        const Spacer(),
        IconButton(
          tooltip: AppLocalizations.of(context).notificationsTitle,
          onPressed: onNotifications,
          icon: Icon(
            Icons.notifications_none_rounded,
            color: carInk(context),
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final CarLabels labels;
  final String? city;
  final bool filtersActive;
  final VoidCallback onTap;

  const _SearchBar({
    required this.labels,
    required this.city,
    required this.filtersActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = city == null ? labels.searchHint : labels.carsIn(city!);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('car-search-bar'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: CarCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: carMuted(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: city == null ? carMuted(context) : carInk(context),
                    fontWeight: city == null ? null : FontWeight.w600,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 26,
                color: carBorder(context),
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Badge(
                  isLabelVisible: filtersActive,
                  backgroundColor: AppColors.accentOrange,
                  smallSize: 8,
                  child: const Icon(
                    Icons.tune_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrowseCarCard extends StatelessWidget {
  final CarModel car;
  final CarLabels labels;
  final VoidCallback onTap;

  const _BrowseCarCard({
    required this.car,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = '${car.brand} ${car.model}'.trim();
    final partner = car.partnerName?.trim() ?? '';
    return Semantics(
      button: true,
      label: '$name, ${formatPrice(context, car.pricePerDay)} ${labels.perDay}'
          '${partner.isEmpty ? '' : ', ${labels.providedBy(partner)}'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: CarCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CarPhoto(
                    car: car,
                    height: 170,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  PositionedDirectional(
                    top: 12,
                    end: 12,
                    child: CarRatingBadge(rating: car.rating),
                  ),
                  if (car.distanceMeters != null)
                    PositionedDirectional(
                      top: 12,
                      start: 12,
                      child: _Pill(
                        icon: Icons.near_me_rounded,
                        text: labels.kmAway(car.distanceMeters!),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: carInk(context),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                carSpecLine(labels, car, full: false),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: carMuted(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CarDailyPrice(car: car, labels: labels, fontSize: 16),
                      ],
                    ),
                    if (partner.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: carBorder(context)),
                      const SizedBox(height: 10),
                      CarProviderLine(car: car, labels: labels),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: carSurface(context),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: carInk(context),
              ),
            ),
          ],
        ),
      );
}

/// "LYD 544.000 / day" (price in the user's currency).
class CarDailyPrice extends StatelessWidget {
  final CarModel car;
  final CarLabels labels;
  final double fontSize;
  final Color color;

  const CarDailyPrice({
    super.key,
    required this.car,
    required this.labels,
    this.fontSize = 18,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: [
          TextSpan(
            text: formatPrice(context, car.pricePerDay),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          TextSpan(
            text: ' ${labels.perDay}',
            style: TextStyle(fontSize: 12, color: carMuted(context)),
          ),
        ]),
      );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback onAction;

  const _Message({
    this.icon = Icons.directions_car_outlined,
    required this.text,
    this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          children: [
            Icon(icon, size: 44, color: carMuted(context)),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: carMuted(context), height: 1.4),
            ),
            if (action != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: 220,
                child: CarCtaButton(label: action!, onPressed: onAction),
              ),
            ],
          ],
        ),
      );
}
