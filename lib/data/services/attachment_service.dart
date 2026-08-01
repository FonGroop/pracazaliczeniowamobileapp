import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class StoredAttachment {
  const StoredAttachment({required this.name, required this.localPath});

  final String name;
  final String localPath;
}

/// Keeps a private copy of selected files so later cloud sync does not depend
/// on the original file still existing at its selected location.
class AttachmentService {
  Future<StoredAttachment> persist({
    required XFile source,
    required String noteId,
  }) async {
    final appDirectory = await getApplicationSupportDirectory();
    final directory = Directory(path.join(appDirectory.path, 'attachments'));
    await directory.create(recursive: true);

    final extension = path.extension(source.name);
    final destination = path.join(
      directory.path,
      '$noteId-${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await source.saveTo(destination);
    return StoredAttachment(
      name: path.basename(source.name),
      localPath: destination,
    );
  }

  Future<void> delete(String? localPath) async {
    if (localPath == null) return;
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }
}
