import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_format.dart';
import '../../../../global_widgets/app_network_image.dart';
import '../../../../models/hotel_model.dart';
import '../../../car_rental/presentation/widgets/car_widgets.dart';
import '../hotel_labels.dart';

// The hotel screens share the car rental screens' design (cards, buttons,
// colours) from car_widgets.dart: CarCard, CarCtaButton, carInk...

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
            fallbackGradient: carIsDark(context)
                ? const LinearGradient(
                    colors: [Color(0xFF1C2A45), Color(0xFF131D30)])
                : const LinearGradient(
                    colors: [Color(0xFFF1F4FA), Color(0xFFE3E9F4)]),
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
            color: priced ? AppColors.primary : carMuted(context),
          ),
        ),
        if (priced)
          TextSpan(
            text: ' ${labels.perNight}',
            style: TextStyle(fontSize: 12, color: carMuted(context)),
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
    return Row(
      children: [
        Icon(Icons.storefront_rounded,
            size: fontSize + 3, color: AppColors.primary),
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

/// Small map with the hotel's location and its address.
class HotelLocationMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;

  const HotelLocationMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return CarCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 160,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.zentrip.app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: point,
                      width: 40,
                      height: 40,
                      alignment: Alignment.topCenter,
                      child: const Icon(Icons.location_on_rounded,
                          size: 40, color: AppColors.accentRed),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          if (address.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.hotel_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: carInk(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// White pill on photos (distance, featured...).
class PhotoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const PhotoPill({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: carSurface(context),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
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
