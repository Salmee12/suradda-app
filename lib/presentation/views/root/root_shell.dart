import 'package:flutter/material.dart';
import '../library/library_page.dart';
import '../room/room_home_page.dart';
import '../radio/radio_page.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/music_slab.dart';
import '../../widgets/app_drawer.dart';
import '../../../core/navigation/app_scaffold_key.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  final _pages = const [
    LibraryPage(),
    RoomHomePage(),
    RadioPage(), // CHANGED — was DashboardPage()
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: rootScaffoldKey, // NEW
      drawer: const AppDrawer(), // NEW
      body: _pages[_index],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MusicSlab(),
          AppBottomNavBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
          ),
        ],
      ),
    );
  }
}