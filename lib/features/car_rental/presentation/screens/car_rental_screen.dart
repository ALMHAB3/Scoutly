import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_shell.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_widgets.dart';
import 'car_search_screen.dart';

/// Car rental home: "Find Your Perfect Drive" with popular cars.
class CarRentalScreen extends StatefulWidget {
  final String? initialCity;
  final CurrentLocationService locationService;

  const CarRentalScreen({
    super.key,
    this.initialCity,
    this.locationService = const CurrentLocationService(),
  });

  @override
  State<CarRentalScreen> createState() => _CarRentalScreenState();
}

class _CarRentalScreenState extends State<CarRentalScreen> {
  late final CarController _ctrl = CarController(
    params: CarSearchParams.initial(city: widget.initialCity?.trim() ?? ''),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.search(_ctrl.searchParams);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final result = await Navigator.push<CarSearchResult>(
      context,
      MaterialPageRoute(
        builder: (_) => CarSearchScreen(
          params: _ctrl.searchParams,
          filters: _ctrl.filters,
          initialCars: _ctrl.results,
          locationService: widget.locationService,
        ),
      ),
    );
    if (result == null || !mounted) return;
    _ctrl.apply(
      params: result.params,
      filters: result.filters,
      cars: result.cars,
    );
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
                          style: const TextStyle(color: carCtaColor),
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
                      location: _ctrl.searchParams.city,
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
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            _ctrl.searchParams.city.isEmpty
                                ? labels.allLocations
                                : _ctrl.searchParams.city,
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
                    const SizedBox(height: 12),
                    CarTypeChips(
                      labels: labels,
                      selected: _ctrl.filters.carType,
                      onSelected: _ctrl.setCarType,
                    ),
                    const SizedBox(height: 16),
                  ]),
                ),
                if (_ctrl.isLoading)
                  const SliverPadding(
                    padding: EdgeInsets.only(top: 40),
                    sliver: SliverToBoxAdapter(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_ctrl.loadFailed)
                  SliverToBoxAdapter(
                    child: _Message(
                      text: labels.loadFailed,
                      action: labels.retry,
                      onAction: () => _ctrl.search(_ctrl.searchParams),
                    ),
                  )
                else if (cars.isEmpty)
                  SliverToBoxAdapter(
                    child: _Message(
                      text: labels.noCars,
                      action: _filtersActive ? labels.clearFilters : null,
                      onAction: () => _ctrl.apply(
                        params: _ctrl.searchParams,
                        filters: const CarFilters(),
                        cars: _ctrl.results,
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
  final String location;
  final bool filtersActive;
  final VoidCallback onTap;

  const _SearchBar({
    required this.labels,
    required this.location,
    required this.filtersActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation = location.trim().isNotEmpty;
    return Semantics(
      button: true,
      label: hasLocation ? location : labels.searchHint,
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
                  hasLocation ? location : labels.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: hasLocation ? carInk(context) : carMuted(context),
                    fontWeight: hasLocation ? FontWeight.w600 : null,
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
                  backgroundColor: carCtaColor,
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
    return Semantics(
      button: true,
      label: '$name, ${formatPrice(context, car.pricePerDay)} ${labels.perDay}',
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
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Row(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    this.color = carCtaColor,
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
  final String text;
  final String? action;
  final VoidCallback onAction;

  const _Message({required this.text, this.action, required this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
        child: Column(
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 44,
              color: carMuted(context),
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: carMuted(context)),
            ),
            if (action != null) ...[
              const SizedBox(height: 10),
              TextButton(onPressed: onAction, child: Text(action!)),
            ],
          ],
        ),
      );
}
