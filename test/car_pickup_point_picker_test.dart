import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:zentrip/core/services/current_location_service.dart';
import 'package:zentrip/features/admin/presentation/screens/car_pickup_point_picker.dart';
import 'package:zentrip/global_widgets/ui/ui.dart';
import 'package:zentrip/l10n/app_localizations.dart';

class _AtTheCar extends CurrentLocationService {
  @override
  Future<Position> getPosition() async => Position(
        latitude: 32.3301,
        longitude: 15.0702,
        timestamp: DateTime(2026, 11, 23),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      );
}

void main() {
  Future<LatLng?> open(WidgetTester tester) async {
    LatLng? result;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await Navigator.push<LatLng>(
              context,
              MaterialPageRoute(
                builder: (_) => CarPickupPointPicker(
                  initial: const LatLng(32.3754, 15.0925),
                  locationService: _AtTheCar(),
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('pickup point comes from the partner\'s location at the car',
      (tester) async {
    await open(tester);
    // Nothing chosen yet: cannot confirm.
    final confirm = find.byKey(const ValueKey('pickup-confirm'));
    expect(tester.widget<AppButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('pickup-use-location')));
    await tester.pumpAndSettle();
    expect(find.text('32.330100, 15.070200'), findsOneWidget);
  });

  testWidgets('tapping the map moves the pickup point', (tester) async {
    await open(tester);
    final map = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(map + const Offset(60, 40));
    // The map waits for a possible double tap before reporting a tap.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((t) => RegExp(r'^\d+\.\d+, \d+\.\d+$').hasMatch(t));
    expect(texts, isNotEmpty);
    expect(texts.first, isNot('32.375400, 15.092500'));
  });
}
