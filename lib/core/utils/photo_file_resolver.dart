import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PhotoFileResolver {
  static Directory? _cachedDocsDir;

  static Future<Directory> initialize() async {
    return await getDocsDir();
  }

  static Future<Directory> getDocsDir() async {
    if (_cachedDocsDir != null) return _cachedDocsDir!;
    try {
      _cachedDocsDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      _cachedDocsDir = Directory.systemTemp;
    }
    return _cachedDocsDir!;
  }

  /// Synchronously resolves a photo path to a valid, existing File.
  /// Handles iOS sandbox container UUID changes across app launches by falling back
  /// to the current documents directory using the relative subpath or filename.
  static File? resolveLocalFile(String rawPath) {
    var clean = rawPath.trim();
    if (clean.isEmpty) return null;
    if (clean.startsWith('http://') || clean.startsWith('https://')) return null;

    // Strip file:// URI scheme if present
    if (clean.startsWith('file://')) {
      clean = clean.replaceFirst('file://', '');
    }

    // 1. Direct path check (works when container UUID hasn't changed or on Android)
    final direct = File(clean);
    if (direct.existsSync()) return direct;

    // 2. Relative subpath check (e.g. incident_photos/evidence_....jpg)
    final docsDir = _cachedDocsDir;
    if (docsDir != null) {
      if (clean.contains('incident_photos/')) {
        final subpath = clean.substring(clean.indexOf('incident_photos/'));
        final subFile = File('${docsDir.path}/$subpath');
        if (subFile.existsSync()) return subFile;
      }

      // 3. Basename check in incident_photos directory
      final filename = clean.contains('/') ? clean.split('/').last : clean;
      final photoFile = File('${docsDir.path}/incident_photos/$filename');
      if (photoFile.existsSync()) return photoFile;

      // 4. Basename check in root documents directory
      final rootFile = File('${docsDir.path}/$filename');
      if (rootFile.existsSync()) return rootFile;
    }

    return null;
  }

  /// Copies a temporary/picked file into the app's permanent documents storage
  /// so it persists across app restarts, reboots, and OS cache cleans.
  static Future<String> persistPickedFile(String tempPath) async {
    try {
      var sourcePath = tempPath.trim();
      if (sourcePath.startsWith('file://')) {
        sourcePath = sourcePath.replaceFirst('file://', '');
      }

      final docsDir = await getDocsDir();
      final photosDir = Directory('${docsDir.path}/incident_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
      final fileName = 'evidence_${DateTime.now().millisecondsSinceEpoch}_${sourcePath.hashCode.abs()}.$ext';
      final destFile = File('${photosDir.path}/$fileName');

      final source = File(sourcePath);
      if (await source.exists()) {
        await source.copy(destFile.path);
        return destFile.path;
      }
      return tempPath;
    } catch (_) {
      return tempPath;
    }
  }

  /// Converts a local photo file path to a Base64 string for zero-cost Firestore sync.
  static Future<String?> photoPathToBase64(String path) async {
    try {
      final file = resolveLocalFile(path);
      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        return base64Encode(bytes);
      }
    } catch (_) {}
    return null;
  }

  /// Saves a remote Base64 image payload into local permanent documents storage
  /// and returns the local file path.
  static Future<String?> saveBase64Photo(String base64String) async {
    try {
      final bytes = base64Decode(base64String);
      final docsDir = await getDocsDir();
      final photosDir = Directory('${docsDir.path}/incident_photos');
      if (!await photosDir.exists()) {
        await photosDir.create(recursive: true);
      }
      final fileName =
          'evidence_remote_${DateTime.now().millisecondsSinceEpoch}_${base64String.hashCode.abs()}.jpg';
      final file = File('${photosDir.path}/$fileName');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
