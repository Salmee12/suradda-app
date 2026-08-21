// lib/presentation/views/room/join_party_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/streaming/local_stream_client_service.dart';
import '../../viewmodels/hotspot_room_viewmodel.dart';
import 'hotspot_room_page.dart';

class JoinHotspotRoomPage extends StatefulWidget {
  const JoinHotspotRoomPage({super.key});

  @override
  State<JoinHotspotRoomPage> createState() => _JoinHotspotRoomPageState();
}

class _JoinHotspotRoomPageState extends State<JoinHotspotRoomPage> {
  @override
  void initState() {
    super.initState();
    context.read<HotspotRoomViewModel>().startDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    final roomVM = context.watch<HotspotRoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Join Hotspot Party')),
      body: StreamBuilder<List<DiscoveredHost>>(
        stream: roomVM.clientService.discoveredHostsStream,
        builder: (context, snapshot) {
          final hosts = snapshot.data ?? [];
          if (hosts.isEmpty) {
            return const Center(child: Text('Searching for nearby hosts on hotspot...'));
          }

          return ListView.builder(
            itemCount: hosts.length,
            itemBuilder: (context, index) {
              final host = hosts[index];
              return ListTile(
                leading: const Icon(Icons.cast_connected),
                title: Text(host.name),
                subtitle: Text('IP: ${host.hostIp}'),
                onTap: () async {
                  await roomVM.joinParty(host);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const HotspotRoomPage()),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}