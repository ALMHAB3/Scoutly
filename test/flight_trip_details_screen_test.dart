import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/core/constants/app_colors.dart';
import 'package:scoutly/core/services/api_result.dart';
import 'package:scoutly/global_widgets/ui/ui.dart';
import 'package:scoutly/features/flight_booking/presentation/screens/flight_seat_widgets.dart';
import 'package:scoutly/models/flight_model.dart';
import 'package:scoutly/models/flight_seat_map.dart';

import 'support/trip_details_harness.dart';

FlightModel _partnerFlight() => FlightModel(
      id: '81',
      partnerListingId: 81,
      airline: 'Scoutly Air',
      airlineCode: 'ZT',
      flightNumber: 'ZT 482',
      originCode: 'MRA',
      originCity: 'Misrata',
      destinationCode: 'MJI',
      destinationCity: 'Tripoli',
      departureTime: DateTime(2027, 9, 5, 6, 14),
      arrivalTime: DateTime(2027, 9, 5, 7, 3),
      durationMinutes: 49,
      isDirect: true,
      stops: 0,
      economyPrice: 138,
      seatsAvailable: 24,
      aircraftName: 'Airbus A320',
    );

FlightSeatMap _map({Set<String>? occupied}) => FlightSeatMap(
      rowCount: 18,
      seatLetters: const ['A', 'B', 'C', 'D', 'E', 'F'],
      extraLegroomRows: const {14},
      occupiedSeats: occupied ?? const {'12B', '14C', '15D'},
      fares: const [
        FlightSeatFare(
          id: 'economy',
          label: 'Economy',
          price: 138,
          availableSeats: 25,
          sharedInventory: false,
        ),
        FlightSeatFare(
          id: 'business',
          label: 'Business',
          price: 331,
          availableSeats: 30,
          sharedInventory: true,
        ),
      ],
      cabins: const [
        FlightSeatCabin(
          id: 'aft',
          name: 'Cabin 1',
          rows: [12, 13],
          totalSeats: 12,
          availableSeats: 5,
        ),
        FlightSeatCabin(
          id: 'forward',
          name: 'Forward cabin',
          rows: [14, 15],
          totalSeats: 6,
          availableSeats: 4,
        ),
      ],
      extraLegroomFee: 22,
      taxRate: .12,
      bookingFee: 8,
      extras: const {'extra_baggage': 18, 'flexible_ticket': 12},
    );

String _footerTotal(WidgetTester tester) {
  final footer = find.byKey(const ValueKey('trip-details-footer'));
  return tester
      .widgetList<Text>(
          find.descendant(of: footer, matching: find.byType(Text)))
      .first
      .data!;
}

