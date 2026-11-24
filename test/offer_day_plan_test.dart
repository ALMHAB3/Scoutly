import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/core/constants/app_colors.dart';
import 'package:zentrip/features/trips/presentation/screens/offer_day_plan_view.dart';
import 'package:zentrip/l10n/app_localizations.dart';
import 'package:zentrip/models/offer_stop.dart';
import 'package:zentrip/models/travel_package_model.dart';

const _stops = [
  OfferStop(
      day: 1,
      time: '08:30',
      name: 'Old Town Cafe',
      nameAr: 'مقهى المدينة القديمة',
      category: 'Coffee shop',
      durationMinutes: 45,
      latitude: 32.8963,
      longitude: 13.1795),
  OfferStop(
      day: 1,
      time: '10:00',
      name: 'Red Castle Museum',
      category: 'Museum',
      durationMinutes: 90,
      latitude: 32.8946,
      longitude: 13.1813),
  OfferStop(
      day: 1,
      time: '17:30',
      name: 'Sunset at the Corniche',
      durationMinutes: 120,
      latitude: 32.8890,
      longitude: 13.2010),
  OfferStop(day: 2, time: '09:00', name: 'Leptis Magna', durationMinutes: 180),
];

TravelPackage _offer() => const TravelPackage(
      id: 'o1',
      title: 'Tripoli Heritage Weekend',
      location: 'Tripoli',
      country: 'Libya',
      description: 'A weekend',
      imageUrl: '',
      pricePerPerson: 300,
      flightPricePerPerson: 100,
      hotelPricePerNight: 100,
      durationNights: 2,
      rating: 4.8,
      reviewCount: 10,
      gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary]),
      icon: Icons.location_city,
      highlights: [],
      itinerary: _stops,
    );

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  test('day totals: time from first start to last end, straight-line km', () {
    final day1 = _stops.where((s) => s.day == 1).toList();
    expect(offerDayMinutes(day1), (17 * 60 + 30 + 120) - (8 * 60 + 30));
    expect(offerDayDistanceKm(day1), closeTo(2.2, 0.4));
    expect(offerDayDistanceKm([_stops.last]), 0);
  });

  test('stops come back from JSON sorted by day and time', () {
    final offer = TravelPackage.fromJson({
      'id': 'x',
      'itinerary': [
        {'day': 2, 'time': '09:00', 'name': 'B'},
        {'day': 1, 'time': '18:00', 'name': 'A2'},
        {'day': 1, 'time': '07:15', 'name': 'A1'},
        {'day': 1, 'time': '10:00', 'name': ''},
      ],
    });
    expect(offer.itinerary.map((s) => s.name), ['A1', 'A2', 'B']);
    expect(offer.toJson()['itinerary'], hasLength(3));
  });

  testWidgets('shows the day plan timeline, day chips and totals',
      (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app(OfferDayPlanView(
      package: _offer(),
      details: const [Text('details-content')],
      booking: false,
      onBook: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.text('Your trip in'), findsOneWidget);
    expect(find.text('Tripoli'), findsOneWidget);
    expect(find.text('Old Town Cafe'), findsOneWidget);
    expect(find.text('Coffee shop'), findsOneWidget);
    expect(find.text('Leptis Magna'), findsNothing);
    expect(find.text('~11h'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Leptis Magna'), findsOneWidget);
    expect(find.text('Old Town Cafe'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('offer-tab-details')));
    await tester.pumpAndSettle();
    expect(find.text('details-content'), findsOneWidget);
    expect(find.byKey(const ValueKey('offer-view-route')), findsNothing);
    expect(find.byKey(const ValueKey('offer-book')), findsOneWidget);
  });

  testWidgets('route screen numbers the stops and sums the route',
      (tester) async {
    _tallView(tester);
    await tester.pumpWidget(_app(OfferRouteScreen(
      package: _offer(),
      day: 1,
      showMapTiles: false,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Route summary'), findsOneWidget);
    expect(find.text('Red Castle Museum'), findsOneWidget);
    for (final n in ['1', '2', '3']) {
      expect(find.text(n), findsWidgets);
    }
    expect(find.textContaining(' km'), findsOneWidget);

    await tester.tap(find.text('List view'));
    await tester.pumpAndSettle();
    expect(find.text('Sunset at the Corniche'), findsOneWidget);
  });
}
