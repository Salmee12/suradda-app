import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../viewmodels/auth_viewmodel.dart';

/// Shown when the tokens are valid but the telco subscription is not active.
///
/// This exists so a lapsed subscriber is not dumped back at the phone screen
/// with no explanation. [AuthGate] routes the whole app here rather than gating
/// individual features, so this screen is the entire surface until the
/// subscription is active again. The session is kept alive so /auth/me still
/// works and the number can be shown; the backend also 403s the paid routes
/// independently, which is what would make per-feature gating possible later.
class SubscriptionExpiredPage extends StatelessWidget {
  const SubscriptionExpiredPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final phone = vm.currentUser?.phoneNumber ?? vm.phoneNumber;

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
                  const Icon(Icons.lock_clock_rounded,
                      size: 56, color: AppColors.primary),
                  const SizedBox(height: 20),
                  const Text(
                    'Your subscription is not active',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    phone == null
                        ? 'Renew your subscription to keep listening together.'
                        : 'Renew the subscription on $phone to keep listening '
                            'together.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Rooms, the shared library, radio and local playback all '
                      'sit behind the subscription, so the app stays locked '
                      'until it is active again. Nothing on your phone is '
                      'deleted — renewing brings everything back.\n\n'
                      'Already topped up or renewed? Tap below and confirm your '
                      'number. You will not be charged a second time.',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  if (vm.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(vm.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      // Labelled as a check, implemented as a sign-out. The
                      // phone screen is the only place that asks the telco
                      // live, and reaching it means clearing the session —
                      // AuthGate swaps the screen itself. A number that is
                      // paying again is signed straight back in from there with
                      // no OTP and no second charge, so "check" is honest about
                      // what the user experiences.
                      //
                      // This used to read "Subscribe again", which nobody who
                      // had just topped up would willingly press. Sitting below
                      // it was an "I already renewed — check again" button
                      // wired to refreshUser(); that only re-read /auth/me,
                      // whose verdict cannot change until the server's 12-hour
                      // re-check falls due — and arriving on this screen resets
                      // that clock. So the trustworthy-looking button did
                      // nothing for up to half a day while the alarming one was
                      // the working escape hatch. Removed rather than fixed:
                      // making it real needs a server route that re-checks on
                      // demand.
                      onPressed: vm.isLoading ? null : vm.logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Check my subscription',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
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
