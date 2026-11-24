import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_method_option.dart';
import 'ui/ui.dart';

/// "Payment Method" card on the booking screens. Without gateway payment
/// methods it shows the hosted bank-card page; when the server offers real
/// methods it lists them (the customer picks one on the next step).
class PaymentMethodsCard extends StatefulWidget {
  final String title;
  final String cardTitle;
  final String cardNote;
  final String secureNote;

  /// Loads the methods; tests can pass a fake.
  final Future<List<PaymentMethodOption>> Function()? loader;

  const PaymentMethodsCard({
    super.key,
    required this.title,
    required this.cardTitle,
    required this.cardNote,
    required this.secureNote,
    this.loader,
  });

  @override
  State<PaymentMethodsCard> createState() => _PaymentMethodsCardState();
}

class _PaymentMethodsCardState extends State<PaymentMethodsCard> {
  late final Future<List<PaymentMethodOption>> _methods =
      (widget.loader ?? ApiService.instance.getPaymentMethods)();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ar = l10n.localeName.startsWith('ar');
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.uiInk,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<PaymentMethodOption>>(
            future: _methods,
            builder: (context, snapshot) {
              final methods = snapshot.data ?? const [];
              if (methods.isEmpty) {
                return _row(
                  context,
                  icon: Icons.credit_card_rounded,
                  title: widget.cardTitle,
                  note: widget.cardNote,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final method in methods)
                        AppPill(icon: method.icon, text: method.name(ar)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.payChooseNextStep,
                    style: TextStyle(fontSize: 11.5, color: context.uiMuted),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 14, color: context.uiMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.secureNote,
                  style: TextStyle(fontSize: 11, color: context.uiMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String note,
  }) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppColors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.uiInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note,
                  style: TextStyle(fontSize: 11.5, color: context.uiMuted),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.radio_button_checked_rounded,
            color: AppColors.primary,
          ),
        ],
      );
}
