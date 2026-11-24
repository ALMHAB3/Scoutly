import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/core/services/api_result.dart';
import 'package:scoutly/features/trips/logic/trips_controller.dart';
import 'package:scoutly/features/trips/presentation/screens/my_trips_screen.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/models/booking_model.dart';
import 'package:scoutly/models/transfer_model.dart';
import 'package:scoutly/models/trip_model.dart';

void main() {
  testWidgets('My Trips displays and opens a saved transfer', (tester) async {
    final transfer = TransferModel(
      id: 'transfer-widget-1',
      vehicleType: 'sedan',
      vehicleName: 'Airport sedan',
      maxPassengers: 3,
      maxLuggage: 2,
      price: 24,
      pickupLocation: 'Tripoli Airport',
      dropoffLocation: 'Old Town Hotel',
      pickupTime: DateTime.now().add(const Duration(days: 3)),
      durationMinutes: 35,
      providerName: 'Partner Ride',
    );
    final controller = TripsController(
      loadFlightTrips: () async =>
          ApiResult<List<TripModel>>.success(const []),
      loadBookings: () async =>
          ApiResult<List<BookingModel>>.success(const []),
      loadTransfers: () async =>
          ApiResult<List<TransferModel>>.success([transfer]),
    );

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MyTripsScreen(controller: controller),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tripoli Airport → Old Town Hotel'), findsOneWidget);
    await tester.tap(find.text('Tripoli Airport → Old Town Hotel'));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle: sedan'), findsOneWidget);
    expect(find.text('35 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
