import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Second half of the OTP flow.
///
/// The display name is collected here rather than on a screen after sign-in, so
/// it travels with the verify call and the user row is complete on first insert.
/// There is deliberately no point at which an authenticated user has no name.
class OtpVerifyPage extends StatefulWidget {
  const OtpVerifyPage({super.key});

  @override
  State<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends State<OtpVerifyPage> {
  /// BDApps sends six digits. The boxes, the input formatter and the
  /// auto-submit all read this, so a different length is a one-line change.
  static const _digitCount = 6;

  // One controller for the whole code rather than one per box: the boxes are a
  // painted view of this single string. Paste and SMS autofill arrive as one
  // insertion and land intact, and there is no per-box focus shuffling to make
  // backspace behave oddly.
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _otpFocus = FocusNode();
  final _nameFocus = FocusNode();

  String? _localError;
  bool _autoSubmitted = false;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    _nameController.addListener(() => setState(() {}));
    // The boxes highlight the active cell, so a focus change repaints them.
    _otpFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _nameController.dispose();
    _otpFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onOtpChanged() {
    setState(() {});
    final vm = context.read<AuthViewModel>();

    if (_otpController.text.length < _digitCount) {
      // Backspacing out of a complete code re-arms the auto-submit, so a
      // corrected code still submits itself.
      _autoSubmitted = false;
      return;
    }
    if (_autoSubmitted || vm.isLoading) return;
    _autoSubmitted = true;

    // A complete code but no name yet: send them to the name field instead of
    // failing a validation they have not had the chance to satisfy.
    if (vm.needsUsername && _nameController.text.trim().isEmpty) {
      _nameFocus.requestFocus();
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    final vm = context.read<AuthViewModel>();
    final code = _otpController.text;
    final name = _nameController.text.trim();

    if (code.length != _digitCount) {
      setState(() => _localError = 'Enter all $_digitCount digits of the code.');
      return;
    }
    if (vm.needsUsername && name.isEmpty) {
      setState(() => _localError = 'Enter a name so friends can recognise you.');
      return;
    }
    setState(() => _localError = null);
    FocusScope.of(context).unfocus();

    final ok = await vm.submitOtp(
      otp: code,
      username: vm.needsUsername ? name : null,
    );
    if (!mounted) return;

    // Either we are in (AuthGate is already showing the shell underneath), or
    // the code was spent without a session and the flow has been reset — both
    // mean this screen is done. The error, if any, is on the view model and the
    // phone screen renders it.
    if (ok || vm.tokenErrorOnLastVerify) {
      Navigator.of(context).pop();
      return;
    }

    // Rejected. Empty the boxes so the next attempt starts clean instead of
    // making the user backspace six times.
    _otpController.clear();
    _autoSubmitted = false;
    _otpFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final error = _localError ?? vm.errorMessage;
    final canSubmit = _otpController.text.length == _digitCount &&
        (!vm.needsUsername || _nameController.text.trim().isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: vm.isLoading
              ? null
              : () {
                  vm.restartOtpFlow();
                  Navigator.of(context).pop();
                },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _Badge()),
                  const SizedBox(height: 22),
                  const Text(
                    'Enter verification code',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a $_digitCount-digit code to '
                    '${vm.phoneNumber ?? 'your number'}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.5,
                        color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 26),
                  _codeCard(enabled: !vm.isLoading),
                  if (vm.needsUsername) ...[
                    const SizedBox(height: 22),
                    const Text(
                      'YOUR NAME',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _Field(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      enabled: !vm.isLoading,
                      hint: 'Shown to others in listening rooms',
                      onSubmitted: vm.isLoading ? null : _submit,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12.5,
                            height: 1.45)),
                  ],
                  const SizedBox(height: 24),
                  _verifyButton(vm, canSubmit),
                  if (vm.isLoading) ...[
                    const SizedBox(height: 16),
                    // Verifying can genuinely take a while: BDApps, then the
                    // token mint against a server that may be waking up. Saying
                    // so keeps the user from killing the app mid-flight and
                    // burning a code.
                    const Text(
                      'Verifying — this can take up to a minute. '
                      'Please keep the app open.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _digitBox(int index) {
    final code = _otpController.text;
    final filled = index < code.length;
    // The cell the next keystroke will land in, which is what stands in for the
    // caret the hidden field is not allowed to draw.
    final isActive = _otpFocus.hasFocus &&
        index == code.length &&
        code.length < _digitCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : filled
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.07),
          width: isActive ? 2 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Text(
        filled ? code[index] : '',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _verifyButton(AuthViewModel vm, bool canSubmit) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: (vm.isLoading || !canSubmit) ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        child: vm.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.black),
              )
            : const Text('Verify & continue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// The digit boxes, with one invisible field stacked over them that actually
  /// receives the keystrokes.
  Widget _codeCard({required bool enabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.06), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < _digitCount; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _digitBox(i)),
              ],
            ],
          ),
          Positioned.fill(
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocus,
              enabled: enabled,
              autofillHints: const [AutofillHints.oneTimeCode],
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_digitCount),
              ],
              // This field is the input; the boxes underneath are the picture of
              // it. Hiding the cursor and the selection handles is what keeps
              // the two from visibly disagreeing.
              showCursor: false,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 22),
              // The theme fills and outlines every field by default, which here
              // painted a rounded rectangle straight over the boxes below. Both
              // have to go, and every border variant has to be cleared rather
              // than just `border`: the theme's enabledBorder and focusedBorder
              // take precedence over it.
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              // A tap anywhere parks the caret at the end, so the next digit
              // appends instead of overwriting one in the middle.
              onTap: () => _otpController.selection =
                  TextSelection.collapsed(offset: _otpController.text.length),
              onSubmitted: enabled ? (_) => _submit() : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// The framed icon above the heading, so this step reads as part of the same
/// flow as the phone screen rather than a different app.
class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(Icons.sms_outlined, color: AppColors.primary, size: 30),
    );
  }
}

/// The display-name field. Only the name uses this now — the code has its own
/// boxed presentation — so it no longer takes styling parameters.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hint,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hint;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.name,
      textCapitalization: TextCapitalization.words,
      inputFormatters: [LengthLimitingTextInputFormatter(50)],
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill,
        hintText: hint,
        hintStyle: const TextStyle(
            color: AppColors.textSecondary, fontWeight: FontWeight.w400),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        // Spelled out because the theme sets its own enabledBorder at radius 8,
        // which would otherwise win and round these corners differently.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onSubmitted: (_) => onSubmitted?.call(),
    );
  }
}
