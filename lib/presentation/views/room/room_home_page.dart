import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/app_scaffold_key.dart';
import '../../../core/theme/app_colors.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../../services/audio/playback_service.dart';
import '../../../data/models/local_song_model.dart';
import '../../../services/streaming/local_stream_client_service.dart';
import 'hotspot_room_page.dart';
import 'party_view.dart';

class RoomHomePage extends StatefulWidget {
  const RoomHomePage({super.key});

  @override
  State<RoomHomePage> createState() => _RoomHomePageState();
}

class _RoomHomePageState extends State<RoomHomePage> {
  final _codeController = TextEditingController();
  bool _showJoinField = false;
  bool _showHotspotHost = false;
  bool _showHotspotJoin = false;

  void _resetHotspotState(HotspotRoomViewModel vm) {
    debugPrint('[RoomUI] Resetting hotspot UI state and stopping discovery...');
   // vm.clientService.stopDiscovery();
    setState(() {
      _showHotspotHost = false;
      _showHotspotJoin = false;
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      );

  @override
  Widget build(BuildContext context) {
    final onlineVm = context.watch<OnlineRoomViewModel>();
    final hotspotVm = context.watch<HotspotRoomViewModel>();
    final playback = context.watch<PlaybackService>();

    if (onlineVm.room != null) return const PartyView();
    if (hotspotVm.isHost || hotspotVm.isClient) return const HotspotRoomPage();

    final canHostHotspot = playback.currentSong is LocalSongModel;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 20,
        title: const Text('Parties',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Listen together, in perfect sync.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            if (onlineVm.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(onlineVm.errorMessage!,
                    style: const TextStyle(color: AppColors.error)),
              ),

            // ── Online party card ─────────────────────────────
            Container(
              decoration: _cardDecoration,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.public, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Online Party',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Play cloud songs together over the internet.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  onlineVm.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.add),
                              label: const Text('Create Party'),
                              onPressed: () {
                                debugPrint('[RoomUI] Create Party pressed');
                                onlineVm.createParty();
                              },
                            ),
                            const SizedBox(height: 12),
                            if (!_showJoinField)
                              OutlinedButton.icon(
                                icon: const Icon(Icons.login),
                                label: const Text('Join Party'),
                                onPressed: () =>
                                    setState(() => _showJoinField = true),
                              )
                            else ...[
                              TextField(
                                controller: _codeController,
                                textCapitalization:
                                    TextCapitalization.characters,
                                decoration: const InputDecoration(
                                    labelText: 'Party Code'),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  debugPrint(
                                      '[RoomUI] Online Join pressed with code: ${_codeController.text}');
                                  onlineVm.joinParty(_codeController.text);
                                },
                                child: const Text('Join'),
                              ),
                            ],
                          ],
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Hotspot party card ────────────────────────────
            Container(
              decoration: _cardDecoration,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.wifi_tethering, color: AppColors.primary),
                      SizedBox(width: 10),
                      Text('Party over Hotspot',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 17)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Both devices must be on the same WiFi hotspot. Only songs on this device can be shared.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (!_showHotspotHost && !_showHotspotJoin) ...[
                    FilledButton.icon(
                      icon: const Icon(Icons.upload),
                      label: const Text('Host — share my music'),
                      onPressed: () {
                        debugPrint('[RoomUI] Host section opened');
                        setState(() => _showHotspotHost = true);
                      },
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.headphones),
                      label: const Text('Join — listen to a friend'),
                      onPressed: () {
                        debugPrint(
                            '[RoomUI] Join section opened -> starting discovery');
                        setState(() => _showHotspotJoin = true);
                        hotspotVm.startDiscovery();
                      },
                    ),
                  ],
                  if (_showHotspotHost) ...[
                    if (!canHostHotspot)
                      const Text(
                        'Pick a song from the Local tab in your Library first.',
                        textAlign: TextAlign.center,
                      )
                    else
                      Text(
                        'Ready to host: ${(playback.currentSong as LocalSongModel).title}',
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: canHostHotspot
                          ? () async {
                              debugPrint(
                                  '[RoomUI] Start Hosting button pressed');
                              final vm = context.read<HotspotRoomViewModel>();
                              await vm.startHosting();
                              _resetHotspotState(vm);
                            }
                          : null,
                      child: const Text('Start Hosting'),
                    ),
                    TextButton(
                      onPressed: () {
                        debugPrint('[RoomUI] Cancel Hosting pressed');
                        _resetHotspotState(hotspotVm);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                  if (_showHotspotJoin) ...[
                    StreamBuilder<List<DiscoveredHost>>(
                      stream: hotspotVm.clientService.discoveredHostsStream,
                      builder: (context, snapshot) {
                        final hosts = snapshot.data ?? [];
                        if (hosts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                                'Searching for a host on this WiFi network...'),
                          );
                        }
                        return Column(
                          children: hosts
                              .map((h) => ListTile(
                                    leading: const Icon(Icons.podcasts),
                                    title: Text(h.name),
                                    subtitle: Text(h.hostIp),
                                    onTap: () async {
                                      debugPrint(
                                          '[RoomUI] Selected host: ${h.name} (${h.hostIp})');
                                      final playback =
                                          context.read<PlaybackService>();
                                      await playback.player.stop();
                                      playback.clearQueue();
                                      final vm = context
                                          .read<HotspotRoomViewModel>();
                                      await vm.joinParty(h);
                                      _resetHotspotState(vm);
                                    },
                                  ))
                              .toList(),
                        );
                      },
                    ),
                    TextButton(
                      onPressed: () {
                        debugPrint('[RoomUI] Cancel Join pressed');
                        _resetHotspotState(hotspotVm);
                      },
                      child: const Text('Cancel'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
