import 'package:on_audio_query/on_audio_query.dart' as oaq;
import 'package:suradda_app/data/models/playable_track.dart';
import 'song_model.dart';

class LocalSongModel implements PlayableTrack {
  final int id;
  final String titleField;
  final String artistField;
  final String uri;
  final Duration? duration;

  LocalSongModel({
    required this.id,
    required this.titleField,
    required this.artistField,
    required this.uri,
    this.duration,
  });

  factory LocalSongModel.fromQuerySong(oaq.SongModel song) {
    return LocalSongModel(
      id: song.id,
      titleField: song.title,
      artistField: song.artist ?? 'Unknown artist',
      // CRITICAL FIX: Use song.data (absolute file path) first for direct file reading
      uri: (song.data.isNotEmpty ? song.data : song.uri) ?? '',
      duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
    );
  }

  @override
  String get trackId => 'local_$id';
  @override
  String get title => titleField;
  @override
  String get subtitle => artistField;
  @override
  String get playUrl => uri;
  @override
  String? get artworkUrl => null; // resolved separately via QueryArtworkWidget
  @override
  String get hexCode => '424242'; // neutral fallback color for local tracks
}