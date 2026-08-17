import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/online_room_viewmodel.dart';
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnlineRoomViewModel>();

    if (vm.room != null) {
      return const PartyView(); // party is active — replace this tab's content entirely
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Parties')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (vm.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            vm.isLoading
                ? const CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create Party'),
                  onPressed: () => vm.createParty(),
                ),
                const SizedBox(height: 16),
                if (!_showJoinField)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Join Party'),
                    onPressed: () => setState(() => _showJoinField = true),
                  )
                else ...[
                  TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Party Code'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => vm.joinParty(_codeController.text),
                    child: const Text('Join'),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton.icon(
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Party over Hotspot'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HotspotRoomPage()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}