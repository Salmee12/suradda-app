import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/app_scaffold_key.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import '../../../services/audio/playback_service.dart';

class PartyView extends StatelessWidget {
  const PartyView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnlineRoomViewModel>();
    final playback = context.watch<PlaybackService>();
    final room = vm.room;
    final song = playback.currentSong;

    return Scaffold(
      appBar: AppBar(
        title: Text('Party ${room?.code ?? ''}'),

        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Leave Party',
            onPressed: () => vm.leaveParty(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Now playing
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: song == null
                ? const Text('Nothing playing yet')
                : Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: song.artworkUrl != null
                      ? Image.network(song.artworkUrl!, width: 56, height: 56, fit: BoxFit.cover)
                      : Container(
                    width: 56,
                    height: 56,
                    color: Colors.white24,
                    child: const Icon(Icons.music_note),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(song.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(room?.isPlaying == true ? 'Playing' : 'Paused',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.groups, size: 18),
                const SizedBox(width: 6),
                Text('${vm.participants.length} in this party',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: vm.participants.isEmpty
                ? const Center(child: Text('Waiting for participants...'))
                : ListView.builder(
              itemCount: vm.participants.length,
              itemBuilder: (context, index) {
                final p = vm.participants[index];
                final isThisHost = room != null && p.userId == room.hostId;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isThisHost
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor: isThisHost ? Colors.black : Colors.white,
                    child: Text(p.username[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  title: Text(p.username),
                  trailing: isThisHost
                      ? Chip(
                          label: const Text('Host'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          labelStyle: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w700),
                          side: BorderSide.none,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}