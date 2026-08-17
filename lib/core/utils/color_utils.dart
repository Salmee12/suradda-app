import 'package:flutter/material.dart';

Color hexToColor(String hexCode) {
  final buffer = StringBuffer();
  if (hexCode.length == 6 || hexCode.length == 7) buffer.write('ff');
  buffer.write(hexCode.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}