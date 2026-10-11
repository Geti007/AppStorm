import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The system share sheet and file picker.
abstract class DeviceFiles {
  Future<void> shareText(String text, {String? subject});

  Future<void> shareFile(Uint8List bytes, String fileName, String mimeType);

  /// Lets the user choose a file; null when they cancel.
  Future<Uint8List?> pickFile();
}

class SystemFiles implements DeviceFiles {
  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  @override
  Future<void> shareFile(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
    );
  }

  @override
  Future<Uint8List?> pickFile() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    return files.first.readAsBytes();
  }
}
