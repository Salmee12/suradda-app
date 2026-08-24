import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/audio/playback_service.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../viewmodels/library_viewmodel.dart';
import '../../viewmodels/online_room_viewmodel.dart';

enum SearchFilter { title, artist }

class CloudSongsTab extends StatefulWidget {
  const CloudSongsTab({super.key});

  @override
  State<CloudSongsTab> createState() => _CloudSongsTabState();
}

class _CloudSongsTabState extends State<CloudSongsTab> {
  final TextEditingController _searchController = TextEditingController();
  SearchFilter _selectedFilter = SearchFilter.title;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadCloudSongs();
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryVM = context.watch<LibraryViewModel>();

    if (libraryVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (libraryVM.errorMessage != null) {
      return Center(child: Text(libraryVM.errorMessage!));
    }

    if (libraryVM.cloudSongs.isEmpty) {
      return const Center(child: Text('No songs available yet.'));
    }

    // In-memory filtering
    final filteredSongs = libraryVM.cloudSongs.where((song) {
      if (_searchQuery.isEmpty) return true;
      if (_selectedFilter == SearchFilter.title) {
        return song.songName.toLowerCase().contains(_searchQuery);
      } else {
        return song.artist.toLowerCase().contains(_searchQuery);
      }
    }).toList();

    return Column(
      children: [
        // Search & Filter Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: _selectedFilter == SearchFilter.title
                      ? 'Search by title...'
                      : 'Search by artist...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                    },
                  )
                      : null,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Search by: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Title'),
                    selected: _selectedFilter == SearchFilter.title,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = SearchFilter.title);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Artist'),
                    selected: _selectedFilter == SearchFilter.artist,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedFilter = SearchFilter.artist);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Songs List View
        Expanded(
          child: filteredSongs.isEmpty
              ? const Center(child: Text('No matching songs found.'))
              : ListView.builder(
            itemCount: filteredSongs.length,
            itemBuilder: (context, index) {
              final song = filteredSongs[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnailUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.music_note),
                  ),
                ),
                title: Text(song.songName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () async {
                  final roomVM = context.read<OnlineRoomViewModel>();
                  final hotspotVM = context.read<HotspotRoomViewModel>();
                  final playback = context.read<PlaybackService>();

                  if (hotspotVM.isHost || hotspotVM.isClient) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cloud songs aren\'t available in a Hotspot party')),
                    );
                    return;
                  }

                  if (roomVM.room != null) {
                    if (roomVM.isHost) {
                      await playback.player.pause();
                      if (playback.player.playing) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tap again to change the song')),
                        );
                      } else {
                        roomVM.hostPlaySong(song, queue: filteredSongs);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Only the host can choose songs during a party')),
                      );
                    }
                  } else {
                    libraryVM.playSong(song);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}