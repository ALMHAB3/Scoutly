import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zentrip/core/services/api_service.dart';
import 'package:zentrip/features/car_rental/logic/car_controller.dart';
import 'package:zentrip/features/car_rental/presentation/screens/car_booking_confirmed_screen.dart';
import 'package:zentrip/features/car_rental/presentation/screens/car_detail_screen.dart';
import 'package:zentrip/features/car_rental/presentation/screens/car_search_screen.dart';
import 'package:zentrip/l10n/app_localizations.dart';
import 'package:zentrip/models/booking_model.dart';
import 'package:zentrip/models/car_model.dart';

CarModel _car(
  String id, {
  String brand = 'BMW',
  String model = 'X5',
  String category = 'suv',
  double price = 85,
  String transmission = 'automatic',
  bool ac = true,
  bool gps = false,
  List<String> features = const [],
  double rating = 4.8,
  String description = '',
}) =>
    CarModel(
      id: id,
      brand: brand,
      model: model,
      category: category,
      year: 2025,
      pricePerDay: price,
      seats: 4,
      transmission: transmission,
      fuelType: 'gasoline',
      features: features,
      rating: rating,
      pickupLocation: 'Tripoli',
      hasAC: ac,
      hasGPS: gps,
      description: description,
    );

final _cars = [
  _car('1', price: 85, gps: true, features: ['Bluetooth']),
  _car('2',
      brand: 'Kia',
      model: 'Picanto',
      category: 'economy',
      price: 30,
      transmission: 'manual',
      rating: 4.2),
  _car('3',
      brand: 'Tesla',
      model: 'Model 3',
      category: 'electric',
      price: 75,
      rating: 4.9,
      features: ['GPS navigation']),
];

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  ApiService.instance.init();

  test('filters combine car type, daily price and features', () {
    expect(_cars.where(const CarFilters().matches).length, 3);
    expect(
      _cars.where(const CarFilters(carType: 'suv').matches).map((c) => c.id),
      ['1'],
    );
    expect(
      _cars
          .where(
              const CarFilters(minPricePerDay: 40, maxPricePerDay: 80).matches)
          .map((c) => c.id),
      ['3'],
    );
    expect(
      _cars
          .where(const CarFilters(features: {CarFeature.gps}).matches)
          .map((c) => c.id),
      ['1', '3'],
    );
    expect(
      _cars
          .where(const CarFilters(
            features: {CarFeature.automatic, CarFeature.bluetooth},
          ).matches)
          .map((c) => c.id),
      ['1'],
    );
  });

  test('cars are listed best rated first', () {
    expect(CarController.sortCars(_cars).map((c) => c.id), ['3', '1', '2']);
  });

  test('rental days and drop-off default to the pickup', () {
    final params = CarSearchParams(
      city: 'Tripoli',
      pickupDate: DateTime(2026, 12, 1),
      returnDate: DateTime(2026, 12, 4),
    );
    expect(params.days, 3);
    expect(params.dropoffOrPickup, 'Tripoli');
    expect(params.copyWith(dropoffCity: 'Misrata').dropoffOrPickup, 'Misrata');
  });

  testWidgets('search screen shows a live count of matching cars',
      (tester) async {
    await tester.pumpWidget(_app(CarSearchScreen(
      params: CarSearchParams.initial(city: 'Tripoli'),
      initialCars: _cars,
    )));
    await tester.pump();
    expect(find.text('Show 3 Results'), findsOneWidget);

    await tester.tap(find.text('SUV'));
    await tester.pump();
    expect(find.text('Show 1 Result'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.scrollUntilVisible(
      find.text('GPS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('GPS'));
    await tester.pump();
    expect(find.text('Show 2 Results'), findsOneWidget);
  });

  testWidgets('details screen shows features, about and Book Now',
      (tester) async {
    final ctrl = CarController()
      ..selectCar(_car('1',
          gps: true,
          features: ['Bluetooth'],
          description: 'Luxury SUV for long trips.'));
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: RouteSettings(arguments: ctrl),
        builder: (_) => const CarDetailScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('BMW X5'), findsOneWidget);
    expect(find.text('Luxury SUV for long trips.'), findsOneWidget);
    for (final label in ['AC', 'GPS', 'Bluetooth', 'Book Now', '4.8']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    ctrl.dispose();
  });

  test('calendar event covers pickup to drop-off day', () {
    final ics = CarBookingConfirmedScreen.calendarEvent(
      uid: 'ZT-C-1',
      title: 'Car pickup: BMW X5',
      location: 'Tripoli, Airport',
      description: 'Booking ID: ZT-C-1',
      start: DateTime(2026, 12, 1),
      end: DateTime(2026, 12, 4),
    );
    expect(ics, contains('DTSTART;VALUE=DATE:20261201'));
    expect(ics, contains('DTEND;VALUE=DATE:20261205'));
    expect(ics, contains(r'LOCATION:Tripoli\, Airport'));
    expect(ics, contains('\r\nEND:VCALENDAR'));
  });

  test('a car booking keeps the currency it was paid in', () {
    final booking = BookingModel(
      id: '1',
      type: BookingType.car,
      title: 'BMW X5',
      subtitle: 'Tripoli',
      date: DateTime.utc(2026, 11, 24),
      price: 310,
      bookingCurrencyCode: 'LYD',
      bookingDisplayAmount: 1984,
    );
    final json = booking.toJson();
    expect(json['booking_currency'], 'LYD');
    expect(json['booking_display_amount'], 1984);
    final back = BookingModel.fromJson({...json, 'id': '1'});
    expect(back.paidAmount, 1984);
    expect(back.paidCurrencyCode, 'LYD');
    final legacy = BookingModel.fromJson({...json}
      ..remove('booking_currency')
      ..remove('booking_display_amount'));
    expect(legacy.paidAmount, 310);
    expect(legacy.paidCurrencyCode, 'USD');
  });
}
