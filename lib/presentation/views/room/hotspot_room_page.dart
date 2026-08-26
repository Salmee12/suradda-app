import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../../services/audio/playback_service.dart';

class HotspotRoomPage extends StatelessWidget {
  const HotspotRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomVM = context.watch<HotspotRoomViewModel>();
    final playback = context.watch<PlaybackService>();
    final song = playback.currentSong;

    return Scaffold(
      appBar: AppBar(
        title: Text(roomVM.isHost ? 'Hosting (Hotspot)' : 'Listening (Hotspot)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave',
            onPressed: () => roomVM.leaveRoom(),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Theme.of(context).colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Changing tracks and pausing frequently might disrupt sync between clients. Tap on the seekbar to adjust sync.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  roomVM.isHost ? Icons.wifi_tethering : Icons.cast_connected,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  roomVM.isHost
                      ? '${roomVM.hostServicePublic.connectedClientsCount} listener${roomVM.hostServicePublic.connectedClientsCount == 1 ? '' : 's'} connected'
                      : 'Connected to ${roomVM.connectedHost?.name ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (song != null) ...[
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ] else if (roomVM.isHost)
                  const Text('Go to Library → Local Songs to pick something to host.',
                      textAlign: TextAlign.center),
              ],
            ),
          ),
          if (song != null) ...[
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
                        Slider(
                          min: 0,
                          max: duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                          value: position.inMilliseconds
                              .toDouble()
                              .clamp(0, duration.inMilliseconds.toDouble().clamp(1, double.infinity)),
                          onChanged: roomVM.isHost ? (_) {} : null,
                          onChangeEnd: roomVM.isHost
                              ? (value) => roomVM.hostSeek(Duration(milliseconds: value.toInt()))
                              : null,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            StreamBuilder(
              stream: playback.playerStateStream,
              builder: (context, snapshot) {
                final playing = snapshot.data?.playing ?? false;
                return IconButton(
                  iconSize: 72,
                  color: Theme.of(context).colorScheme.primary,
                  icon: Icon(playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill),
                  onPressed: roomVM.isHost ? roomVM.hostTogglePlayPause : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}