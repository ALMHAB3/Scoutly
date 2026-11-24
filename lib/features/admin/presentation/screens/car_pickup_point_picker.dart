import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/current_location_service.dart';
import '../../../../global_widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../global_widgets/ui/ui.dart';

/// Lets a car partner place the car's pickup point: tap the map where the
/// car is, or use the device's current location (when standing at the car).
class CarPickupPointPicker extends StatefulWidget {
  final LatLng initial;
  final bool hasInitialPin;
  final CurrentLocationService locationService;

  /// Screen title and hint; default to the car pickup texts.
  final String? title;
  final String? hint;

  const CarPickupPointPicker({
    super.key,
    required this.initial,
    this.hasInitialPin = false,
    this.locationService = const CurrentLocationService(),
    this.title,
    this.hint,
  });

  /// Opens the picker; returns the chosen point or null when cancelled.
  static Future<LatLng?> open(
    BuildContext context, {
    required LatLng initial,
    bool hasInitialPin = false,
    String? title,
    String? hint,
  }) =>
      Navigator.push<LatLng>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => CarPickupPointPicker(
            initial: initial,
            hasInitialPin: hasInitialPin,
            title: title,
            hint: hint,
          ),
        ),
      );

  @override
  State<CarPickupPointPicker> createState() => _CarPickupPointPickerState();
}

class _CarPickupPointPickerState extends State<CarPickupPointPicker> {
  final _map = MapController();
  late LatLng? _pin = widget.hasInitialPin ? widget.initial : null;
  bool _locating = false;

  bool get _ar => AppLocalizations.of(context).localeName.startsWith('ar');

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await widget.locationService.getPosition();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _pin = point);
      _map.move(point, 17);
    } on CurrentLocationException {
      if (mounted) {
        AppSnackbar.error(
          context,
          _ar
              ? 'تعذّر تحديد موقعك. فعّل الموقع أو اختر النقطة على الخريطة.'
              : 'Could not get your location. Turn on location or tap the map.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = _ar;
    final pin = _pin;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.title ?? (ar ? 'موقع استلام السيارة' : 'Car pickup point')),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: widget.hasInitialPin ? 16 : 13,
              onTap: (_, point) => setState(() => _pin = point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.zentrip.app',
              ),
              if (pin != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pin,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 44,
                        color: AppColors.accentRed,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          PositionedDirectional(
            top: 12,
            start: 12,
            end: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.hint ??
                      (ar
                          ? 'اضغط على الخريطة في المكان الموجودة فيه السيارة، أو استخدم موقعك الحالي إذا كنت عند السيارة.'
                          : 'Tap the map where the car is, or use your current location if you are at the car.'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pin != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${pin.latitude.toStringAsFixed(6)}, ${pin.longitude.toStringAsFixed(6)}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              AppButton.icon(
                key: const ValueKey('pickup-use-location'),
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_rounded),
                label: Text(
                    ar ? 'استخدم موقعي الحالي' : 'Use my current location'),
                variant: AppButtonVariant.secondary,
              ),
              const SizedBox(height: 8),
              AppButton(
                key: const ValueKey('pickup-confirm'),
                onPressed:
                    pin == null ? null : () => Navigator.pop(context, pin),
                child: Text(ar ? 'تأكيد الموقع' : 'Confirm location'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
