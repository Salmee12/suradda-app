import 'package:flutter/material.dart';
import '../library/library_page.dart';
import '../room/room_home_page.dart';
import '../radio/radio_page.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/music_slab.dart';
import '../../widgets/app_drawer.dart';
import '../../../core/navigation/root_navigation.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  /// Instance-scoped, NOT a top-level global: two RootShells coexisting would
  /// otherwise both claim the same key and trip Flutter's duplicate-GlobalKey
  /// assertion.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  final _pages = const [
    LibraryPage(),
    RoomHomePage(),
    RadioPage(), // CHANGED — was DashboardPage()
  ];

  // A tear-off of an instance method compares equal across rebuilds, so
  // RootNavigation.updateShouldNotify stays false and pages don't rebuild on
  // every tab change.
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      // The drawer lives on this Scaffold so it covers the nav bar and slab too;
      // the pages reach it through RootNavigation.
      body: RootNavigation(
        openDrawer: _openDrawer,
        child: _pages[_index],
      ),
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
