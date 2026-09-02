import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../viewmodels/room_connection.dart';
import '../../widgets/connection_banner.dart';
import '../../../services/audio/playback_service.dart';

class HotspotRoomPage extends StatelessWidget {
  const HotspotRoomPage({super.key});

  String _clientStatus(HotspotRoomViewModel vm) {
    final hostName = vm.connectedHost?.name ?? 'the host';
    switch (vm.connection) {
      case RoomConnection.connected:
        return 'Connected to $hostName';
      case RoomConnection.connecting:
        return 'Connecting to $hostName...';
      case RoomConnection.reconnecting:
        return 'Reconnecting to $hostName...';
      case RoomConnection.disconnected:
      case RoomConnection.idle:
        return 'Disconnected from $hostName';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomVM = context.watch<HotspotRoomViewModel>();
    final playback = context.watch<PlaybackService>();
    final song = playback.currentSong;
    final clientOffline = roomVM.isClient && roomVM.connection.isBroken;

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
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  roomVM.isHost
                      ? Icons.wifi_tethering
                      : clientOffline
                          ? Icons.cast
                          : Icons.cast_connected,
                  size: 48,
                  color: clientOffline
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  roomVM.isHost
                      ? '${roomVM.hostServicePublic.connectedClientsCount} listener${roomVM.hostServicePublic.connectedClientsCount == 1 ? '' : 's'} connected'
                      : _clientStatus(roomVM),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (song != null) ...[
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ] else if (roomVM.isHost)
                  const Text(
                    'All participants joined? Now go to Library → Local Songs and tap a track to share it. '
                    '(Songs picked before everyone joins won\'t reach late joiners.)',
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
          if (roomVM.isClient)
            ConnectionBanner(
              connection: roomVM.connection,
              onRetry: roomVM.retryConnection,
              onLeave: roomVM.leaveRoom,
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