import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/library_viewmodel.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
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
    final hotspotVM = context.watch<HotspotRoomViewModel>();

    if (libraryVM.isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (libraryVM.localErrorMessage != null) {
      return Center(child: Text(libraryVM.localErrorMessage!));
    }
    if (libraryVM.localSongs.isEmpty) {
      return const Center(child: Text('No local songs found on this device.'));
    }

    return Column(
      children: [
        if (hotspotVM.isHost)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'As host, tap any song to share it instantly with your Hotspot party.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: libraryVM.localSongs.length,
            itemBuilder: (context, index) {
              final song = libraryVM.localSongs[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: QueryArtworkWidget(
                  id: song.id,
                  type: ArtworkType.AUDIO,
                  nullArtworkWidget: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.music_note, color: AppColors.textSecondary),
                  ),
                  artworkFit: BoxFit.cover,
                  artworkWidth: 52,
                  artworkHeight: 52,
                  artworkBorder: BorderRadius.circular(6),
                ),
                title: Text(song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(song.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary)),
                onTap: () async {
                  final roomVM = context.read<OnlineRoomViewModel>();
                  final hotspotVM = context.read<HotspotRoomViewModel>();


                  if (roomVM.room != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Local songs can\'t be shared in an online party')),
                    );
                    return;
                  }

                  if (hotspotVM.isClient) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Only the host can choose songs during a Hotspot party')),
                    );
                    return;
                  }

                  if (hotspotVM.isHost) {
                    try {
                      await hotspotVM.playLocalSongAsHost(song);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                    return;
                  }

                  final libraryVM = context.read<LibraryViewModel>();
                  libraryVM.playLocalSong(song);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}