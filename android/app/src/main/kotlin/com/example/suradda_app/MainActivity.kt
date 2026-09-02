package com.example.suradda_app

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (instead of FlutterActivity) is required by
// just_audio_background so the media foreground service can bind to the app.
class MainActivity : AudioServiceActivity()
