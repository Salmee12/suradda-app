import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Rooms'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Dashboard'),
      ],
    );
  }
}