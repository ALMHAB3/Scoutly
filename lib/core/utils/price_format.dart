import 'package:flutter/widgets.dart';

import '../services/currency_service.dart';
import 'money_format.dart';

/// Connects the widget tree to [CurrencyService]. Every widget that calls
/// [formatPrice] or [convertPrice] rebuilds as soon as the user changes the
/// currency in Profile → Preferences → Currency, without restarting the app.
class CurrencyScope extends InheritedNotifier<CurrencyService> {
  CurrencyScope({super.key, required super.child})
      : super(notifier: CurrencyService.instance);

  static CurrencyService of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CurrencyScope>()?.notifier ??
      CurrencyService.instance;
}

/// The user's display currency (ISO code), read from their profile setting.
/// Falls back to the app default defined in [CurrencyService.supported].
String userCurrencyCode(BuildContext context) =>
    CurrencyScope.of(context).selected.code;

/// Converts [amount] from [from] (the currency the API returned it in) to the
/// user's currency. Returns null when no exchange rate is available, so
/// callers never show a converted-looking number that was not converted.
double? convertPrice(
  BuildContext context,
  double amount, {
  String from = 'USD',
}) =>
    CurrencyScope.of(context).convertFrom(amount, from);

/// The single price formatter for the UI.
///
/// Converts [amount] from [from] to the user's profile currency using the
/// app's exchange-rate service and formats it with that currency's symbol and
/// ISO minor units (LYD = 3 decimals, EUR/USD = 2). If no rate is available
/// the amount is shown unconverted, labelled with its own currency.
String formatPrice(
  BuildContext context,
  double amount, {
  String from = 'USD',
}) {
  final service = CurrencyScope.of(context);
  final locale = Localizations.maybeLocaleOf(context)?.languageCode ?? 'en';
  final converted = service.convertFrom(amount, from);
  if (converted == null) {
    return formatCurrencyAmount(amount, from, locale: locale);
  }
  return formatCurrencyAmount(converted, service.selected.code, locale: locale);
}
