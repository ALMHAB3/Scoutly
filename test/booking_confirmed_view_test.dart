import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/global_widgets/app_shell.dart';
import 'package:scoutly/global_widgets/booking_confirmed_view.dart';
import 'package:scoutly/l10n/app_localizations.dart';

Widget _confirmed() => const BookingConfirmedView(
      title: 'Booking Confirmed!',
      subtitle: 'Your stay is all set.',
      bookingIdLabel: 'Booking ID',
      copyTooltip: 'Copy',
      copiedMessage: 'Copied',
      viewDetailsLabel: 'View Booking Details',
      okLabel: 'OK',
      reference: 'ZT-H-1',
      photo: SizedBox(height: 70),
      name: 'Al-Masa Grand Hotel',
      lines: [(Icons.bed_rounded, '3 nights')],
    );

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Column(children: [
          const Text('HOME'),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _confirmed()),
            ),
            child: const Text('open'),
          ),
        ]),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => AppShellTabController.pendingIndex.value = null);

  testWidgets('OK closes the confirmation and opens the home tab',
      (tester) async {
    await _open(tester);
    expect(find.text('Booking Confirmed!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('booking-ok')));
    await tester.pumpAndSettle();

    expect(find.text('Booking Confirmed!'), findsNothing);
    expect(find.text('HOME'), findsOneWidget);
    expect(AppShellTabController.pendingIndex.value, 0);
  });

  testWidgets('View Booking Details opens My Trips', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const ValueKey('booking-view-details')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(AppShellTabController.pendingIndex.value, 3);
  });
}
