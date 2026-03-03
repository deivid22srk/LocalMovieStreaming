import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

class StorageService {
  Future<String?> generateZip() async {
    final dbPath = p.join(await getDatabasesPath(), 'movie_streaming.db');
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) return null;

    final archive = Archive();

    // Add DB file to archive
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('movie_streaming.db', dbBytes.length, dbBytes));

    // Add local images to archive
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (imagesDir.existsSync()) {
      final imageFiles = imagesDir.listSync();
      for (final file in imageFiles) {
        if (file is File) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('images/${p.basename(file.path)}', bytes.length, bytes));
        }
      }
    }

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData == null) return null;

    try {
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'local_movie_backup.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);
      return zipPath;
    } catch (e) {
      return null;
    }
  }

  Future<String?> exportData() async {
    final dbPath = p.join(await getDatabasesPath(), 'movie_streaming.db');
    final dbFile = File(dbPath);

    if (!dbFile.existsSync()) return 'Database file not found';

    final archive = Archive();

    // Add DB file to archive
    final dbBytes = await dbFile.readAsBytes();
    archive.addFile(ArchiveFile('movie_streaming.db', dbBytes.length, dbBytes));

    // Add local images to archive
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'images'));
    if (imagesDir.existsSync()) {
      final imageFiles = imagesDir.listSync();
      for (final file in imageFiles) {
        if (file is File) {
          final bytes = await file.readAsBytes();
          archive.addFile(ArchiveFile('images/${p.basename(file.path)}', bytes.length, bytes));
        }
      }
    }

    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);

    if (zipData == null) return 'Zip encoding failed';

    try {
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'local_movie_backup.zip');
      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipData);

      // Using Share is much more reliable on modern Android than direct path writing
      // and it allows the user to save to Google Drive, Telegram, or any SAF folder.
      await Share.shareXFiles([XFile(zipPath)], text: 'Backup Local Movie Player');

      return 'Compartilhado com sucesso';
    } catch (e) {
       return 'Error during export: $e';
    }
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

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'images'));
      if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);

      for (final file in archive) {
        if (file.name == 'movie_streaming.db') {
          final dbPath = p.join(await getDatabasesPath(), 'movie_streaming.db');
          final dbFile = File(dbPath);
          await dbFile.writeAsBytes(file.content as List<int>);
        } else if (file.name.startsWith('images/')) {
          final fileName = p.basename(file.name);
          final imgFile = File(p.join(imagesDir.path, fileName));
          await imgFile.writeAsBytes(file.content as List<int>);
        }
      }
      return true;
    }
    return false;
  }

  Future<String?> backupToTelegram(String botToken, String chatId) async {
    try {
      final zipPath = await generateZip();
      if (zipPath == null) return 'Erro ao gerar ZIP';

      final file = File(zipPath);
      final request = http.MultipartRequest('POST', Uri.parse('https://api.telegram.org/bot$botToken/sendDocument'));
      request.fields['chat_id'] = chatId;
      request.fields['caption'] = 'Backup Local Movie Player - ${DateTime.now()}';
      request.files.add(await http.MultipartFile.fromPath('document', file.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        return 'Backup enviado para o Telegram com sucesso!';
      } else {
        final body = await response.stream.bytesToString();
        return 'Erro no envio: ${response.statusCode} - $body';
      }
    } catch (e) {
      return 'Erro: $e';
    }
  }
}
