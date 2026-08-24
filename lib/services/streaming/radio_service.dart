// radio_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../data/models/radio_model.dart';

class RadioService {
  static const String _baseUrl = 'https://de1.api.radio-browser.info/json/stations';

  Future<List<RadioStation>> fetchTopStations({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/topclick/$limit'),
      headers: {'User-Agent': 'YourFlutterAppName/1.0'},
    );

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((json) => RadioStation.fromJson(json)).toList();
    }
    return [];
  }
}