import 'package:flutter/material.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            const UserAccountsDrawerHeader(
              accountName: Text('User Profile'), // placeholder — wire up later
              accountEmail: Text(''),
              currentAccountPicture: CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel_outlined, color: Colors.red),
              title: const Text('Unsubscribe', style: TextStyle(color: Colors.red)),
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