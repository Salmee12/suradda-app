import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadCloudSongs();
    });
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

    return ListView.builder(
      itemCount: libraryVM.cloudSongs.length,
      itemBuilder: (context, index) {
        final song = libraryVM.cloudSongs[index];
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
                  await playback.player.playing ?
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tap again to change the song')),
                    )
                      : roomVM.hostPlaySong(song, queue: libraryVM.cloudSongs);



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
    );
  }
}