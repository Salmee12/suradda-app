import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../viewmodels/auth_viewmodel.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  /// Cancelling billing is irreversible from inside the app — the user has to go
  /// through the whole subscribe flow again — so it asks first.
  Future<void> _confirmUnsubscribe() async {
    final vm = context.read<AuthViewModel>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('Cancel subscription?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Your daily charge stops and you are signed out straight away. '
          'Nothing on your phone is deleted, but the app stays locked until '
          'you subscribe again.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unsubscribe',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await vm.unsubscribe();
    if (!mounted) return;

    // On success the view model flips to unauthenticated and AuthGate replaces
    // this whole subtree, so there is no drawer left to close. Only the failure
    // path has anything to say.
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ??
              'Could not cancel your subscription. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final user = vm.currentUser;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.card),
              accountName: Text(
                user?.username ?? 'SurAdda listener',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              accountEmail: Text(user?.phoneNumber ?? ''),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.black),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded,
                  color: AppColors.textSecondary),
              title: const Text('Sign out',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: const Text('Your subscription stays active',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
              onTap: vm.isLoading ? null : vm.logout,
            ),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
              title: const Text('Unsubscribe',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
              subtitle: const Text('Stops the daily charge',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 11.5)),
              trailing: vm.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.textSecondary),
                    )
                  : null,
              onTap: vm.isLoading ? null : _confirmUnsubscribe,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
