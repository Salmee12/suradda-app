import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:suradda_app/presentation/viewmodels/hotspot_room_viewmodel.dart';
import 'package:suradda_app/presentation/viewmodels/online_room_viewmodel.dart';
import 'package:suradda_app/services/streaming/local_stream_host_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'di/locator.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/views/root/root_shell.dart';
import 'presentation/views/auth/phone_login_page.dart';
import 'presentation/views/auth/subscription_expired_page.dart';
import 'services/audio/playback_service.dart';

class SurAddaApp extends StatelessWidget {
  const SurAddaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // .value, not create: AuthViewModel is a locator singleton now, and
        // create would let this provider dispose it.
        ChangeNotifierProvider<AuthViewModel>.value(value: locator<AuthViewModel>()),
        ChangeNotifierProvider<PlaybackService>.value(value: locator<PlaybackService>()),
        ChangeNotifierProvider<OnlineRoomViewModel>.value(value: locator<OnlineRoomViewModel>()),
        ChangeNotifierProvider<HotspotRoomViewModel>.value(value: locator<HotspotRoomViewModel>()),
        ChangeNotifierProvider<LocalStreamHostService>.value(value: locator<LocalStreamHostService>()),

      ],
      child: MaterialApp(
        title: 'SurAdda',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
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
          // Signed in but not paying. Kept separate from unauthenticated so the
          // user gets an explanation and a way back in, instead of silently
          // landing on the phone screen as though the session had died.
          case AuthStatus.subscriptionExpired:
            return const SubscriptionExpiredPage();
          case AuthStatus.unauthenticated:
            return const PhoneLoginPage();
          case AuthStatus.unknown:
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.graphic_eq_rounded,
                        size: 72, color: AppColors.primary),
                    SizedBox(height: 28),
                    SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ],
                ),
              ),
            );
        }
      },
    );
  }
}