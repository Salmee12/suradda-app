// lib/presentation/views/room/create_party_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import 'hotspot_room_page.dart';

class CreateHotspotRoomPage extends StatelessWidget {
  const CreateHotspotRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roomVM = context.read<HotspotRoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Host Hotspot Party')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.wifi_tethering),
          label: const Text('Start Hotspot Room'),
          onPressed: () async {
            await roomVM.startHosting();
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HotspotRoomPage()),
              );
            }
          },
        ),
      ),
    );
  }
}