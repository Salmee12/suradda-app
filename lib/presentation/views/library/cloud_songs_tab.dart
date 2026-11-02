import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/song_repository.dart';
import '../../../services/audio/playback_service.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../viewmodels/library_viewmodel.dart';
import '../../viewmodels/online_room_viewmodel.dart';

class CloudSongsTab extends StatefulWidget {
  const CloudSongsTab({super.key});

  @override
  State<CloudSongsTab> createState() => _CloudSongsTabState();
}

class _CloudSongsTabState extends State<CloudSongsTab> {
  final TextEditingController _searchController = TextEditingController();

  /// Mirrors the controller so the clear button and the searching spinner
  /// appear and disappear on the same frame as the text changes. The view model
  /// notifies too, but a keystroke that only fills the field is not a state
  /// change there, so its notify never fires for it.
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadCloudSongs();
    });
  }

  /// Hands the raw text to the view model, which owns the debounce and the
  /// request. Nothing is filtered here any more — the results on screen are
  /// whatever the server returned for this term.
  void _onSearchChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
    context.read<LibraryViewModel>().setSearchQuery(_searchController.text);
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

    // Only a first load blanks the tab. Searches keep the previous results
    // visible underneath, so typing never flashes an empty screen.
    if (libraryVM.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (libraryVM.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(libraryVM.errorMessage!),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: libraryVM.loadCloudSongs,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final songs = libraryVM.cloudSongs;

    return Column(
      children: [
        // Search & Filter Section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: libraryVM.searchField == SongSearchField.artist
                      ? 'Search by artist...'
                      : 'Search by title...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: libraryVM.isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _hasText
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _searchController.clear,
                            )
                          : null,
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Search by: ',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ChoiceChip(
                    label: const Text('Title'),
                    selected: libraryVM.searchField == SongSearchField.title,
                    onSelected: (selected) {
                      if (selected) {
                        libraryVM.setSearchField(SongSearchField.title);
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Artist'),
                    selected: libraryVM.searchField == SongSearchField.artist,
                    onSelected: (selected) {
                      if (selected) {
                        libraryVM.setSearchField(SongSearchField.artist);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // A failed search is reported in place, above whatever is still
        // listed, rather than replacing the list with an error page.
        if (libraryVM.searchError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    libraryVM.searchError!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12.5),
                  ),
                ),
                TextButton(
                  onPressed: libraryVM.retrySearch,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

        // Songs List View
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      libraryVM.isSearchActive
                          ? 'No songs match "${libraryVM.searchQuery}".'
                          : 'No songs available yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: song.thumbnailUrl,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox(
                            width: 52,
                            height: 52,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 52,
                            height: 52,
                            color: AppColors.card,
                            child: const Icon(Icons.music_note,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      title: Text(song.songName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      trailing: SizedBox(
                        width: 40,
                        child: libraryVM.isDownloading(song.id)
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  libraryVM.isDownloaded(song.id)
                                      ? Icons.download_done
                                      : Icons.download_outlined,
                                  color: libraryVM.isDownloaded(song.id)
                                      ? AppColors.primary
                                      : null,
                                ),
                                tooltip: libraryVM.isDownloaded(song.id)
                                    ? 'Downloaded'
                                    : 'Download to device',
                                onPressed: libraryVM.isDownloaded(song.id)
                                    ? null
                                    : () async {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final result = await libraryVM
                                            .downloadSong(song);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            duration: Duration(
                                                seconds:
                                                    result.success ? 2 : 6),
                                            content: Text(result.success
                                                ? 'Downloaded to your Local library'
                                                : 'Download failed: ${result.error ?? 'unknown error'}'),
                                          ),
                                        );
                                      },
                              ),
                      ),
                      onTap: () async {
                        // Captured before any await: the tile can be disposed
                        // while player.pause() is in flight, and
                        // ScaffoldMessenger.of() would then throw on a
                        // deactivated context.
                        final messenger = ScaffoldMessenger.of(context);
                        final roomVM = context.read<OnlineRoomViewModel>();
                        final hotspotVM = context.read<HotspotRoomViewModel>();
                        final playback = context.read<PlaybackService>();

                        if (hotspotVM.isHost || hotspotVM.isClient) {
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Cloud songs aren\'t available in a Hotspot party')),
                          );
                          return;
                        }

                        if (roomVM.room != null) {
                          if (roomVM.isHost) {
                            await playback.player.pause();
                            if (playback.player.playing) {
                              messenger.showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Tap again to change the song')),
                              );
                            } else {
                              roomVM.hostPlaySong(song, queue: songs);
                            }
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Only the host can choose songs during a party')),
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
