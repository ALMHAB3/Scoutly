import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scoutly/core/services/currency_service.dart';
import 'package:scoutly/core/utils/price_format.dart';
import 'package:scoutly/features/flight_booking/logic/flight_controller.dart';
import 'package:scoutly/features/flight_booking/presentation/screens/flight_trip_details_screen.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/models/flight_model.dart';

/// Sets the user's profile currency (Profile → Preferences → Currency).
Future<void> setProfileCurrency(String code) async {
  SharedPreferences.setMockInitialValues({});
  await CurrencyService.instance.selectCode(code);
}

FlightController tripController(
  FlightModel flight, {
  int passengers = 1,
  String seatClass = 'economy',
  DateTime? returnDate,
}) {
  final controller = FlightController(searchFlights: (_) async => []);
  controller.searchParams = FlightSearchParams(
    originCode: flight.originCode,
    originCity: flight.originCity,
    destinationCode: flight.destinationCode,
    destinationCity: flight.destinationCity,
    departureDate: flight.departureTime,
    returnDate: returnDate,
    passengers: passengers,
    seatClass: seatClass,
  );
  controller.selectedFlight = flight;
  return controller;
}

Widget tripApp({
  required FlightController controller,
  FlightSeatMapLoader? loader,
  FlightPaymentLauncher? paymentLauncher,
  FlightTripCreator? tripCreator,
  Locale? locale,
}) =>
    CurrencyScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FlightTripDetailsScreen(
          controller: controller,
          seatMapLoader: loader,
          paymentLauncher: paymentLauncher,
          tripCreator: tripCreator,
        ),
      ),
    );

void usePhoneViewport(WidgetTester tester,
    {double width = 390, double height = 3200}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _type(
    WidgetTester tester, String label, int index, String text) async {
  final field = find.widgetWithText(TextFormField, label).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _pickDefaultDate(
    WidgetTester tester, String label, int index) async {
  final field = find.widgetWithText(TextFormField, label).at(index);
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// Fills traveler [index] the way a user would (dates via the picker's
/// default suggestion: adult ~30 years, child ~6, infant ~1; passport +5 y).
Future<void> fillTraveler(
  WidgetTester tester,
  int index, {
  String name = 'Example Traveler',
  bool contact = false,
}) async {
  await _type(tester, 'Full Name', index, name);
  await _pickDefaultDate(tester, 'Date of birth', index);
  await _type(tester, 'Nationality', index, 'Libyan');
  await _type(tester, 'Passport number', index, 'P${1234567 + index}');
  await _pickDefaultDate(tester, 'Passport expiry', index);
  if (contact) {
    await _type(tester, 'Email', index, 'traveler@example.com');
    await _type(tester, 'Phone Number', index, '+218910000000');
  }
}
