/*
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/online_room_viewmodel.dart';
import 'party_screen.dart';

class CreatePartyPage extends StatelessWidget {
  const CreatePartyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OnlineRoomViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Create Party')),
      body: Center(
        child: vm.isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
          onPressed: () async {
            await vm.createParty();
            if (vm.room != null && context.mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PartyScreen()),
              );
            }
          },
          child: const Text('Start Party'),
        ),
      ),
    );
  }
}*/
