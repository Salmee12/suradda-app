import 'package:flutter/material.dart';
import 'app.dart';
import 'di/locator.dart';

void main() {
  setupLocator();
  runApp(const SurAddaApp());
}


//flutter run -d web-server --web-port 8080