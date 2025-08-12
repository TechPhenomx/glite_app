// lib/core/storage_permission_helper.dart

import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StoragePermissionHelper {
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await _isAndroid11Plus()) {
      bool hasPermission = await Permission.manageExternalStorage.isGranted;
      if (!hasPermission) {
        bool opened = await openAppSettings();
        print('Opened app settings: $opened');
        return false;
      }
      return true;
    } else {
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        var result = await Permission.storage.request();
        return result.isGranted;
      }
      return true;
    }
  }

  static Future<void> createFolderInExternalStorage() async {
    if (!Platform.isAndroid) return;

    String folderName = 'glite';
    String basePath = '/storage/emulated/0';

    final fullPath = p.join(basePath, folderName);
    final dir = Directory(fullPath);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
      print('Folder created at: $fullPath');
    } else {
      print('Folder already exists at: $fullPath');
    }
  }

  static Future<bool> _isAndroid11Plus() async {
    try {
      var sdkInt = int.parse(
          (Platform.version.split(' ')[0]).split('.')[0]);
      return sdkInt >= 30;
    } catch (e) {
      return false;
    }
  }
}
