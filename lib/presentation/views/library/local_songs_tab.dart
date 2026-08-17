import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../viewmodels/library_viewmodel.dart';
import '../../viewmodels/online_room_viewmodel.dart';

class LocalSongsTab extends StatefulWidget {
  const LocalSongsTab({super.key});

  @override
  State<LocalSongsTab> createState() => _LocalSongsTabState();
}

class _LocalSongsTabState extends State<LocalSongsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryViewModel>().loadLocalSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryVM = context.watch<LibraryViewModel>();

    if (libraryVM.isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (libraryVM.localErrorMessage != null) {
      return Center(child: Text(libraryVM.localErrorMessage!));
    }
    if (libraryVM.localSongs.isEmpty) {
      return const Center(child: Text('No local songs found on this device.'));
    }

    return ListView.builder(
      itemCount: libraryVM.localSongs.length,
      itemBuilder: (context, index) {
        final song = libraryVM.localSongs[index];
        return ListTile(
          leading: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            nullArtworkWidget: const Icon(Icons.music_note),
            artworkFit: BoxFit.cover,
            artworkWidth: 48,
            artworkHeight: 48,
            artworkBorder: BorderRadius.circular(6),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            final roomVM = context.read<OnlineRoomViewModel>();
            if (roomVM.room != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local songs can\'t be shared in a party')),
              );
              return;
            }
            libraryVM.playLocalSong(song);
          },
        );
      },
    );
  }
}