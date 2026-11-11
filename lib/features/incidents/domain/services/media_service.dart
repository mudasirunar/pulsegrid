import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum MediaPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

typedef CameraPermissionStatus = MediaPermissionStatus;

abstract class MediaService {
  Future<MediaPermissionStatus> checkCameraPermission();
  Future<MediaPermissionStatus> requestCameraPermission();
  Future<MediaPermissionStatus> checkGalleryPermission();
  Future<MediaPermissionStatus> requestGalleryPermission();
  Future<bool> shouldShowCameraRationale();
  Future<bool> shouldShowGalleryRationale();
  Future<bool> openAppSettings();
  Future<String?> pickImageFromCamera();
  Future<String?> pickImageFromGallery();
  Future<List<String>> pickMultipleImagesFromGallery({int maxImages = 5});
}

class MediaServiceImpl implements MediaService {
  final ImagePicker _picker;

  MediaServiceImpl({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  @override
  Future<MediaPermissionStatus> checkCameraPermission() async {
    final status = await ph.Permission.camera.status;
    if (status.isGranted || status.isLimited) {
      return MediaPermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    } else {
      return MediaPermissionStatus.denied;
    }
  }

  @override
  Future<MediaPermissionStatus> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    if (status.isGranted || status.isLimited) {
      return MediaPermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    } else {
      return MediaPermissionStatus.denied;
    }
  }

  @override
  Future<MediaPermissionStatus> checkGalleryPermission() async {
    final photoStatus = await ph.Permission.photos.status;
    if (photoStatus.isGranted || photoStatus.isLimited) {
      return MediaPermissionStatus.granted;
    }
    if (photoStatus.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    }

    if (Platform.isAndroid) {
      final storageStatus = await ph.Permission.storage.status;
      if (storageStatus.isGranted || storageStatus.isLimited) {
        return MediaPermissionStatus.granted;
      }
      if (storageStatus.isPermanentlyDenied &&
          photoStatus != ph.PermissionStatus.denied) {
        return MediaPermissionStatus.permanentlyDenied;
      }
    }

    return MediaPermissionStatus.denied;
  }

  @override
  Future<MediaPermissionStatus> requestGalleryPermission() async {
    final photoStatus = await ph.Permission.photos.request();
    if (photoStatus.isGranted || photoStatus.isLimited) {
      return MediaPermissionStatus.granted;
    }
    if (photoStatus.isPermanentlyDenied) {
      return MediaPermissionStatus.permanentlyDenied;
    }

    if (Platform.isAndroid) {
      final storageStatus = await ph.Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        return MediaPermissionStatus.granted;
      }
      if (storageStatus.isPermanentlyDenied &&
          photoStatus != ph.PermissionStatus.denied) {
        return MediaPermissionStatus.permanentlyDenied;
      }
    }

    return MediaPermissionStatus.denied;
  }

  @override
  Future<bool> shouldShowCameraRationale() async {
    if (Platform.isAndroid) {
      return await ph.Permission.camera.shouldShowRequestRationale;
    }
    return false;
  }

  @override
  Future<bool> shouldShowGalleryRationale() async {
    if (Platform.isAndroid) {
      final photos = await ph.Permission.photos.shouldShowRequestRationale;
      final storage = await ph.Permission.storage.shouldShowRequestRationale;
      return photos || storage;
    }
    return false;
  }

  @override
  Future<bool> openAppSettings() async {
    return await ph.openAppSettings();
  }

  @override
  Future<String?> pickImageFromCamera() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      return photo?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> pickImageFromGallery() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      return image?.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<String>> pickMultipleImagesFromGallery({int maxImages = 5}) async {
    try {
      final images = await _picker.pickMultiImage(
        limit: maxImages,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      return images.map((x) => x.path).toList();
    } catch (_) {
      return [];
    }
  }
}
