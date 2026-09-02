// radio_station_model.dart

/// Which pool of stations the radio tunes into.
///
/// Adding another country is a one-line change here — the service builds its
/// query from [countryCode] and the UI builds its dropdown from
/// [RadioRegion.values], so neither needs touching.
enum RadioRegion {
  /// The globally most-clicked stations, whatever country they're in.
  international(label: 'Global', countryCode: null),
  bangladesh(label: 'Bangladesh', countryCode: 'BD');

  const RadioRegion({required this.label, required this.countryCode});

  /// Shown in the dropdown. Kept short so it fits in the AppBar.
  final String label;

  /// ISO 3166-1 alpha-2 code, or null to search worldwide.
  final String? countryCode;
}

class RadioStation {
  final String stationUuid;
  final String name;
  final String streamUrl;
  final String favicon;
  final String tags;

  RadioStation({
    required this.stationUuid,
    required this.name,
    required this.streamUrl,
    required this.favicon,
    required this.tags,
  });

  factory RadioStation.fromJson(Map<String, dynamic> json) {
    return RadioStation(
      stationUuid: json['stationuuid'] ?? '',
      name: json['name'] ?? 'Unknown Station',
      streamUrl: json['url_resolved'] ?? json['url'] ?? '',
      favicon: json['favicon'] ?? '',
      tags: json['tags'] ?? '',
    );
  }
}