import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/models/song_model.dart';

/// Outcome of a single download attempt.
///
/// [error] carries the real reason when [success] is false, so the UI can show
/// something actionable instead of a generic message.
class DownloadResult {
  final bool success;
  final String? error;
  final String? savedPath;

  const DownloadResult.ok({this.savedPath})
      : success = true,
        error = null;

  const DownloadResult.failed(this.error)
      : success = false,
        savedPath = null;
}

/// Downloads a cloud song into the device's shared Music store (via MediaStore)
/// so it shows up in the Local tab (on_audio_query) and can be shared in a
/// Hotspot party (the host opens File(song.data)).
///
/// Uses its own [Dio] instance so the app's auth interceptor / baseUrl are NOT
/// applied to the external, already-public song URL.
class SongDownloadService {
  final Dio _dio = Dio();
  final MediaStore _mediaStore = MediaStore();

  Future<DownloadResult> downloadSong(SongModel song) async {
    final fileName = _buildFileName(song);
    String? tempPath;

    try {
      final sdkInt = Platform.isAndroid ? await _mediaStore.getPlatformSDKInt() : 0;

      // Only API <= 29 needs a runtime WRITE_EXTERNAL_STORAGE grant. From API 30
      // the MediaStore insert owns the file, and the legacy permission isn't even
      // in the merged manifest (maxSdkVersion=29), so requesting it there just
      // returns permanentlyDenied and would block a download that would work.
      if (Platform.isAndroid && sdkInt <= 29) {
        var status = await Permission.storage.status;
        if (!status.isGranted) status = await Permission.storage.request();
        if (!status.isGranted) {
          return const DownloadResult.failed('Storage permission denied');
        }
      }

      final tempDir = await getTemporaryDirectory();
      tempPath = '${tempDir.path}/$fileName';
      await _dio.download(song.songUrl, tempPath);

      // media_store_plus returns null in several cases where the file *was*
      // actually written (below API 30 it copies the file first and only then
      // looks it up in MediaStore, which fails until the media scanner runs), so
      // a null here is not proof of failure — verify on disk below.
      SaveInfo? saveInfo;
      Object? saveError;
      try {
        saveInfo = await _mediaStore.saveFile(
          tempFilePath: tempPath,
          dirType: DirType.audio,
          dirName: DirName.music,
          relativePath: MediaStore.appFolder,
        );
      } catch (e) {
        saveError = e;
      }

      final expectedPath = '${_musicFolderPath()}/$fileName';
      if (saveInfo != null) {
        debugPrint('SongDownloadService: saved -> ${saveInfo.uri} (${saveInfo.saveStatus})');
        return DownloadResult.ok(savedPath: expectedPath);
      }

      // saveFile returned null or threw — did the file land anyway?
      if (await _fileLanded(fileName, expectedPath)) {
        debugPrint('SongDownloadService: saveFile reported nothing but $expectedPath exists');
        return DownloadResult.ok(savedPath: expectedPath);
      }

      debugPrint('SongDownloadService: save failed -> ${saveError ?? 'saveFile returned null'}');
      return DownloadResult.failed(
        saveError != null ? _describe(saveError) : 'Could not write to the Music folder',
      );
    } on DioException catch (e) {
      debugPrint('SongDownloadService: network failure -> $e');
      return DownloadResult.failed('Network error (${e.type.name})');
    } catch (e) {
      debugPrint('SongDownloadService: download failed -> $e');
      return DownloadResult.failed(_describe(e));
    } finally {
      // The plugin deletes the temp file itself on success; guard either way.
      if (tempPath != null) {
        try {
          final f = File(tempPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
    }
  }

  /// Two independent checks, because each one fails in a different Android era:
  /// the direct [File] check works below API 30 (legacy external storage) while
  /// the MediaStore lookup works from API 30 up.
  Future<bool> _fileLanded(String fileName, String expectedPath) async {
    try {
      if (await File(expectedPath).exists()) return true;
    } catch (_) {}
    try {
      return await _mediaStore.isFileExist(
        fileName: fileName,
        dirType: DirType.audio,
        dirName: DirName.music,
        relativePath: MediaStore.appFolder,
      );
    } catch (_) {
      return false;
    }
  }

  String _musicFolderPath() => DirType.audio.fullPath(
        relativePath: MediaStore.appFolder,
        dirName: DirName.music,
      );

  String _describe(Object e) {
    final text = e.toString();
    return text.length > 140 ? '${text.substring(0, 140)}…' : text;
  }

  String _buildFileName(SongModel song) {
    final safe = song.songName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safe.isEmpty ? 'song_${song.id}' : safe;
    return '$base${_extensionFromUrl(song.songUrl)}';
  }

  String _extensionFromUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? url;
    final dot = path.lastIndexOf('.');
    if (dot != -1 && dot > path.lastIndexOf('/')) {
      final ext = path.substring(dot);
      if (ext.length <= 5) return ext;
    }
    return '.mp3';
  }
}
