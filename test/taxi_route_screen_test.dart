import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/features/transfers/presentation/screens/transfers_screen.dart';
import 'package:scoutly/l10n/app_localizations.dart';

void main() {
  testWidgets('route step places known cities and shows distance and time',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TransfersScreen(
        initialFromLocation: 'Misrata',
        initialToLocation: 'Tripoli',
        showMapTiles: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Route'), findsOneWidget);
    expect(find.text('Misrata'), findsOneWidget);
    expect(find.text('Tripoli'), findsOneWidget);
    // Misrata → Tripoli airports are ~180 km apart in a straight line.
    expect(find.textContaining(RegExp(r'^1[78]\d\.\d km$')), findsOneWidget);
    expect(find.text('~2h 55m drive'), findsOneWidget);
    expect(find.byKey(const ValueKey('taxi-choose-car')), findsOneWidget);
  });

  testWidgets('swapping moves the cities between pickup and destination',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TransfersScreen(
        initialFromLocation: 'Misrata',
        initialToLocation: 'Tripoli',
        showMapTiles: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byIcon(Icons.swap_vert_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    final pickup = tester.widget<TextField>(find.descendant(
        of: find.byKey(const ValueKey('taxi-pickup')),
        matching: find.byType(TextField)));
    expect(pickup.controller!.text, 'Tripoli');
  });
}
