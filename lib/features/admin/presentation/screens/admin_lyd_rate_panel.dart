import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/currency_rates.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../global_widgets/app_snackbar.dart';

/// Admin control for the USD -> LYD reference rate used to show prices in
/// Libyan dinars across the app (the rate provider has no LYD).
class AdminLydRatePanel extends StatefulWidget {
  const AdminLydRatePanel({super.key});

  @override
  State<AdminLydRatePanel> createState() => _AdminLydRatePanelState();
}

class _AdminLydRatePanelState extends State<AdminLydRatePanel> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  bool get _ar => Localizations.localeOf(context).languageCode == 'ar';

  @override
  void initState() {
    super.initState();
    _controller.text = _format(LydRate.unitsPerUsd);
    // Show the stored value even if this device has not refreshed yet.
    CurrencyService.instance.refreshLydRate().then((_) {
      if (mounted && !_saving) {
        setState(() => _controller.text = _format(LydRate.unitsPerUsd));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String _format(double value) {
    final text = value.toStringAsFixed(4);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String? _validate(String? value) {
    final rate = double.tryParse((value ?? '').trim());
    if (rate == null || rate < 0.1 || rate > 1000) {
      return _ar
          ? 'أدخل سعرًا بين 0.1 و 1000'
          : 'Enter a rate between 0.1 and 1000';
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final rate = double.parse(_controller.text.trim());
    setState(() => _saving = true);
    final result = await ApiService.instance.updateLydRate(rate);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result.isFailure || result.data == null) {
      AppSnackbar.error(
        context,
        result.errorMessage ??
            (_ar ? 'تعذّر حفظ سعر الصرف' : 'Could not save the exchange rate'),
      );
      return;
    }
    await CurrencyService.instance.refreshLydRate();
    if (!mounted) return;
    _controller.text = _format(result.data!);
    AppSnackbar.success(
      context,
      _ar ? 'تم تحديث سعر الدينار' : 'Dinar exchange rate updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      key: const ValueKey('admin-lyd-rate'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ar ? 'سعر صرف الدينار الليبي' : 'Libyan dinar exchange rate',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _ar
                  ? 'يُستخدم لعرض الأسعار بالدينار في كل التطبيق. لا يغيّر أسعار المزوّدين الأصلية.'
                  : 'Used to show prices in dinars across the app. Provider prices are not changed.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text('1 USD =',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _controller,
                    enabled: !_saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: _validate,
                    decoration: InputDecoration(
                      suffixText: 'LYD',
                      labelText: _ar ? 'السعر' : 'Rate',
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_ar ? 'حفظ' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
