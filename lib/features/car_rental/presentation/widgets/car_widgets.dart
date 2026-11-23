import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/car_model.dart';
import '../../logic/car_controller.dart';
import '../car_labels.dart';
import '../../../../global_widgets/ui/ui.dart';

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
    final dark = context.uiIsDark;
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
                child: AppChip(
                  label: labels.carType(type),
                  selected: selected == type,
                  onTap: () => onSelected(type),
                ),
              ),
          ],
        ),
      );
}

IconData carFeatureIcon(CarFeature feature) => switch (feature) {
      CarFeature.automatic => Icons.settings_suggest_outlined,
      CarFeature.ac => Icons.ac_unit_rounded,
      CarFeature.gps => Icons.location_on_outlined,
      CarFeature.bluetooth => Icons.bluetooth_rounded,
    };

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
    return AppIconLabel(
      icon: Icons.storefront_rounded,
      text: labels.providedBy(partner),
      fontSize: fontSize,
    );
  }
}