Future<void> _tapSeat(WidgetTester tester, String seat) async {
  final finder = find.byKey(ValueKey('seat-$seat'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapContinue(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(AppButton, 'Continue'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => setProfileCurrency('USD'));

  testWidgets(
      'one screen: summary once, fare cards with ✓, travelers, deck, 2 steps',
      (tester) async {
    usePhoneViewport(tester);
    final controller = tripController(_partnerFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Trip Details'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Pay'), findsOneWidget);
    expect(find.text('Fare'), findsNothing);
    expect(find.text('Passengers'), findsNothing);
    // Route summary appears once (no duplicate line at the bottom).
    expect(find.text('MRA  →  MJI'), findsOneWidget);
    // Economy is a single selectable fare card (no separate "Fare price").
    expect(find.text('Economy'), findsOneWidget);
    expect(find.text('Fare price'), findsNothing);
    expect(find.text('Business'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('Compare in'), findsNothing);
    expect(find.text('Who’s flying?'), findsOneWidget);
    expect(find.text('DECK'), findsOneWidget);
    expect(find.byType(FlightSeatLegend), findsOneWidget);
    // 1 adult economy: 138 × 1.12 + 8 = 162.56 USD
    expect(_footerTotal(tester), '\$162.56');
    expect(find.text('Economy · 1 traveler · total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('counters drive traveler forms and the live total',
      (tester) async {
    usePhoneViewport(tester);
    final controller = tripController(_partnerFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Full Name'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Adults +'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Children +'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Full Name'), findsNWidgets(3));
    expect(find.text('Traveler 3 · Child'), findsOneWidget);
    // 3 seated × 138 × 1.12 + 8 = 471.68
    expect(_footerTotal(tester), '\$471.68');

    await tester.tap(find.byKey(const ValueKey('fare-business')));
    await tester.pumpAndSettle();
    // 3 × 331 × 1.12 + 8 = 1,120.16
    expect(_footerTotal(tester), '\$1,120.16');

    // Infant: a traveler without a seat or fare.
    await tester.tap(find.bySemanticsLabel('Infants +'));
    await tester.pumpAndSettle();
    expect(find.text('Traveler 4 · Infant'), findsOneWidget);
    expect(find.text('Business · 4 travelers · total'), findsOneWidget);
    expect(_footerTotal(tester), '\$1,120.16');

    // Extra-legroom seat (+22) is added to the total with tax.
    await _tapSeat(tester, '12A');
    await tester.tap(find.descendant(
        of: find.byType(FlightCabinSelector), matching: find.text('2')));
    await tester.pumpAndSettle();
    await _tapSeat(tester, '14A');
    // (993 + 22) × 1.12 + 8 = 1,144.80
    expect(_footerTotal(tester), '\$1,144.80');

    // Profile currency change updates the price immediately.
    await setProfileCurrency('LYD');
    await tester.pumpAndSettle();
    expect(_footerTotal(tester), contains('7,326.720'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('continue with missing data scrolls to the first field error',
      (tester) async {
    usePhoneViewport(tester, height: 844);
    final controller = tripController(_partnerFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();

    await _tapContinue(tester);
    expect(find.text('This field is required').hitTestable(), findsWidgets);
    expect(find.text('Review & Pay'), findsNothing);

    // Details complete but no seat: the seat section shows its error.
    await fillTraveler(tester, 0, contact: true);
    await _tapContinue(tester);
    expect(
        find.byKey(const ValueKey('seat-error')).hitTestable(), findsOneWidget);
    expect(find.text('Choose a seat for every traveler'), findsOneWidget);
    expect(find.text('Review & Pay'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seat numbers follow travelers and taken seats are disabled',
      (tester) async {
    final semantics = tester.ensureSemantics();
    usePhoneViewport(tester);
    final controller = tripController(_partnerFlight(), passengers: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Seat 12B, taken'), findsOneWidget);
    await _tapSeat(tester, '13A'); // traveler 1
    await _tapSeat(tester, '12A'); // traveler 2
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('seat-13A')), matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: find.byKey(const ValueKey('seat-12A')), matching: find.text('2')),
      findsOneWidget,
    );
    final material = tester.widget<Material>(find.descendant(
        of: find.byKey(const ValueKey('seat-12A')),
        matching: find.byType(Material)));
    expect(material.color, AppColors.primary);
    semantics.dispose();
  });

  testWidgets('seat map failure shows "Seat selection not available" + retry',
      (tester) async {
    usePhoneViewport(tester);
    var calls = 0;
    final controller = tripController(_partnerFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async {
        calls++;
        return calls == 1
            ? ApiResult.failure('Seat map temporarily unavailable')
            : ApiResult.success(_map());
      },
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Seat selection not available'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Seat selection not available'), findsNothing);
    expect(find.text('DECK'), findsOneWidget);
  });

  testWidgets('complete details open Pay with travelers, seats and total',
      (tester) async {
    usePhoneViewport(tester);
    final controller = tripController(_partnerFlight(), passengers: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();

    await fillTraveler(tester, 0, name: 'Omar Benali', contact: true);
    await fillTraveler(tester, 1, name: 'Salma Benali');
    await _tapSeat(tester, '13A');
    await _tapSeat(tester, '13B');
    await _tapContinue(tester);

    expect(find.text('Review & Pay'), findsOneWidget);
    expect(find.text('Omar Benali'), findsOneWidget);
    expect(find.text('Salma Benali'), findsOneWidget);
    expect(find.text('13A, 13B'), findsOneWidget);
    // 2 × 138 × 1.12 + 8 = 317.12; price lines use distinct labels.
    expect(find.text('Pay \$317.12'), findsOneWidget);
    expect(find.text('Ticket Price × 2'), findsOneWidget);
    expect(find.text('Taxes & Fees'), findsOneWidget);
    expect(find.text('Service Fee'), findsOneWidget);
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AppButton>(find.byType(AppButton)).onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('works on a 360 px phone without overflow', (tester) async {
    usePhoneViewport(tester, width: 360, height: 3200);
    final controller = tripController(_partnerFlight(), passengers: 3);
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      loader: (_) async => ApiResult.success(_map()),
    ));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Full Name'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
