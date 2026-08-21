import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suradda_app/presentation/viewmodels/hotspot_room_viewmodel.dart';
import 'package:suradda_app/presentation/viewmodels/online_room_viewmodel.dart';
import 'package:suradda_app/services/streaming/local_stream_host_service.dart';
import 'di/locator.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/views/root/root_shell.dart';
import 'presentation/views/auth/login_page.dart';
import 'services/audio/playback_service.dart';

class SurAddaApp extends StatelessWidget {
  const SurAddaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>(create: (_) => locator<AuthViewModel>()),
        ChangeNotifierProvider<PlaybackService>.value(value: locator<PlaybackService>()),
        ChangeNotifierProvider<OnlineRoomViewModel>.value(value: locator<OnlineRoomViewModel>()),
        ChangeNotifierProvider<HotspotRoomViewModel>.value(value: locator<HotspotRoomViewModel>()),
        ChangeNotifierProvider<LocalStreamHostService>.value(value: locator<LocalStreamHostService>()),

      ],
      child: MaterialApp(
        title: 'SurAdda',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.deepPurple,
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authVM, _) {
        switch (authVM.status) {
          case AuthStatus.authenticated:
            return const RootShell();
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
        }
      },
    );
  }
}