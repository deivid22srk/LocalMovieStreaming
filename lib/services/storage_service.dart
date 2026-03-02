import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';

class StorageService {
  Future<String?> exportData() async {
    final dbPath = join(await getDatabasesPath(), 'movie_streaming.db');
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) return null;

    final archive = Archive();

    // Add DB file to archive
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('movie_streaming.db', dbBytes.length, dbBytes));

    // Optional: add images if we had local image caching.
    // Since we use cached_network_image, it's simpler to just let it re-download for now
    // to keep the ZIP small, or if we want full offline, we'd add images here.

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData == null) return null;

    String? outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Exportar dados',
      fileName: 'local_movie_backup.zip',
    );

    if (outputPath != null) {
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(zipData);
      return outputPath;
    }
    return null;
  }

  Future<bool> importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        if (file.name == 'movie_streaming.db') {
          final dbPath = join(await getDatabasesPath(), 'movie_streaming.db');
          final dbFile = File(dbPath);
          await dbFile.writeAsBytes(file.content as List<int>);
          return true;
        }
      }
    }
    return false;
  }
}
