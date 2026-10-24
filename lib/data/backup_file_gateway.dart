import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// User-initiated file access. No permission is requested and no file is
/// opened until the platform picker returns an explicit user choice.
abstract interface class BackupFileGateway {
  Future<String?> readBackup();
  Future<bool> writeText(String fileName, String text, {String? mimeType});
}

final class FilePickerBackupGateway implements BackupFileGateway {
  const FilePickerBackupGateway();

  @override
  Future<String?> readBackup() async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose a Bed Ledger backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty) return null;
    final bytes = await picked.single.readAsBytes();
    return utf8.decode(bytes);
  }

  @override
  Future<bool> writeText(
    String fileName,
    String text, {
    String? mimeType,
  }) async {
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: mimeType ?? 'application/octet-stream',
    );
    return saved != null;
  }
}
