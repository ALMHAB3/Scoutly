import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/hotel_model.dart';
import '../hotel_labels.dart';
import '../../../../global_widgets/ui/ui.dart';

/// Hotel photo (or a hotel icon when there is none).
class HotelPhoto extends StatelessWidget {
  final HotelModel hotel;
  final String? url;
  final double? height;
  final BorderRadius borderRadius;

  const HotelPhoto({
    super.key,
    required this.hotel,
    this.url,
    this.height,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: AppNetworkImage(
            url: url ?? hotel.imageUrl,
            fallbackIcon: Icons.hotel_rounded,
            fallbackGradient: context.uiIsDark
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
      );
}

/// Nightly price in the user's currency (converted from the hotel's), or
/// "Unavailable" when the provider gave no price.
String hotelNightlyText(
    BuildContext context, HotelModel hotel, HotelLabels labels) {
  final price = hotel.comparisonNightlyPrice;
  return price == null
      ? labels.priceUnavailable
      : formatPrice(context, price, from: hotel.priceCurrencyCode);
}

class HotelNightlyPrice extends StatelessWidget {
  final HotelModel hotel;
  final HotelLabels labels;
  final double fontSize;

  const HotelNightlyPrice({
    super.key,
    required this.hotel,
    required this.labels,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final priced = hotel.comparisonNightlyPrice != null;
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: hotelNightlyText(context, hotel, labels),
          style: TextStyle(
            fontSize: priced ? fontSize : 13,
            fontWeight: FontWeight.w800,
            color: priced ? AppColors.primary : context.uiMuted,
          ),
        ),
        if (priced)
          TextSpan(
            text: ' ${labels.perNight}',
            style: TextStyle(fontSize: 12, color: context.uiMuted),
          ),
      ]),
    );
  }
}

/// "Provided by Al-Masa Hotel" (partner hotels only).
class HotelProviderLine extends StatelessWidget {
  final HotelModel hotel;
  final HotelLabels labels;
  final double fontSize;

  const HotelProviderLine({
    super.key,
    required this.hotel,
    required this.labels,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final partner = hotel.partnerName?.trim() ?? '';
    if (partner.isEmpty) return const SizedBox.shrink();
    return AppIconLabel(
      icon: Icons.storefront_rounded,
      text: labels.providedBy(partner),
      fontSize: fontSize,
    );
  }
}

/// Stars row (hotel class).
class HotelStars extends StatelessWidget {
  final int stars;
  final double size;
  const HotelStars({super.key, required this.stars, this.size = 13});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          stars.clamp(0, 5),
          (_) => Icon(Icons.star_rounded,
              size: size, color: AppColors.accentYellow),
        ),
      );
}

/// Icon for an amenity name entered by the partner or the provider.
IconData hotelAmenityIcon(String amenity) {
  final a = amenity.toLowerCase();
  bool has(List<String> words) => words.any(a.contains);
  if (has(['wi-fi', 'wifi', 'internet', 'إنترنت', 'واي'])) {
    return Icons.wifi_rounded;
  }
  if (has(['pool', 'مسبح'])) return Icons.pool_rounded;
  if (has(['parking', 'موقف', 'parking'])) return Icons.local_parking_rounded;
  if (has(['breakfast', 'إفطار', 'فطور'])) return Icons.free_breakfast_rounded;
  if (has(['restaurant', 'مطعم'])) return Icons.restaurant_rounded;
  if (has(['gym', 'fitness', 'رياضي', 'جيم'])) {
    return Icons.fitness_center_rounded;
  }
  if (has(['spa', 'سبا'])) return Icons.spa_rounded;
  if (has(['air', 'تكييف', 'a/c'])) return Icons.ac_unit_rounded;
  if (has(['shuttle', 'airport', 'نقل', 'مطار'])) {
    return Icons.airport_shuttle_rounded;
  }
  if (has(['room service', 'خدمة الغرف'])) return Icons.room_service_rounded;
  if (has(['laundry', 'غسيل'])) return Icons.local_laundry_service_rounded;
  if (has(['beach', 'شاطئ'])) return Icons.beach_access_rounded;
  if (has(['tv', 'تلفاز', 'تلفزيون'])) return Icons.tv_rounded;
  return Icons.check_circle_outline_rounded;
}
