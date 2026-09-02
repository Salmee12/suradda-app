import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/navigation/root_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/radio_model.dart';
import '../../../di/locator.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import '../../viewmodels/radio_viewmodel.dart';

class RadioPage extends StatelessWidget {
  const RadioPage({super.key});

  Future<void> _handlePowerToggle(BuildContext context, RadioViewModel radioVM) async {
    // Only switching ON needs a guard; switching off is always allowed.
    if (!radioVM.isPowerOn) {
      final onlineVM = context.read<OnlineRoomViewModel>();
      final hotspotVM = context.read<HotspotRoomViewModel>();
      final inAnyRoom =
          onlineVM.room != null || hotspotVM.isHost || hotspotVM.isClient;

      if (inAnyRoom) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Radio service is not available when in a room'),
          ),
        );
        return;
      }
    }

    // No explicit stop of the music player: radio and music share the one
    // AudioPlayer, so tuning a station replaces whatever was playing.
    await radioVM.togglePower();
  }

  @override
  Widget build(BuildContext context) {
    // .value, not create: the VM is a locator singleton so the radio survives
    // this page being disposed on a tab switch. ChangeNotifierProvider.value
    // also won't dispose it, which is what we want for a shared instance.
    return ChangeNotifierProvider<RadioViewModel>.value(
      value: locator<RadioViewModel>(),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: RootNavigation.of(context).openDrawer,
          ),
          title: const Text('Live Radio'),
          centerTitle: true,
          actions: const [_RegionPicker()],
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
                                errorBuilder: (_, _, _) => const Icon(
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

/// AppBar dropdown that switches the station list between regions.
///
/// A [Consumer] rather than `context.watch`: the AppBar is built with
/// RadioPage's own context, which sits *above* the ChangeNotifierProvider, so a
/// direct lookup wouldn't find the RadioViewModel.
class _RegionPicker extends StatelessWidget {
  const _RegionPicker();

  @override
  Widget build(BuildContext context) {
    return Consumer<RadioViewModel>(
      builder: (context, radioVM, _) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<RadioRegion>(
            value: radioVM.region,
            // Disabled mid-fetch so two region loads can't race each other.
            onChanged: radioVM.isLoading
                ? null
                : (region) {
                    if (region != null) radioVM.setRegion(region);
                  },
            borderRadius: BorderRadius.circular(12),
            dropdownColor: AppColors.card,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            items: [
              for (final region in RadioRegion.values)
                DropdownMenuItem(value: region, child: Text(region.label)),
            ],
          ),
        ),
      ),
    );
  }
}