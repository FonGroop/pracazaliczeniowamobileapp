import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class StoredAttachment {
  const StoredAttachment({required this.name, required this.localPath});

  final String name;
  final String localPath;
}

class AttachmentOpenException implements Exception {
  const AttachmentOpenException(this.message);

  final String message;
}

abstract interface class AttachmentGateway {
  Future<StoredAttachment> persist({
    required XFile source,
    required String noteId,
  });

  Future<String> resolveLocalPath({required String name, String? localPath});

  Future<void> open(String localPath);

  Future<void> delete(String? localPath);
}

/// Keeps a private copy of selected files so later cloud sync does not depend
/// on the original file still existing at its selected location.
class AttachmentService implements AttachmentGateway {
  static const _attachmentChannel = MethodChannel('city_companion/attachments');

  AttachmentService({Future<Directory> Function()? appSupportDirectory})
    : _appSupportDirectory =
          appSupportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _appSupportDirectory;

  @override
  Future<StoredAttachment> persist({
    required XFile source,
    required String noteId,
  }) async {
    final appDirectory = await _appSupportDirectory();
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

  @override
  Future<String> resolveLocalPath({
    required String name,
    String? localPath,
  }) async {
    if (localPath != null) {
      final localFile = File(localPath);
      if (await localFile.exists()) return localFile.path;

      // Apple can assign a new sandbox prefix after an app update. The
      // app-managed filename stays stable, so rebuild it under the current
      // Application Support directory before declaring the file missing.
      final appDirectory = await _appSupportDirectory();
      final repairedFile = File(
        path.join(appDirectory.path, 'attachments', path.basename(localPath)),
      );
      if (await repairedFile.exists()) return repairedFile.path;
    }
    throw AttachmentOpenException(
      'The local attachment "$name" is no longer available on this device.',
    );
  }

  @override
  Future<void> open(String localPath) async {
    try {
      await _attachmentChannel.invokeMethod<void>('open', {'path': localPath});
    } on PlatformException catch (error) {
      throw AttachmentOpenException(
        error.message ?? 'The attachment could not be opened.',
      );
    } on MissingPluginException {
      throw const AttachmentOpenException(
        'Opening attachments is not supported on this platform.',
      );
    }
  }

  @override
  Future<void> delete(String? localPath) async {
    if (localPath == null) return;
    final file = File(localPath);
    if (await file.exists()) await file.delete();
  }
}
