import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<bool> requestAudioPermission() async {
    final status = await Permission.audio.status;
    if (status.isGranted) return true;

    final result = await Permission.audio.request();
    if (result.isGranted) return true;

    // Fallback for older Android versions where storage permission applies
    final storageResult = await Permission.storage.request();
    return storageResult.isGranted;
  }
}