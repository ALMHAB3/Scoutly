import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scoutly/global_widgets/payment_method_screen.dart';
import 'package:scoutly/global_widgets/payment_methods_card.dart';
import 'package:scoutly/l10n/app_localizations.dart';
import 'package:scoutly/models/payment_method_option.dart';

Widget _app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

void main() {
  test('only known methods from the server are kept, with their group', () {
    expect(PaymentMethodOption.fromJson({'id': 'bitcoin', 'group': 'other'}),
        isNull);
    final sadad =
        PaymentMethodOption.fromJson({'id': 'SADAD', 'group': 'other'})!;
    expect(sadad.id, 'sadad');
    expect(sadad.group, PaymentMethodGroup.other);
    expect(sadad.name(true), 'سداد');
  });

  testWidgets('lists methods by group and returns the chosen one',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    PaymentMethodOption? chosen;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            chosen = await PaymentMethodScreen.choose(
              context,
              methods: const [
                PaymentMethodOption(
                    id: 'card', group: PaymentMethodGroup.cards),
                PaymentMethodOption(
                    id: 'paypal', group: PaymentMethodGroup.wallets),
                PaymentMethodOption(
                    id: 'sadad', group: PaymentMethodGroup.other),
              ],
              amount: 120,
              currencyCode: 'LYD',
              description: 'BMW X5',
            );
          },
          child: const Text('pay'),
        ),
      ),
    )));
    await tester.tap(find.text('pay'));
    await tester.pumpAndSettle();

    expect(find.text('How would you like to pay?'), findsOneWidget);
    expect(find.text('CARDS'), findsOneWidget);
    expect(find.text('DIGITAL WALLETS'), findsOneWidget);
    expect(find.text('OTHER'), findsOneWidget);
    expect(find.text('BMW X5'), findsOneWidget);

    await tester.tap(find.text('Sadad'));
    await tester.pump();
    // The pay bar shows the selected method.
    expect(find.text('Sadad'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('payment-method-continue')));
    await tester.pumpAndSettle();
    expect(chosen?.id, 'sadad');
  });

  testWidgets(
      'booking card shows the bank card when the gateway has no methods',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: PaymentMethodsCard(
        title: 'Payment Method',
        cardTitle: 'Bank card',
        cardNote: 'Hosted page',
        secureNote: 'Secure',
        loader: () async => const [],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Bank card'), findsOneWidget);
    expect(
        find.text("You'll choose how to pay on the next step."), findsNothing);
  });

  testWidgets('booking card lists the real methods when the gateway has them',
      (tester) async {
    await tester.pumpWidget(_app(Scaffold(
      body: PaymentMethodsCard(
        title: 'Payment Method',
        cardTitle: 'Bank card',
        cardNote: 'Hosted page',
        secureNote: 'Secure',
        loader: () async => const [
          PaymentMethodOption(id: 'card', group: PaymentMethodGroup.cards),
          PaymentMethodOption(id: 'mobicash', group: PaymentMethodGroup.other),
        ],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('MobiCash'), findsOneWidget);
    expect(find.text("You'll choose how to pay on the next step."),
        findsOneWidget);
  });
}
