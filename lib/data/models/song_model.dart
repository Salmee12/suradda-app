import 'package:suradda_app/data/models/playable_track.dart';

class SongModel implements PlayableTrack {
  final String id;
  final String songUrl;
  final String thumbnailUrl;
  final String artist;
  final String songName;
  @override
  final String hexCode;

  SongModel({
    required this.id,
    required this.songUrl,
    required this.thumbnailUrl,
    required this.artist,
    required this.songName,
    required this.hexCode,
  });

  factory SongModel.fromJson(Map<String, dynamic> json) {
    return SongModel(
      id: json['id'],
      songUrl: json['song_url'],
      thumbnailUrl: json['thumbnail_url'],
      artist: json['artist'],
      songName: json['song_name'],
      hexCode: json['hex_code'],
    );
  }

  @override
  String get trackId => id;
  @override
  String get title => songName;
  @override
  String get subtitle => artist;
  @override
  String get playUrl => songUrl;
  @override
  String? get artworkUrl => thumbnailUrl;
}