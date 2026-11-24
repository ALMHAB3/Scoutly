import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/money_format.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_method_option.dart';
import 'ui/ui.dart';

/// "How would you like to pay?": lists the payment methods the payment
/// gateway offers (cards, digital wallets, other) and returns the chosen one.
/// Shown by [PaymentCheckoutScreen.start] only when the server reports real
/// payment methods; returns null when the customer goes back.
class PaymentMethodScreen extends StatefulWidget {
  final List<PaymentMethodOption> methods;
  final double amount;
  final String currencyCode;
  final String description;

  /// Optional progress header shown next to the back button (e.g. the taxi
  /// booking steps).
  final Widget? header;

  /// Optional summary card of what is being paid for; defaults to the
  /// description and the amount.
  final Widget? summary;

  const PaymentMethodScreen({
    super.key,
    required this.methods,
    required this.amount,
    required this.currencyCode,
    required this.description,
    this.header,
    this.summary,
  });

  static Future<PaymentMethodOption?> choose(
    BuildContext context, {
    required List<PaymentMethodOption> methods,
    required double amount,
    required String currencyCode,
    required String description,
    Widget? header,
    Widget? summary,
  }) =>
      Navigator.push<PaymentMethodOption>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentMethodScreen(
            methods: methods,
            amount: amount,
            currencyCode: currencyCode,
            description: description,
            header: header,
            summary: summary,
          ),
        ),
      );

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  late PaymentMethodOption _selected = widget.methods.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ar = l10n.localeName.startsWith('ar');
    final amountText = formatBookingCurrencyAmount(
      widget.amount,
      widget.currencyCode,
      locale: Localizations.localeOf(context).languageCode,
    );
    final groups = <(PaymentMethodGroup, String)>[
      (PaymentMethodGroup.cards, l10n.payGroupCards),
      (PaymentMethodGroup.wallets, l10n.payGroupWallets),
      (PaymentMethodGroup.other, l10n.payGroupOther),
    ];
    return Scaffold(
      backgroundColor: context.uiPageBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  AppIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip:
                        MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: widget.header ?? const SizedBox()),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                children: [
                  Text(
                    l10n.payHowTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: context.uiInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.paySubtitle,
                    style: TextStyle(fontSize: 13.5, color: context.uiMuted),
                  ),
                  const SizedBox(height: 18),
                  widget.summary ??
                      AppCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: context.uiInk,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              amountText,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  for (final (group, title) in groups)
                    if (widget.methods.any((m) => m.group == group)) ...[
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.fromSTEB(4, 22, 4, 10),
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: ar ? 0 : 1,
                            fontWeight: FontWeight.w700,
                            color: context.uiMuted,
                          ),
                        ),
                      ),
                      for (final method
                          in widget.methods.where((m) => m.group == group))
                        _MethodTile(
                          method: method,
                          arabic: ar,
                          selected: method.id == _selected.id,
                          onTap: () => setState(() => _selected = method),
                        ),
                    ],
                ],
              ),
            ),
            _PayBar(
              label: l10n.payPayingWith,
              method: _selected,
              arabic: ar,
              continueLabel: l10n.payContinue,
              onContinue: () => Navigator.pop(context, _selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodLogo extends StatelessWidget {
  final PaymentMethodOption method;
  const _MethodLogo(this.method);

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(method.icon, color: AppColors.primary, size: 22),
      );
}

class _MethodTile extends StatelessWidget {
  final PaymentMethodOption method;
  final bool arabic;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.method,
    required this.arabic,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderColor: selected ? AppColors.primary : null,
          onTap: onTap,
          child: Row(
            children: [
              _MethodLogo(method),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name(arabic),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: context.uiInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method.detail(arabic),
                      style: TextStyle(fontSize: 12, color: context.uiMuted),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.primary : context.uiBorder,
              ),
            ],
          ),
        ),
      );
}

class _PayBar extends StatelessWidget {
  final String label;
  final PaymentMethodOption method;
  final bool arabic;
  final String continueLabel;
  final VoidCallback onContinue;

  const _PayBar({
    required this.label,
    required this.method,
    required this.arabic,
    required this.continueLabel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: context.uiSurface,
          border: Border(top: BorderSide(color: context.uiBorder)),
        ),
        child: Row(
          children: [
            _MethodLogo(method),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(fontSize: 11.5, color: context.uiMuted)),
                  Text(
                    method.name(arabic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.uiInk,
                    ),
                  ),
                ],
              ),
            ),
            AppButton(
              key: const ValueKey('payment-method-continue'),
              onPressed: onContinue,
              expand: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(continueLabel),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ],
        ),
      );
}
