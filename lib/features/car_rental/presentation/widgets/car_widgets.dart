import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/car_model.dart';
import '../../../flight_booking/presentation/screens/flight_primary_button.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';

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
    carIsDark(context) ? AppColors.darkBackground : AppColors.background;

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
                  ? const [
                      AppColors.darkSurfaceSecondary,
                      AppColors.darkSurface
                    ]
                  : const [
                      AppColors.surfaceSecondary,
                      AppColors.primarySurface
                    ],
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
                      ? const LinearGradient(colors: [
                          AppColors.darkSurfaceSecondary,
                          AppColors.darkSurface
                        ])
                      : const LinearGradient(colors: [
                          AppColors.surfaceSecondary,
                          AppColors.primarySurface
                        ]),
                ),
        ),
      ),
    );
  }
}

/// Full-width call-to-action in the app's standard style (navy gradient,
/// same as the rest of the app's primary buttons).
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
  Widget build(BuildContext context) => FlightPrimaryButton(
        key: buttonKey,
        label: label,
        onPressed: onPressed,
        loading: loading,
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
                    color: AppColors.textPrimary.withValues(alpha: 0.05),
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
  final int maxLines;

  const CarFeatureTile({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.onTap,
    this.maxLines = 1,
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
            maxLines: maxLines,
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
          const Icon(Icons.star_rounded,
              color: AppColors.accentYellow, size: 16),
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

/// Date then time picker. Returns null when cancelled.
Future<DateTime?> pickCarDateTime(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
}) async {
  final firstDay = DateTime(first.year, first.month, first.day);
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(firstDay) ? firstDay : initial,
    firstDate: firstDay,
    lastDate: firstDay.add(const Duration(days: 365)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// "Provided by Libya Cars" line with a store icon.
class CarProviderLine extends StatelessWidget {
  final CarModel car;
  final CarLabels labels;
  final double fontSize;

  const CarProviderLine({
    super.key,
    required this.car,
    required this.labels,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final partner = car.partnerName?.trim() ?? '';
    if (partner.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.storefront_rounded,
          size: fontSize + 3,
          color: AppColors.primary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            labels.providedBy(partner),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
