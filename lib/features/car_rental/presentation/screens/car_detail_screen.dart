import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../global_widgets/booking_load_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/car_model.dart';
import '../../../favorites/logic/favorites_controller.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../widgets/car_pickup_map.dart';
import '../widgets/car_widgets.dart';
import 'car_booking_screen.dart';
import 'car_rental_screen.dart' show CarDailyPrice;

/// Car details: photo, price per day, features, about and specs, Book Now.
class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key});

  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  CarController? _ctrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ctrl ??= ModalRoute.of(context)?.settings.arguments as CarController?;
  }

  String _favoriteId(CarModel car) => 'car:${car.id}';

  Future<void> _toggleFavorite(CarModel car, CarLabels labels) async {
    final favorites = FavoritesController.instance;
    final wasFavorite = favorites.isFavorite(_favoriteId(car));
    await favorites.toggle(FavoritePlace(
      id: _favoriteId(car),
      title: '${car.brand} ${car.model}'.trim(),
      subtitle: car.pickupLocation,
      type: 'car',
      imageUrl: car.imageUrl,
      latitude: car.latitude,
      longitude: car.longitude,
    ));
    if (!mounted) return;
    AppSnackbar.success(
      context,
      wasFavorite ? labels.removedFromFavorites : labels.savedToFavorites,
    );
  }

  void _book(CarModel car) {
    final ctrl = _ctrl!;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarBookingScreen(car: car, params: ctrl.searchParams),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final car = _ctrl?.selectedCar;
    if (car == null) return const BookingLoadError();
    final labels = CarLabels(AppLocalizations.of(context));
    final name = '${car.brand} ${car.model}'.trim();
    final soldOut = car.availableVehicles < 1;
    final features = [
      for (final feature in CarFeature.values)
        if (carHasFeature(car, feature)) feature,
    ];

    return Scaffold(
      backgroundColor: carPageBackground(context),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                CarPhoto(car: car, height: 300, fit: BoxFit.cover),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          onPressed: () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: FavoritesController.instance,
                          builder: (context, _) {
                            final saved = FavoritesController.instance
                                .isFavorite(_favoriteId(car));
                            return _RoundIconButton(
                              icon: saved
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: saved ? AppColors.accentRed : null,
                              tooltip: saved
                                  ? labels.removedFromFavorites
                                  : labels.savedToFavorites,
                              onPressed: () => _toggleFavorite(car, labels),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                PositionedDirectional(
                  end: 16,
                  bottom: 16,
                  child: CarRatingBadge(rating: car.rating),
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                color: carSurface(context),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -18, 0),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: carInk(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CarDailyPrice(car: car, labels: labels, fontSize: 20),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    carSpecLine(labels, car),
                    style: TextStyle(fontSize: 12.5, color: carMuted(context)),
                  ),
                  if ((car.partnerName ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    CarProviderLine(car: car, labels: labels, fontSize: 13),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: carMuted(context),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          car.distanceMeters == null
                              ? car.pickupPlace
                              : '${car.pickupPlace} · '
                                  '${labels.kmAway(car.distanceMeters!)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: carMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (features.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        for (var i = 0; i < features.length; i++) ...[
                          if (i > 0) const SizedBox(width: 10),
                          Expanded(
                            child: CarFeatureTile(
                              icon: carFeatureIcon(features[i]),
                              label: labels.feature(features[i]),
                            ),
                          ),
                        ],
                        // Keep tiles the same width as in a full row of 4.
                        for (var i = features.length; i < 4; i++) ...[
                          const SizedBox(width: 10),
                          const Expanded(child: SizedBox()),
                        ],
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  Text(
                    labels.aboutCar,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: carInk(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    car.description.isNotEmpty
                        ? car.description
                        : labels.about(name, car.pickupLocation),
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: carMuted(context),
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Engine and fuel economy when the partner entered them
                  // (as in the design), otherwise year and bags.
                  _SpecGrid(specs: [
                    if (car.engine.isNotEmpty)
                      (car.engine, labels.engine)
                    else
                      (car.year > 0 ? '${car.year}' : '—', labels.year),
                    (
                      labels.transmission(car.transmission),
                      labels.transmissionTitle
                    ),
                    ('${car.seats}', labels.seats),
                    if (car.fuelEconomy.isNotEmpty)
                      (car.fuelEconomy, labels.fuelEconomy)
                    else
                      ('${car.bags}', labels.bags),
                  ]),
                  if (car.engine.isNotEmpty ||
                      car.fuelEconomy.isNotEmpty ||
                      car.doors != null ||
                      car.color.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _SpecGrid(specs: [
                      if (car.engine.isNotEmpty && car.year > 0)
                        ('${car.year}', labels.year),
                      if (car.fuelEconomy.isNotEmpty)
                        ('${car.bags}', labels.bags),
                      if (car.doors != null) ('${car.doors}', labels.doors),
                      if (car.color.isNotEmpty) (car.color, labels.color),
                    ]),
                  ],
                  if (car.latitude != null && car.longitude != null) ...[
                    const SizedBox(height: 22),
                    Text(
                      labels.pickupPoint,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: carInk(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CarPickupMap(car: car),
                  ],
                ],
              ).animate().fade(duration: 250.ms),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: carSurface(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: CarCtaButton(
              buttonKey: const ValueKey('car-book-now'),
              label: soldOut ? labels.soldOut : labels.bookNow,
              onPressed: soldOut ? null : () => _book(car),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpecGrid extends StatelessWidget {
  final List<(String, String)> specs;
  const _SpecGrid({required this.specs});

  @override
  Widget build(BuildContext context) {
    if (specs.isEmpty) return const SizedBox.shrink();
    return CarCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < specs.length; i++) ...[
              if (i > 0) VerticalDivider(width: 1, color: carBorder(context)),
              _Spec(value: specs[i].$1, label: specs[i].$2),
            ],
          ],
        ),
      ),
    );
  }
}

class _Spec extends StatelessWidget {
  final String value;
  final String label;
  const _Spec({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: carInk(context),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: carMuted(context)),
              ),
            ],
          ),
        ),
      );
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: carSurface(context).withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, color: color ?? carInk(context)),
          ),
        ),
      );
}
