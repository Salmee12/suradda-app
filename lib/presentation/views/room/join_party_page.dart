/*
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import 'party_screen.dart';

class JoinPartyPage extends StatefulWidget {
  const JoinPartyPage({super.key});

  @override
  State<JoinPartyPage> createState() => _JoinPartyPageState();
}

class _JoinPartyPageState extends State<JoinPartyPage> {
  final _codeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnlineRoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Join Party')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Party Code'),
            ),
            const SizedBox(height: 16),
            if (vm.errorMessage != null)
              Text(vm.errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            vm.isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: () async {
                await vm.joinParty(_codeController.text);
                if (vm.room != null && context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PartyScreen()),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
  }
}*/
