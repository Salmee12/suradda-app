// radio_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../data/models/radio_model.dart';

class RadioService {
  static const String _searchUrl =
      'https://de1.api.radio-browser.info/json/stations/search';

  // radio-browser.info asks callers to identify themselves; a real name keeps us
  // off their rate-limit list.
  static const Map<String, String> _headers = {'User-Agent': 'SurAdda/1.0'};

  /// Most-clicked stations for [region], newest health check first.
  ///
  /// Returns an empty list on any failure — the UI reads that as "couldn't
  /// load" and offers Retry, so a dead network doesn't need a separate path.
  Future<List<RadioStation>> fetchStations({
    RadioRegion region = RadioRegion.international,
    int limit = 30,
  }) async {
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      // Drops stations whose stream failed the API's last health check.
      'hidebroken': 'true',
      'order': 'clickcount',
      'reverse': 'true',
      'limit': '$limit',
      if (region.countryCode != null) 'countrycode': region.countryCode!,
    });

    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode != 200) {
        debugPrint('[RadioService] ${response.statusCode} for $uri');
        return [];
      }
      final List data = json.decode(response.body);
      return data
          .map((json) => RadioStation.fromJson(json))
          // A station with no resolvable stream URL would just fail on play.
          .where((station) => station.streamUrl.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('[RadioService] fetch failed for $uri: $e');
      return [];
    }
  }
}
