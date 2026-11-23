import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/core/services/api_result.dart';
import 'package:zentrip/global_widgets/ui/ui.dart';
import 'package:zentrip/global_widgets/payment_checkout_screen.dart';
import 'package:zentrip/l10n/app_localizations.dart';
import 'package:zentrip/models/flight_model.dart';
import 'package:zentrip/models/payment_session.dart';
import 'package:zentrip/models/trip_model.dart';

import 'support/trip_details_harness.dart';

FlightModel _duffelFlight() => FlightModel(
      id: 'duffel-off_example',
      source: 'duffel',
      duffelOfferId: 'off_example',
      airline: 'Example Air',
      airlineCode: 'EA',
      flightNumber: 'EA123',
      originCode: 'MRA',
      originCity: 'Misrata',
      destinationCode: 'TUN',
      destinationCity: 'Tunis',
      departureTime: DateTime.utc(2027, 3, 10, 8),
      arrivalTime: DateTime.utc(2027, 3, 10, 10),
      durationMinutes: 120,
      isDirect: true,
      stops: 0,
      economyPrice: 240,
      seatsAvailable: -1,
      priceCurrencyCode: 'EUR',
      priceIsTotal: true,
    );

Widget _localizedApp(Widget home) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  testWidgets('simulated payment shows the amount in the offer currency',
      (tester) async {
    await tester.pumpWidget(
      _localizedApp(
        const PaymentCheckoutScreen(
          session: PaymentSession(
            sessionId: 'mock-duffel',
            checkoutUrl: 'mock://checkout',
          ),
          amount: 240,
          currencyCode: 'EUR',
        ),
      ),
    );

    expect(find.text('Total: EUR 240.00'), findsOneWidget);
  });

  testWidgets(
      'Duffel simulation charges the profile currency and saves only after payment',
      (tester) async {
    usePhoneViewport(tester);
    // Profile currency = offer currency: the quote is charged unchanged.
    await setProfileCurrency('EUR');
    TripModel? savedTrip;
    var paymentAmount = 0.0;
    var paymentCurrency = '';
    final controller = tripController(_duffelFlight(), passengers: 2);
    addTearDown(controller.dispose);

    await tester.pumpWidget(tripApp(
      controller: controller,
      paymentLauncher: (
        context, {
        required amount,
        required currencyCode,
        required description,
        required referenceId,
      }) async {
        paymentAmount = amount;
        paymentCurrency = currencyCode;
        return true;
      },
      tripCreator: (trip) async {
        savedTrip = trip;
        return ApiResult.success(trip);
      },
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Simulated seat map'), findsOneWidget);
    await fillTraveler(tester, 0, contact: true);
    await fillTraveler(tester, 1, name: 'Second Traveler');
    for (final seat in ['seat-1A', 'seat-1B']) {
      final finder = find.byKey(ValueKey(seat));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(paymentAmount, 240);
    expect(paymentCurrency, 'EUR');
    expect(savedTrip?.source, 'duffel');
    expect(savedTrip?.sourceOfferId, 'off_example');
    expect(savedTrip?.priceCurrencyCode, 'EUR');
    expect(savedTrip?.passengerCount, 2);
    expect(savedTrip?.isSimulated, isTrue);
    expect(savedTrip?.bookingRef, startsWith('ZT-SIM-DUF-'));
    expect(find.text('Simulation'), findsOneWidget);
    expect(find.text('Ticket 1 of 2 · Adult'), findsOneWidget);
    expect(find.text('€240.00'), findsOneWidget);
  });

  testWidgets('Duffel price follows the profile currency', (tester) async {
    usePhoneViewport(tester);
    await setProfileCurrency('USD');
    final controller = tripController(_duffelFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(controller: controller));
    await tester.pumpAndSettle();
    // 240 EUR / 0.92 = 260.87 USD (app's fallback reference rates).
    expect(find.text('\$260.87'), findsWidgets);
    await setProfileCurrency('EUR');
    await tester.pumpAndSettle();
    expect(find.text('€240.00'), findsWidgets);
  });

  testWidgets('failed Duffel simulator payment does not save a trip',
      (tester) async {
    usePhoneViewport(tester);
    await setProfileCurrency('EUR');
    var saveCalls = 0;
    final controller = tripController(_duffelFlight());
    addTearDown(controller.dispose);
    await tester.pumpWidget(tripApp(
      controller: controller,
      paymentLauncher: (
        context, {
        required amount,
        required currencyCode,
        required description,
        required referenceId,
      }) async =>
          false,
      tripCreator: (trip) async {
        saveCalls++;
        return ApiResult.success(trip);
      },
    ));
    await tester.pumpAndSettle();

    await fillTraveler(tester, 0, contact: true);
    final seat = find.byKey(const ValueKey('seat-1A'));
    await tester.ensureVisible(seat);
    await tester.tap(seat);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppButton));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(find.textContaining('No trip was saved'), findsOneWidget);
  });
}
