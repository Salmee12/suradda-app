import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'app.dart';
import 'di/locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Runs playback inside an Android foreground service. Besides the media
  // notification, this is what keeps the process alive when the app is
  // backgrounded — without it Android suspends the isolate and the party's
  // WebSocket dies within seconds of pressing Home.
  // Must run before any AudioPlayer is constructed.
  // Background audio service configuration (Android/iOS only)
  if (!kIsWeb) {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.suradda_app.channel.audio',
      androidNotificationChannelName: 'SurAdda playback',
      androidNotificationOngoing: true,
    );
  }

  setupLocator();

  // MediaStore is Android-specific. Guard against Web and other platforms.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'SurAdda';
  }

  runApp(const SurAddaApp());
}


//flutter run -d web-server --web-port 8080
