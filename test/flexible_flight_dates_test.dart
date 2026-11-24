import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/features/flight_booking/logic/flexible_flight_selection.dart';
import 'package:scoutly/features/flight_booking/presentation/widgets/flexible_flight_dates_button.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/global_widgets/ui/ui.dart';

void main() {
  Widget app(ValueChanged<FlexibleFlightSelection?> onChanged) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: FlexibleFlightDatesButton(
            selection: null,
            onChanged: onChanged,
          ),
        ),
      );

  testWidgets('selects multiple months and a weekend trip', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlexibleFlightSelection? selected;
    await tester.pumpWidget(app((value) => selected = value));

    await tester.tap(find.text("I'm flexible"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A weekend'));
    await tester.tap(find.byIcon(Icons.calendar_month_rounded).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Select dates'));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.departureMonths, hasLength(2));
    expect(selected!.tripDurationDays, 2);
    expect(selected!.weekendsOnly, isTrue);
    expect(selected!.isValid, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom trip duration rejects invalid input', (tester) async {
    FlexibleFlightSelection? selected;
    await tester.pumpWidget(app((value) => selected = value));
    await tester.tap(find.text("I'm flexible"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '0');
    await tester.pump();

    final disabledButton = tester.widget<AppButton>(
      find.widgetWithText(AppButton, 'Select dates'),
    );
    expect(disabledButton.onPressed, isNull);
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    await tester.tap(find.widgetWithText(AppButton, 'Select dates'));
    await tester.pumpAndSettle();

    expect(selected!.tripDurationDays, 12);
    expect(tester.takeException(), isNull);
  });
}
