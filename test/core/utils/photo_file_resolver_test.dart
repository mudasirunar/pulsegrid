import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsegrid/core/utils/photo_file_resolver.dart';

void main() {
  test('deleteUnreferencedPhotos deletes only unreferenced files inside incident_photos/', () async {
    final docsDir = await PhotoFileResolver.getDocsDir();
    final photosDir = Directory('${docsDir.path}/incident_photos');
    await photosDir.create(recursive: true);

    final unreferencedManaged = File('${photosDir.path}/test_unused_${DateTime.now().microsecondsSinceEpoch}.jpg');
    final referencedManaged = File('${photosDir.path}/test_used_${DateTime.now().microsecondsSinceEpoch}.jpg');
    final outsideFile = File('${docsDir.path}/test_outside_${DateTime.now().microsecondsSinceEpoch}.jpg');

    await unreferencedManaged.writeAsBytes([1, 2, 3]);
    await referencedManaged.writeAsBytes([4, 5, 6]);
    await outsideFile.writeAsBytes([7, 8, 9]);

    try {
      await PhotoFileResolver.deleteUnreferencedPhotos(
        candidatePaths: [
          unreferencedManaged.path,
          referencedManaged.path,
          outsideFile.path,
        ],
        stillReferencedPaths: [referencedManaged.path],
      );

      expect(await unreferencedManaged.exists(), isFalse);
      expect(await referencedManaged.exists(), isTrue);
      expect(await outsideFile.exists(), isTrue);
    } finally {
      if (await unreferencedManaged.exists()) await unreferencedManaged.delete();
      if (await referencedManaged.exists()) await referencedManaged.delete();
      if (await outsideFile.exists()) await outsideFile.delete();
    }
  });
}

