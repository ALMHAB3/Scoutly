import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zentrip/core/utils/price_format.dart';
import 'package:zentrip/features/hotel_booking/logic/hotel_controller.dart';
import 'package:zentrip/features/hotel_booking/presentation/screens/hotel_booking_screen.dart';
import 'package:zentrip/l10n/app_localizations.dart';
import 'package:zentrip/models/hotel_model.dart';

HotelModel _hotel() => HotelModel.fromJson({
      'id': 'partner-hotel-1',
      'source': 'partner',
      'name': 'Al-Masa Hotel',
      'city': 'Tripoli',
      'country': 'Libya',
      'location_name': 'Central Tripoli',
      'price_per_night': '100',
      'price_currency': 'USD',
      'tax_and_fees_percentage': 12,
      'availability_known': true,
      'available_rooms': 4,
      'partner_name': 'Al-Masa Hotels',
      'stars': 4,
    });

void main() {
  testWidgets('booking screen shows the stay, price details and total',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HotelBookingScreen(
        hotel: _hotel(),
        params: HotelSearchParams(
          city: 'Tripoli',
          checkIn: DateTime(2026, 12, 1),
          checkOut: DateTime(2026, 12, 4),
          rooms: 2,
          guests: 3,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(HotelBookingScreen));
    String shown(double usd) => formatPrice(context, usd);

    expect(find.text('Al-Masa Hotel'), findsOneWidget);
    expect(find.text('Provided by Al-Masa Hotels'), findsOneWidget);
    expect(find.text('3 nights · 2 rooms · 3 guests'), findsOneWidget);
    // 100 x 3 nights x 2 rooms = 600, taxes 12% = 72, total 672.
    expect(find.text(shown(600)), findsOneWidget);
    expect(find.text('Taxes & Fees (12%)'), findsOneWidget);
    expect(find.text(shown(72)), findsOneWidget);
    expect(find.byKey(const ValueKey('hotel-total')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('hotel-total'))).data,
      shown(672),
    );
    expect(find.textContaining('Pay ${shown(672)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
