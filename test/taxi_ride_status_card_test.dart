import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/features/transfers/presentation/widgets/taxi_ride_status_card.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/models/transfer_model.dart';

final _pickup = DateTime(2026, 11, 27, 10);
final _ride = TransferModel(
  id: '1',
  vehicleType: 'sedan',
  vehicleName: 'Toyota Camry 2024',
  maxPassengers: 4,
  maxLuggage: 3,
  price: 45,
  pickupLocation: 'Misrata',
  dropoffLocation: 'Tripoli',
  pickupTime: _pickup,
  durationMinutes: 150,
  driverName: 'Ali Ben Omar',
  driverRating: 4.9,
  providerName: 'Libya Cars',
);

Future<void> _show(WidgetTester tester, DateTime now) =>
    tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TaxiRideStatusCard(ride: _ride, clock: () => now),
        ),
      ),
    ));

void main() {
  test('phase follows the pickup time and the ride duration', () {
    expect(taxiRidePhase(_ride, _pickup.subtract(const Duration(days: 2))),
        TaxiRidePhase.scheduled);
    expect(taxiRidePhase(_ride, _pickup.subtract(const Duration(minutes: 20))),
        TaxiRidePhase.soon);
    expect(taxiRidePhase(_ride, _pickup.add(const Duration(minutes: 30))),
        TaxiRidePhase.onRide);
    expect(taxiRidePhase(_ride, _pickup.add(const Duration(hours: 3))),
        TaxiRidePhase.finished);
  });

  testWidgets('scheduled ride counts down in days', (tester) async {
    await _show(tester, _pickup.subtract(const Duration(days: 2, hours: 3)));
    expect(find.text('Ride scheduled'), findsOneWidget);
    expect(find.text('Ali Ben Omar will pick you up from Misrata'),
        findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(find.text('Ali Ben Omar'), findsOneWidget);
  });

  testWidgets('last hour before pickup counts down in minutes', (tester) async {
    await _show(tester, _pickup.subtract(const Duration(minutes: 25)));
    expect(find.text('Pickup soon'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
    expect(find.text('min'), findsOneWidget);
  });

  testWidgets('after the ride it says thanks', (tester) async {
    await _show(tester, _pickup.add(const Duration(hours: 4)));
    expect(find.text('Ride finished'), findsOneWidget);
    expect(find.text('Thanks for riding with Ali Ben Omar'), findsOneWidget);
  });
}
