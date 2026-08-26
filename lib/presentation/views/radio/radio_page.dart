import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/app_scaffold_key.dart';
import '../../../core/theme/app_colors.dart';
import '../../../services/audio/playback_service.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import '../../viewmodels/radio_viewmodel.dart';

class RadioPage extends StatelessWidget {
  const RadioPage({super.key});

  Future<void> _handlePowerToggle(BuildContext context, RadioViewModel radioVM) async {
    final onlineVM = context.read<OnlineRoomViewModel>();
    final hotspotVM = context.read<HotspotRoomViewModel>();
    final playback = context.read<PlaybackService>();

    final inOnlineRoom = onlineVM.room != null;
    final inHotspotRoom = hotspotVM.isHost || hotspotVM.isClient;
    final inAnyRoom = inOnlineRoom || inHotspotRoom;

    // Checks when attempting to turn the radio ON
    if (!radioVM.isPowerOn) {
      if (inAnyRoom) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Radio service is not available when in a room'),
          ),
        );
        return;
      }

      // Stop active music player if playing outside of a room
      if (playback.player.playing || playback.currentSong != null) {
        await playback.player.stop();
      }
    }

    await radioVM.togglePower();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RadioViewModel(),
      child: Scaffold(
        appBar: AppBar(
          /* leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
          ),*/
          title: const Text('Live Radio'),
          centerTitle: true,
        ),
        body: Consumer<RadioViewModel>(
          builder: (context, radioVM, child) {
            if (radioVM.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final station = radioVM.currentStation;
            if (station == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Failed to load radio stations.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => radioVM.fetchStations(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 96.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Station Visual / Artwork Container
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: radioVM.isPowerOn
                                      ? Theme.of(context).primaryColor.withValues(alpha: 0.35)
                                      : Colors.black26,
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: station.favicon.isNotEmpty
                                  ? Image.network(
                                station.favicon,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.radio,
                                  size: 80,
                                  color: Colors.grey,
                                ),
                              )
                                  : const Icon(
                                Icons.radio,
                                size: 80,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Station Title and Info
                          Text(
                            station.name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            station.tags.isNotEmpty ? station.tags : 'Global Radio Station',
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: radioVM.isPowerOn
                                  ? (radioVM.isBuffering ? Colors.orange : AppColors.primary)
                                  : Colors.grey[700],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              radioVM.isPowerOn
                                  ? (radioVM.isBuffering ? 'CONNECTING...' : 'LIVE')
                                  : 'OFF',
                              style: TextStyle(
                                color: (radioVM.isPowerOn && !radioVM.isBuffering)
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),

                          const SizedBox(height: 36),

                          // Dedicated Radio Controls Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Skip Backward Button
                              IconButton(
                                iconSize: 42,
                                icon: const Icon(Icons.skip_previous_rounded),
                                onPressed: () => radioVM.previousStation(),
                              ),

                              // Power On/Off Button
                              GestureDetector(
                                onTap: () => _handlePowerToggle(context, radioVM),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: radioVM.isPowerOn
                                        ? AppColors.primary
                                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                                    boxShadow: radioVM.isPowerOn
                                        ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.5),
                                        blurRadius: 18,
                                        spreadRadius: 1,
                                      )
                                    ]
                                        : [],
                                  ),
                                  child: Icon(
                                    Icons.power_settings_new_rounded,
                                    size: 38,
                                    color: radioVM.isPowerOn ? Colors.black : AppColors.textSecondary,
                                  ),
                                ),
                              ),

                              // Skip Forward Button
                              IconButton(
                                iconSize: 42,
                                icon: const Icon(Icons.skip_next_rounded),
                                onPressed: () => radioVM.nextStation(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}