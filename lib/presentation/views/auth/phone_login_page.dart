import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/bd_phone.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'otp_verify_page.dart';

/// Entry point for the whole app: the number is the identity, so this replaces
/// the old username/password login.
class PhoneLoginPage extends StatefulWidget {
  const PhoneLoginPage({super.key});

  @override
  State<PhoneLoginPage> createState() => _PhoneLoginPageState();
}

class _PhoneLoginPageState extends State<PhoneLoginPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _localError;

  @override
  void initState() {
    super.initState();
    // Drives the operator selection and enables the button without a Form.
    _controller.addListener(() => setState(() {}));
    // The field's outline reacts to focus, so a focus change repaints it.
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Tapping an operator writes its prefix into the field rather than storing a
  /// separate choice.
  ///
  /// The prefix already decides the operator, so a second piece of state could
  /// only ever contradict the number — "you picked Robi but typed an 016
  /// number" is a dead end for the user. The field stays the only source of
  /// truth: the two buttons read their selected state from it, and tapping one
  /// edits it.
  void _pickOperator(BdOperator op) {
    final digits = BdPhone.digitsOnly(_controller.text);
    // Keep anything already typed past the prefix, so switching operator does
    // not mean retyping the whole number.
    final rest = digits.length > 3 ? digits.substring(3) : '';
    final next = '${op.prefix}$rest';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _focus.requestFocus();
  }

  Future<void> _submit() async {
    final raw = _controller.text;
    final problem = BdPhone.validate(raw);
    if (problem != null) {
      setState(() => _localError = problem);
      return;
    }
    setState(() => _localError = null);
    FocusScope.of(context).unfocus();

    final vm = context.read<AuthViewModel>();
    final needsOtp = await vm.submitPhoneNumber(BdPhone.toE164(raw));
    if (!mounted) return;

    if (needsOtp) {
      // A direct sign-in returns false and AuthGate swaps in the shell on its
      // own, so this push only happens when there is actually a code to enter.
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OtpVerifyPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final selected = BdPhone.operatorOf(_controller.text);
    final error = _localError ?? vm.errorMessage;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _TaglinePill()),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome to SurAdda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your mobile number to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'MOBILE NUMBER',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _PhoneField(
                    controller: _controller,
                    focusNode: _focus,
                    enabled: !vm.isLoading,
                    onSubmitted: vm.isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 14),
                  const _ChargeNotice(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (final op in BdOperator.values) ...[
                        if (op != BdOperator.values.first)
                          const SizedBox(width: 12),
                        Expanded(
                          child: _OperatorButton(
                            operator: op,
                            selected: selected == op,
                            onTap:
                                vm.isLoading ? null : () => _pickOperator(op),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12.5, height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _ContinueButton(
                    isLoading: vm.isLoading,
                    onPressed: vm.isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No card needed. Cancel anytime.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'By continuing you agree to be charged the daily '
                    'subscription fee until you cancel.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The badge above the heading.
///
/// Deliberately not the mock's "Free to join": the next tap starts a daily
/// charge, and BDApps requires that charge to be disclosed rather than
/// contradicted two lines above the disclosure.
class _TaglinePill extends StatelessWidget {
  const _TaglinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
          SizedBox(width: 6),
          Text(
            'Listen together, anywhere',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Flag, `+88`, hairline, then the eleven local digits.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.10),
          width: focused ? 2 : 1.5,
        ),
      ),
      child: Row(
        children: [
          const _BdFlag(),
          const SizedBox(width: 10),
          const Text('+88',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Container(
              width: 1, height: 20, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              // The number keyboard still offers '+', spaces and dashes on some
              // Android IMEs, which would only surface later as a format error.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5),
              // The pill around this row draws the fill and the outline, so the
              // theme's own filled/outlined defaults have to be switched off or
              // they paint a second rounded box inside it. Clearing `border`
              // alone is not enough — enabledBorder and focusedBorder come from
              // the theme and outrank it.
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                hintText: '01XXXXXXXXX',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0),
              ),
              onSubmitted: (_) => onSubmitted?.call(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two shapes, so the flag is drawn rather than added as an asset or a new
/// SVG dependency.
class _BdFlag extends StatelessWidget {
  const _BdFlag();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 16,
      decoration: BoxDecoration(
        color: const Color(0xFF006A4E),
        borderRadius: BorderRadius.circular(2),
      ),
      // The disc sits left of centre on the flag itself, not dead centre.
      child: Align(
        alignment: const Alignment(-0.13, 0),
        child: Container(
          width: 9.6,
          height: 9.6,
          decoration: const BoxDecoration(
            color: Color(0xFFF42A41),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// BDApps requires the charge to be disclosed before the user subscribes.
class _ChargeNotice extends StatelessWidget {
  const _ChargeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoDot(),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Daily charge ৳2.78 (incl. VAT + SD + SC) — only for Robi and '
              'Cirkle customers.',
              style: TextStyle(
                  fontSize: 12, height: 1.45, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoDot extends StatelessWidget {
  const _InfoDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          color: AppColors.primary, shape: BoxShape.circle),
      child: const Text('i',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black)),
    );
  }
}

/// One of the two billable operators. Selection is derived from the number, so
/// this is a shortcut for filling in the prefix, not a separate answer.
class _OperatorButton extends StatelessWidget {
  const _OperatorButton({
    required this.operator,
    required this.selected,
    required this.onTap,
  });

  final BdOperator operator;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 46,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.12),
            width: 2,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check,
                        size: 11,
                        color: selected
                            ? Colors.black
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    operator.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    operator.prefix,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.greenBright],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.black),
                    )
                  : const Text('Continue  →',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.black)),
            ),
          ),
        ),
      ),
    );
  }
}
