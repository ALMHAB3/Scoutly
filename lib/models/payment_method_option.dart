import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Section a payment method is listed under on "How would you like to pay?".
enum PaymentMethodGroup { cards, wallets, other }

/// A payment method the connected payment gateway really offers (the server
/// lists them from its configuration; nothing here is invented client-side).
class PaymentMethodOption {
  final String id;
  final PaymentMethodGroup group;

  const PaymentMethodOption({required this.id, required this.group});

  static PaymentMethodOption? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim().toLowerCase();
    if (!_names.containsKey(id)) return null;
    final group = switch ((json['group'] ?? '').toString()) {
      'wallets' => PaymentMethodGroup.wallets,
      'other' => PaymentMethodGroup.other,
      _ => PaymentMethodGroup.cards,
    };
    return PaymentMethodOption(id: id, group: group);
  }

  /// Apple Pay / Google Pay only work on their own platform's app.
  bool get supportedOnThisDevice => switch (id) {
        'apple_pay' => !kIsWeb &&
            (defaultTargetPlatform == TargetPlatform.iOS ||
                defaultTargetPlatform == TargetPlatform.macOS),
        'google_pay' =>
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        _ => true,
      };

  IconData get icon => switch (id) {
        'card' => Icons.credit_card_rounded,
        'tadawul' => Icons.account_balance_rounded,
        'apple_pay' => Icons.apple,
        'google_pay' => Icons.g_mobiledata_rounded,
        'paypal' => Icons.paypal,
        _ => Icons.phone_iphone_rounded,
      };

  String name(bool arabic) => _names[id]!.$1.pick(arabic);
  String detail(bool arabic) => _names[id]!.$2.pick(arabic);

  static const _names = <String, ((String, String), (String, String))>{
    'card': (
      ('Bank card', 'بطاقة مصرفية'),
      ('Visa, Mastercard', 'فيزا، ماستركارد')
    ),
    'tadawul': (
      ('Tadawul card', 'بطاقة تداول'),
      ('Local bank card', 'بطاقة مصرفية محلية')
    ),
    'apple_pay': (
      ('Apple Pay', 'Apple Pay'),
      ('Confirm with Face ID', 'التأكيد ببصمة الوجه')
    ),
    'google_pay': (
      ('Google Pay', 'Google Pay'),
      ('Pay with your Google account', 'الدفع بحساب Google')
    ),
    'paypal': (
      ('PayPal', 'PayPal'),
      ('Pay with your PayPal account', 'الدفع بحساب PayPal')
    ),
    'sadad': (('Sadad', 'سداد'), ('Libyana mobile wallet', 'محفظة ليبيانا')),
    'mobicash': (('MobiCash', 'موبي كاش'), ('Mobile wallet', 'محفظة الهاتف')),
    'edfaali': (('Edfaali', 'ادفع لي'), ('Mobile wallet', 'محفظة الهاتف')),
  };
}

extension on (String, String) {
  String pick(bool arabic) => arabic ? $2 : $1;
}
