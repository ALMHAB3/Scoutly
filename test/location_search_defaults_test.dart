import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scoutly/core/services/api_service.dart';
import 'package:scoutly/core/services/current_location_service.dart';
import 'package:scoutly/features/car_rental/presentation/screens/car_rental_screen.dart';
import 'package:scoutly/features/hotel_booking/logic/hotel_controller.dart';
import 'package:scoutly/features/hotel_booking/presentation/screens/hotel_search_screen.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ApiService.instance.init();

  testWidgets('hotel search stays blank until current location is requested',
      (tester) async {
    final location = _MisrataLocationService();
    final controller = HotelController();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HotelSearchScreen(
          controller: controller,
          locationService: location,
        ),
        routes: {
          AppRoutes.hotelResults: (_) =>
              const Scaffold(body: Text('Hotel results')),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    final locationField = _fieldWithHint('City or destination...');
    expect(tester.widget<TextField>(locationField).controller!.text, isEmpty);
    expect(location.placeRequests, 0);

    await tester.tap(find.byTooltip('Use my current location'));
    await tester.pumpAndSettle();

    expect(location.placeRequests, 1);
    expect(controller.searchParams?.city, 'Misrata');
    expect(find.text('Hotel results'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('car rental uses the customer\'s current city on open',
      (tester) async {
    final location = _MisrataLocationService();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CarRentalScreen(locationService: location),
      ),
    );
    await tester.pumpAndSettle();

    // Customers only see cars of the city they are in.
    expect(location.placeRequests, 1);
    expect(find.text('Misrata'), findsOneWidget);
  });
}

Finder _fieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

class _MisrataLocationService extends CurrentLocationService {
  int placeRequests = 0;

  @override
  Future<CurrentPlace> getCurrentPlace() async {
    placeRequests++;
    return CurrentPlace(
      position: Position(
        longitude: 15.0610,
        latitude: 32.3250,
        timestamp: DateTime(2026, 10, 30),
        accuracy: 1,
        altitude: 0,
        altitudeAccuracy: 1,
        heading: 0,
        headingAccuracy: 1,
        speed: 0,
        speedAccuracy: 1,
      ),
      city: 'Misrata',
    );
  }
}
