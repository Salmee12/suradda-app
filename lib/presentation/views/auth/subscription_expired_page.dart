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
                      'deleted — renewing brings everything back.',
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
                      // Subscribing again means running the telco flow for this
                      // number, which lives on the phone screen. Signing out is
                      // what gets there — AuthGate swaps the screen itself.
                      onPressed: vm.isLoading ? null : vm.logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Subscribe again',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      // For a subscription renewed by SMS or USSD: the server
                      // only re-checks every few hours, so this is the manual
                      // nudge that avoids making the user wait it out.
                      onPressed: vm.isLoading ? null : vm.refreshUser,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.card, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: vm.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.textSecondary),
                            )
                          : const Text('I already renewed — check again',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
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
