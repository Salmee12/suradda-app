import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/color_utils.dart';
import '../../services/audio/playback_service.dart';
import '../viewmodels/online_room_viewmodel.dart';
import '../views/player/music_player_page.dart';

class MusicSlab extends StatelessWidget {
  const MusicSlab({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackService>();
    final roomVM = context.watch<OnlineRoomViewModel>();
    final song = playback.currentSong;

    if (song == null) return const SizedBox.shrink();

    /*final inParty = roomVM.room != null;
    final isHost = roomVM.isHost;
    final controlsEnabled = !inParty || isHost;

    final onPrevious = inParty ? roomVM.hostPlayPrevious : playback.playPrevious;
    final onNext = inParty ? roomVM.hostPlayNext : playback.playNext;
    final onToggle = inParty ? roomVM.hostTogglePlayPause : playback.togglePlayPause;*/

    final inParty = roomVM.room != null;
    final isHost = roomVM.isHost;
    final toggleEnabled = !inParty || isHost; // play/pause: solo mode, or host only
    final skipEnabled = !inParty; // next/previous: solo mode only, disabled entirely in a party

    final onToggle = inParty ? roomVM.hostTogglePlayPause : playback.togglePlayPause;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const MusicPlayerPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final tween = Tween(begin: const Offset(0, 1), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOut));
              return SlideTransition(position: animation.drive(tween), child: child);
            },
          ),
        );
      },
      child: Stack(
        children: [
          Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: hexToColor(song.hexCode),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Hero(
                  tag: 'music-image',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: song.artworkUrl != null
                        ? Image.network(
                      song.artworkUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.music_note),
                    )
                        : Container(
                      width: 44,
                      height: 44,
                      color: Colors.white24,
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          if (inParty)
                            const Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(Icons.groups, size: 14, color: Colors.white70),
                            ),
                          Expanded(
                            child: Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ),
                      Text(song.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: skipEnabled ? playback.playPrevious : null,
                  icon: Icon(CupertinoIcons.backward_fill,
                      color: skipEnabled ? Colors.white : Colors.white38),
                ),
                StreamBuilder(
                  stream: playback.playerStateStream,
                  builder: (context, snapshot) {
                    final playing = snapshot.data?.playing ?? false;
                    return IconButton(
                      onPressed: toggleEnabled ? onToggle : null,
                      icon: Icon(
                        playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: toggleEnabled ? Colors.white : Colors.white38,
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: skipEnabled ? playback.playNext : null,
                  icon: Icon(CupertinoIcons.forward_fill,
                      color: skipEnabled ? Colors.white : Colors.white38),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 6,
            left: 16,
            right: 16,
            child: StreamBuilder<Duration?>(
              stream: playback.durationStream,
              builder: (context, durationSnap) {
                final duration = durationSnap.data ?? Duration.zero;
                return StreamBuilder<Duration>(
                  stream: playback.positionStream,
                  builder: (context, positionSnap) {
                    final position = positionSnap.data ?? Duration.zero;
                    final progress = duration.inMilliseconds == 0
                        ? 0.0
                        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(height: 2, width: constraints.maxWidth, color: Colors.white24),
                            Container(height: 2, width: constraints.maxWidth * progress, color: Colors.white),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}