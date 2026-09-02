import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/root_navigation.dart';
import '../../viewmodels/library_viewmodel.dart';
import '../../../di/locator.dart';
import 'cloud_songs_tab.dart';
import 'local_songs_tab.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LibraryViewModel>(
      create: (_) => locator<LibraryViewModel>(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 20,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: RootNavigation.of(context).openDrawer,
            ),
            title: const Text(
              'Your Library',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
            ),
            bottom: const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(text: 'Cloud'),
                Tab(text: 'Local'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              CloudSongsTab(),
              LocalSongsTab(),
            ],
          ),
        ),
      ),
    );
  }
}