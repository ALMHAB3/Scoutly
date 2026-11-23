import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/car_model.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';

/// Orange call-to-action colour of the car rental screens.
const carCtaColor = Color(0xFFFF7A1A);

bool carIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color carSurface(BuildContext context) =>
    carIsDark(context) ? AppColors.darkSurface : AppColors.surface;

Color carBorder(BuildContext context) =>
    carIsDark(context) ? AppColors.darkBorder : AppColors.border;

Color carMuted(BuildContext context) =>
    carIsDark(context) ? AppColors.darkTextSecondary : AppColors.textSecondary;

Color carInk(BuildContext context) =>
    carIsDark(context) ? AppColors.darkTextPrimary : AppColors.textPrimary;

Color carPageBackground(BuildContext context) =>
    carIsDark(context) ? AppColors.darkBackground : const Color(0xFFF6F8FC);

/// The car photo on a light studio background (or a car icon when the
/// partner did not upload a photo).
class CarPhoto extends StatelessWidget {
  final CarModel car;
  final double? height;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const CarPhoto({
    super.key,
    required this.car,
    this.height,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final dark = carIsDark(context);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const [Color(0xFF1C2A45), Color(0xFF131D30)]
                  : const [Color(0xFFF1F4FA), Color(0xFFE3E9F4)],
            ),
          ),
          child: car.imageUrl == null || car.imageUrl!.trim().isEmpty
              ? Center(
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: (height ?? 160) * 0.45,
                    color: AppColors.primary.withValues(alpha: 0.75),
                  ),
                )
              : AppNetworkImage(
                  url: car.imageUrl,
                  fit: fit,
                  fallbackIcon: Icons.directions_car_filled_rounded,
                  fallbackGradient: dark
                      ? const LinearGradient(
                          colors: [Color(0xFF1C2A45), Color(0xFF131D30)])
                      : const LinearGradient(
                          colors: [Color(0xFFF1F4FA), Color(0xFFE3E9F4)]),
                ),
        ),
      ),
    );
  }
}

/// Full-width orange button (Book Now, Pay, Show results...).
class CarCtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Key? buttonKey;

  const CarCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          key: buttonKey,
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: carCtaColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: carCtaColor.withValues(alpha: 0.45),
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : Text(label),
        ),
      );
}

/// White rounded card used to group content.
class CarCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const CarCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: carSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: carBorder(context)),
          boxShadow: carIsDark(context)
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF0F1E36).withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: child,
      );
}

/// Horizontal car type chips (All, Economy, SUV...).
class CarTypeChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final CarLabels labels;

  const CarTypeChips({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final type in CarLabels.carTypes)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _Chip(
                  label: labels.carType(type),
                  selected: selected == type,
                  onTap: () => onSelected(type),
                ),
              ),
          ],
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : carSurface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : carBorder(context),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : carInk(context),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
}

/// Square tile with an icon and a label (car features). When [onTap] is
/// set it works as a toggle.
class CarFeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const CarFeatureTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : carInk(context);
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.10)
            : carSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : carBorder(context),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: tile,
      ),
    );
  }
}

IconData carFeatureIcon(CarFeature feature) => switch (feature) {
      CarFeature.automatic => Icons.settings_suggest_outlined,
      CarFeature.ac => Icons.ac_unit_rounded,
      CarFeature.gps => Icons.location_on_outlined,
      CarFeature.bluetooth => Icons.bluetooth_rounded,
    };

/// Rating pill (white with a star), hidden when the car has no rating.
class CarRatingBadge extends StatelessWidget {
  final double rating;
  const CarRatingBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: carSurface(context),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: carInk(context),
            ),
          ),
          const SizedBox(width: 3),
          const Icon(Icons.star_rounded, color: carCtaColor, size: 16),
        ],
      ),
    );
  }
}

/// Small grey caption line: "Automatic · SUV · 4 Seats · Petrol".
String carSpecLine(CarLabels labels, CarModel car, {bool full = true}) => [
      labels.transmission(car.transmission),
      if (full) labels.carType(car.category),
      labels.l10n.carSeatsCount(car.seats),
      if (full) carFuelLabel(labels.l10n, car.fuelType),
    ].join('  ·  ');
