import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/color_utils.dart';
import '../../../services/audio/playback_service.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';

class MusicPlayerPage extends StatelessWidget {
  const MusicPlayerPage({super.key});

  String _fmt(Duration? d) {
    if (d == null) return '0:00';
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.watch<PlaybackService>();
    final onlineVM = context.watch<OnlineRoomViewModel>();
    final hotspotVM = context.watch<HotspotRoomViewModel>();
    final song = playback.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing')));
    }

    final inOnlineParty = onlineVM.room != null;
    final inHotspotParty = hotspotVM.isHost || hotspotVM.isClient;
    final inAnyParty = inOnlineParty || inHotspotParty;
    final isHost = (inOnlineParty && onlineVM.isHost) || (inHotspotParty && hotspotVM.isHost);

    const toggleEnabled = true;
    final skipEnabled = !inAnyParty;
    final seekEnabled = !inAnyParty || isHost;

    Future<void> onToggle() async {
      if (inHotspotParty) {
        await hotspotVM.hostTogglePlayPause();
      } else if (inOnlineParty) {
        if (onlineVM.isHost) {
          await onlineVM.hostTogglePlayPause();
        } else {
          await playback.togglePlayPause();
        }
      } else {
        await playback.togglePlayPause();
      }
    }

    Future<void> onSeek(Duration position) async {
      if (inHotspotParty) {
        await hotspotVM.hostSeek(position);
      } else if (inOnlineParty) {
        await onlineVM.hostSeek(position);
      } else {
        await playback.seek(position);
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [hexToColor(song.hexCode), const Color(0xff121212)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (inAnyParty)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Row(
                    children: [
                      const Icon(Icons.groups, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        isHost ? 'Hosting' : 'Listening',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Hero(
                    tag: 'music-image',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 32,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song.artworkUrl != null
                            ? Image.network(song.artworkUrl!,
                            fit: BoxFit.cover, width: double.infinity, errorBuilder: (_, _, _) => _fallbackArt())
                            : _fallbackArt(),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                song.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<Duration?>(
                      stream: playback.durationStream,
                      builder: (context, durationSnap) {
                        final duration = durationSnap.data ?? Duration.zero;
                        return StreamBuilder<Duration>(
                          stream: playback.positionStream,
                          builder: (context, positionSnap) {
                            var position = positionSnap.data ?? Duration.zero;
                            if (position > duration) position = duration;

                            return Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: seekEnabled ? Colors.white : Colors.white38,
                                    trackHeight: 4,
                                    overlayShape: SliderComponentShape.noOverlay,
                                  ),
                                  child: Slider(
                                    min: 0,
                                    max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                                    value: position.inMilliseconds
                                        .toDouble()
                                        .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                                    onChanged: seekEnabled ? (_) {} : null,
                                    onChangeEnd: seekEnabled
                                        ? (value) => onSeek(Duration(milliseconds: value.toInt()))
                                        : null,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_fmt(position), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                    Text(_fmt(duration), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                  ],
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: skipEnabled && playback.hasPrevious ? playback.playPrevious : null,
                          icon: const Icon(CupertinoIcons.backward_end_fill),
                          color: skipEnabled && playback.hasPrevious ? Colors.white : Colors.white24,
                          iconSize: 36,
                        ),
                        const SizedBox(width: 20),
                        StreamBuilder<PlayerState>(
                          stream: playback.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton(
                              onPressed: toggleEnabled ? onToggle : null,
                              icon: Icon(
                                playing ? CupertinoIcons.pause_circle_fill : CupertinoIcons.play_circle_fill,
                                color: toggleEnabled ? Colors.white : Colors.white24,
                              ),
                              iconSize: 80,
                            );
                          },
                        ),
                        const SizedBox(width: 20),
                        IconButton(
                          onPressed: skipEnabled && playback.hasNext ? playback.playNext : null,
                          icon: const Icon(CupertinoIcons.forward_end_fill),
                          color: skipEnabled && playback.hasNext ? Colors.white : Colors.white24,
                          iconSize: 36,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackArt() => Container(
    color: Colors.white24,
    width: double.infinity,
    child: const Icon(Icons.music_note, size: 80, color: Colors.white),
  );
}