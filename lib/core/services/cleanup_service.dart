import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CleanupService {
  /// Cleans up temporary audio files older than a specified duration (default: 1 day)
  static Future<void> cleanTemporaryAudioFiles({Duration olderThan = const Duration(days: 1)}) async {
    try {
      final dir = await getTemporaryDirectory();
      if (!dir.existsSync()) return;

      final now = DateTime.now();
      final entities = dir.listSync();

      for (var entity in entities) {
        if (entity is File && entity.path.contains('audio_') && entity.path.endsWith('.m4a')) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > olderThan) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      // Ignore errors during cleanup
      print('Error during cleanup: $e');
    }
  }
}
