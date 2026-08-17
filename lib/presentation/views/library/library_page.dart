import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            title: const Text('Music Library'),
            bottom: const TabBar(
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