import '../../../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/auth_fonts.dart'
    as GoogleFonts; // ignore: library_prefixes

import '../../../../core/services/api_service.dart';
import '../../../../routes/app_routes.dart';
import '../../logic/auth_controller.dart';
import 'auth_shared.dart' show AuthScaffold, GoogleG;
import '../../../../core/constants/app_colors.dart';
import '../../../../global_widgets/ui/ui.dart';

// ───────────────────────── Colors ─────────────────────────

// ───────────────────────── Screen ─────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;

  @override
  void dispose() {
    _auth.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage(AppLocalizations.of(context).authInvalidEmail);
      return;
    }
    if (_passCtrl.text.isEmpty) {
      _showMessage(AppLocalizations.of(context).authPasswordHint);
      return;
    }

    setState(() => _loading = true);
    final success = await _auth.login(email: email, password: _passCtrl.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      _continueToApp();
    } else {
      final error = _auth.errorMessage;
      if (error != null && error.isNotEmpty) _showMessage(error);
    }
  }

  Future<void> _socialLogin({required bool withApple}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final success = withApple
        ? await _auth.loginWithApple()
        : await _auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (success) {
      _continueToApp();
    } else {
      final error = _auth.errorMessage;
      if (error != null && error.isNotEmpty) _showMessage(error);
    }
  }

  void _continueToApp() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.splash,
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroFraction: 0.28,
      showBack: false,
      child: _buildForm(),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Text(
          AppLocalizations.of(context).loginTitleLine1,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.authText,
            height: 1.2,
          ),
        ),
        Text(
          AppLocalizations.of(context).loginTitleLine2,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.authNavy,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 22),

        _InputField(
          controller: _emailCtrl,
          hint: AppLocalizations.of(context).authEmailHint,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _InputField(
          controller: _passCtrl,
          hint: AppLocalizations.of(context).authPasswordHint,
          icon: Icons.lock_outline_rounded,
          obscure: _obscure,
          suffix: IconButton(
            splashRadius: 20,
            icon: Icon(
              _obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: AppColors.authHint,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
        const SizedBox(height: 10),

        // Remember me / Forgot password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _remember,
                      activeColor: AppColors.authNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      onChanged: (v) => setState(() => _remember = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).rememberMe,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.authText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: _loading
                    ? null
                    : () => Navigator.of(context)
                        .pushNamed(AppRoutes.forgotPassword),
                child: Text(
                  AppLocalizations.of(context).forgotPasswordLink,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.authNavy,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        AppButton.label(
          text: AppLocalizations.of(context).loginButton,
          loading: _loading,
          onPressed: _submitLogin,
        ),
        if (ApiService.socialAuthConfigured) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.authLine)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  AppLocalizations.of(context).orSignUpWith,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.authHint,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.authLine)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton.icon(
                  label: Text('Google'),
                  icon: const GoogleG(),
                  onPressed: () => _socialLogin(withApple: false),
                  variant: AppButtonVariant.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.icon(
                  label: Text('Apple'),
                  icon:
                      const Icon(Icons.apple, size: 22, color: AppColors.black),
                  onPressed: () => _socialLogin(withApple: true),
                  variant: AppButtonVariant.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],

        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _loading
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.register),
          child: Text.rich(
            TextSpan(
              text: AppLocalizations.of(context).noAccountPrompt,
              style:
                  GoogleFonts.poppins(fontSize: 12, color: AppColors.authText),
              children: [
                TextSpan(
                  text: AppLocalizations.of(context).createAnAccount,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.authNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Components ─────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 14, color: AppColors.authText),
      cursorColor: AppColors.authNavy,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: AppColors.authHint),
        prefixIcon: Icon(icon, size: 20, color: AppColors.authHint),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.authFieldBackground,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.authNavy, width: 1.4),
        ),
      ),
    );
  }
}
