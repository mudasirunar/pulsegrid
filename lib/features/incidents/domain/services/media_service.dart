import 'package:image_picker/image_picker.dart';

abstract class MediaService {
  Future<String?> pickImageFromCamera();
  Future<String?> pickImageFromGallery();
  Future<List<String>> pickMultipleImagesFromGallery({int maxImages = 5});
}

class MediaServiceImpl implements MediaService {
  final ImagePicker _picker;

  MediaServiceImpl({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

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
