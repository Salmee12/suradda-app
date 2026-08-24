// radio_station_model.dart
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