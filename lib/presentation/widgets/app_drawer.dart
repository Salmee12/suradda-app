import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: AppColors.card),
              accountName: Text(
                'User Profile',
                style: TextStyle(fontWeight: FontWeight.w700),
              ), // placeholder — wire up later
              accountEmail: Text(''),
              currentAccountPicture: CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.black),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
              title: const Text('Unsubscribe',
                  style: TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w600)),
              onTap: () {
                // placeholder — wire up bdapps check_subscription/unsubscribe later
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
