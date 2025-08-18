import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:device_info_plus/device_info_plus.dart';

class StoragePermissionManager {
  static Future<void> initAppPermissions() async {
    if (!Platform.isAndroid) return;

    final sdkInt = await _getAndroidVersion();
    print("Android SDK Version: $sdkInt");

    if (sdkInt >= 30) {
      // Android 11+ (API 30+)
      await _handleAndroid11Plus();
    } else if (sdkInt >= 23) {
      // Android 6-10 (API 23-29)
      await _handleLegacyAndroid();
    } else {
      // Android 5.1 and below (no runtime permissions)
      await _createPublicAppFolder();
    }
  }

  static Future<void> _handleAndroid11Plus() async {
    if (!await Permission.manageExternalStorage.isGranted) {
      // MANAGE_EXTERNAL_STORAGE permission ko check karne ka correct tarika
      print("Requesting MANAGE_EXTERNAL_STORAGE permission...");
      bool granted = await Permission.manageExternalStorage.isGranted;

      if (!granted) {
        // direct request() kaam nahi karta yaha, user ko manually settings kholna hota hai
        print("⚠️ All files permission not granted, opening app settings...");
        await openAppSettings();
        // user ko permission enable karna hoga manually
      }
    } else {
      print("✅ MANAGE_EXTERNAL_STORAGE permission already granted.");
    }

    // Ab folder create karo, permission milne ke baad
    await _createPublicAppFolder();
  }

  static Future<void> _handleLegacyAndroid() async {
    if (!await Permission.storage.isGranted) {
      print("Requesting STORAGE permission...");
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        print("⚠️ Storage permission denied, opening app settings...");
        await openAppSettings();
      } else {
        print("✅ Storage permission granted.");
      }
    } else {
      print("✅ Storage permission already granted.");
    }

    await _createPublicAppFolder();
  }

  static Future<void> _createPublicAppFolder() async {
    try {
      final folderName = "glite";

      Directory? baseDir;

      if (Platform.isAndroid) {
        // getExternalStorageDirectory will give internal app directory; to access public external storage root:
        baseDir = await getExternalStorageDirectory();

        if (baseDir == null) {
          print("❌ Unable to get external storage directory");
          return;
        }

        // Android ka path usually /storage/emulated/0/Android/data/package/files
        // Public folder create karne ke liye root external storage pe jana hai:
        // Eg: /storage/emulated/0/glite
        final paths = baseDir.path.split("/");
        // Remove Android/data/... part to get root external storage
        int androidIndex = paths.indexOf("Android");
        if (androidIndex > 0) {
          final rootPath = paths.sublist(0, androidIndex).join("/");
          baseDir = Directory(p.join(rootPath));
        }
      } else {
        baseDir = await getApplicationDocumentsDirectory();
      }

      final appFolder = Directory(p.join(baseDir.path, folderName));
      if (!await appFolder.exists()) {
        await appFolder.create(recursive: true);
        print("✅ Public folder created at: ${appFolder.path}");
      } else {
        print("📂 Folder already exists: ${appFolder.path}");
      }

      // .nomedia file to hide media scanning
      final noMediaFile = File(p.join(appFolder.path, ".nomedia"));
      if (!await noMediaFile.exists()) {
        await noMediaFile.writeAsString("");
        print("🖼️ Created .nomedia file");
      }

      // Call recordings folder
      final recordingsFolder = Directory(p.join(appFolder.path, "CallRecordings"));
      if (!await recordingsFolder.exists()) {
        await recordingsFolder.create(recursive: true);
        print("🎙️ Recordings folder created at: ${recordingsFolder.path}");
      }

    } catch (e) {
      print("❌ Error creating folders: $e");
    }
  }

  static Future<int> _getAndroidVersion() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt ?? 0;
    } catch (e) {
      print("⚠️ Error fetching Android SDK version: $e");
      return 0;
    }
  }
}
