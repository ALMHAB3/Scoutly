import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import 'app_card.dart';
import 'ui_colors.dart';

/// Small map card with a pin and the place's address underneath.
class AppPlaceMap extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String address;
  final IconData addressIcon;
  final double height;

  const AppPlaceMap({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.address,
    this.addressIcon = Icons.place_rounded,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: height,
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
                  Icon(addressIcon, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.uiInk,
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
