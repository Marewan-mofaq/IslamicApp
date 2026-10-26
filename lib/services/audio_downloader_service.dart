import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioDownloaderService {
  static Future<String> _getBaseDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = '${docDir.path}/quran_audio';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  static String _getFileName(String reciterId, int surahNum) {
    final paddedSurah = surahNum.toString().padLeft(3, '0');
    return '${reciterId}_$paddedSurah.mp3';
  }

  // Check if device has active internet connection
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    try {
      final result = await InternetAddress.lookup('everyayah.com')
          .timeout(const Duration(seconds: 3));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Get local path for a reciter and surah
  static Future<String> getLocalPath(String reciterId, int surahNum) async {
    final baseDir = await _getBaseDir();
    final filename = _getFileName(reciterId, surahNum);
    return '$baseDir/$filename';
  }

  // Check if a surah is downloaded and valid
  static Future<bool> isDownloaded(String reciterId, int surahNum) async {
    try {
      final localPath = await getLocalPath(reciterId, surahNum);
      final file = File(localPath);
      return await file.exists() && await file.length() > 1000;
    } catch (_) {
      return false;
    }
  }

  // Downloads a surah with progressive callbacks
  static Future<String?> downloadAudio(
    String reciterId,
    int surahNum,
    String remoteUrl,
    Function(double) onProgress,
  ) async {
    try {
      final localPath = await getLocalPath(reciterId, surahNum);
      final file = File(localPath);
      final tmpFile = File('$localPath.tmp');
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(remoteUrl));
        final response = await client.send(request).timeout(const Duration(seconds: 30));

        if (response.statusCode != 200) {
          return null;
        }

        final totalBytes = response.contentLength ?? 0;
        final IOSink sink = tmpFile.openWrite();
        try {
          int receivedBytes = 0;
          await for (final chunk in response.stream) {
            receivedBytes += chunk.length;
            sink.add(chunk);
            if (totalBytes > 0) {
              onProgress(receivedBytes / totalBytes);
            }
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      } finally {
        client.close();
      }

      if (await tmpFile.exists() && await tmpFile.length() > 1000) {
        if (await file.exists()) {
          await file.delete();
        }
        await tmpFile.rename(localPath);
        return localPath;
      } else if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    } catch (e) {
      debugPrint('[AudioDownloader] Download failed: $e');
      try {
        final localPath = await getLocalPath(reciterId, surahNum);
        final tmpFile = File('$localPath.tmp');
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {}
    }
    return null;
  }

  // Deletes downloaded file
  static Future<bool> deleteDownloaded(String reciterId, int surahNum) async {
    try {
      final localPath = await getLocalPath(reciterId, surahNum);
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ━━━ AYAH-LEVEL OFFLINE AUDIO CACHING & DOWNLOADS ━━━

  static Future<String> _getAyahBaseDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final path = '${docDir.path}/quran_ayah_audio';
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return path;
  }

  static String getAyahFileName(String folder, int surahNum, int ayahNum) {
    final paddedSurah = surahNum.toString().padLeft(3, '0');
    final paddedAyah = ayahNum.toString().padLeft(3, '0');
    return '${folder}_${paddedSurah}_$paddedAyah.mp3';
  }

  // Get local path for an individual ayah audio
  static Future<String> getLocalAyahPath(String folder, int surahNum, int ayahNum) async {
    final baseDir = await _getAyahBaseDir();
    final filename = getAyahFileName(folder, surahNum, ayahNum);
    return '$baseDir/$filename';
  }

  // Check if an individual ayah audio is downloaded
  static Future<bool> isAyahDownloaded(String folder, int surahNum, int ayahNum) async {
    try {
      final localPath = await getLocalAyahPath(folder, surahNum, ayahNum);
      final file = File(localPath);
      return await file.exists() && await file.length() > 500;
    } catch (_) {
      return false;
    }
  }

  // Download or cache a single Ayah audio file
  static Future<String?> downloadAyahAudio(
    String folder,
    int surahNum,
    int ayahNum, {
    String? remoteUrl,
  }) async {
    try {
      final paddedSurah = surahNum.toString().padLeft(3, '0');
      final paddedAyah = ayahNum.toString().padLeft(3, '0');
      final url = remoteUrl ?? 'https://everyayah.com/data/$folder/$paddedSurah$paddedAyah.mp3';
      final localPath = await getLocalAyahPath(folder, surahNum, ayahNum);
      final file = File(localPath);

      if (await file.exists() && await file.length() > 500) {
        return localPath;
      }

      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.length > 500) {
        final tmpFile = File('$localPath.tmp');
        await tmpFile.writeAsBytes(response.bodyBytes, flush: true);
        if (await tmpFile.exists() && await tmpFile.length() > 500) {
          if (await file.exists()) await file.delete();
          await tmpFile.rename(localPath);
          return localPath;
        }
      } else if (response.statusCode != 200 && folder != 'Alafasy_128kbps') {
        // Fallback to Alafasy if specific reciter is unavailable
        final fallbackUrl = 'https://everyayah.com/data/Alafasy_128kbps/$paddedSurah$paddedAyah.mp3';
        final response2 = await http.get(Uri.parse(fallbackUrl)).timeout(const Duration(seconds: 15));
        if (response2.statusCode == 200 && response2.bodyBytes.length > 500) {
          final tmpFile = File('$localPath.tmp');
          await tmpFile.writeAsBytes(response2.bodyBytes, flush: true);
          if (await tmpFile.exists() && await tmpFile.length() > 500) {
            if (await file.exists()) await file.delete();
            await tmpFile.rename(localPath);
            return localPath;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // Get list of downloaded ayah numbers for a surah
  static Future<Set<int>> getDownloadedAyahsForSurah(
    String folder,
    int surahNum,
    int totalVerses,
  ) async {
    final Set<int> downloaded = {};
    for (int i = 1; i <= totalVerses; i++) {
      if (await isAyahDownloaded(folder, surahNum, i)) {
        downloaded.add(i);
      }
    }
    return downloaded;
  }

  // Download all ayahs of a surah concurrently in small batches
  // Only ayahs that genuinely succeed are recorded
  static Future<int> downloadAllAyahsOfSurah(
    String folder,
    int surahNum,
    int totalVerses,
    Function(double progress, int downloadedCount, int total) onProgress, {
    Function(int ayahNum)? onAyahSuccess,
  }) async {
    if (!await hasInternetConnection()) {
      return 0;
    }

    int downloadedCount = 0;
    int processed = 0;
    final int batchSize = 4;

    for (int i = 1; i <= totalVerses; i += batchSize) {
      final end = (i + batchSize - 1).clamp(1, totalVerses);
      final futures = <Future<MapEntry<int, String?>>>[];
      for (int j = i; j <= end; j++) {
        final ayah = j;
        futures.add(downloadAyahAudio(folder, surahNum, ayah).then((p) => MapEntry(ayah, p)));
      }
      final results = await Future.wait(futures);
      int batchSuccess = 0;
      for (final entry in results) {
        processed++;
        if (entry.value != null) {
          downloadedCount++;
          batchSuccess++;
          if (onAyahSuccess != null) {
            onAyahSuccess(entry.key);
          }
        }
      }
      onProgress(totalVerses > 0 ? processed / totalVerses : 0.0, downloadedCount, totalVerses);

      // If the entire batch failed, check if internet connection was lost
      if (batchSuccess == 0 && !await hasInternetConnection()) {
        break;
      }
    }
    return downloadedCount;
  }
}
