import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/utils/photo_file_resolver.dart';

abstract class FirestoreRemoteDataSource {
  Future<void> pushIncident(Map<String, dynamic> incidentData);
  Future<void> pushResourceLog(Map<String, dynamic> resourceData);
  Future<void> pushActivityEvent(Map<String, dynamic> eventData);
  Future<void> deleteIncident(String incidentId);
  Future<List<Map<String, dynamic>>> pullIncidents();
  Future<List<Map<String, dynamic>>> pullResourceLogs({String? incidentId});
  Future<List<Map<String, dynamic>>> pullActivityEvents({String? incidentId});
  Future<Map<String, dynamic>?> getRemoteIncident(String incidentId);

  // Live WebSocket snapshot streams (zero polling, quota safe)
  Stream<List<Map<String, dynamic>>> watchIncidents();
  Stream<Map<String, dynamic>?> watchIncident(String incidentId);
  Stream<List<Map<String, dynamic>>> watchResourceLogs(String incidentId);
  Stream<List<Map<String, dynamic>>> watchActivityEvents(String incidentId);
}

class FirestoreRemoteDataSourceImpl implements FirestoreRemoteDataSource {
  final FirebaseFirestore firestore;
  final Map<String, String> _pushedPhotoSignatures = {};

  FirestoreRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _incidentsCol =>
      firestore.collection('incidents');
  CollectionReference<Map<String, dynamic>> get _resourcesCol =>
      firestore.collection('resource_logs');
  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      firestore.collection('activity_events');

  @override
  Future<void> pushIncident(Map<String, dynamic> incidentData) async {
    final docId = incidentData[DatabaseConstants.colId] as String;
    final copy = Map<String, dynamic>.from(incidentData);

    // Convert local photo paths to Base64 strings for zero-cost cloud sync on Spark tier
    final rawPhotos = copy[DatabaseConstants.colPhotoPath];
    List<String> photoPaths = [];
    if (rawPhotos is List) {
      photoPaths = rawPhotos.map((e) => e.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.isNotEmpty) {
      if (rawPhotos.startsWith('[')) {
        photoPaths = List<String>.from(
          rawPhotos
              .replaceAll('[', '')
              .replaceAll(']', '')
              .replaceAll('"', '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      } else {
        photoPaths = [rawPhotos];
      }
    }

    final photoSignature = photoPaths.join('|');
    if (photoPaths.isNotEmpty && _pushedPhotoSignatures[docId] != photoSignature) {
      final List<String> base64Photos = [];
      int totalChars = 0;
      const int maxTotalChars = 750000; // Keep well under Firestore 1 MiB document limit

      for (final path in photoPaths) {
        String? b64;
        if (path.length > 200 && !path.contains('/') && !path.contains('\\')) {
          b64 = path;
        } else {
          b64 = await PhotoFileResolver.photoPathToBase64(path);
        }
        if (b64 != null && (totalChars + b64.length) <= maxTotalChars) {
          base64Photos.add(b64);
          totalChars += b64.length;
        }
      }
      if (base64Photos.isNotEmpty) {
        copy['photoBase64s'] = base64Photos;
        _pushedPhotoSignatures[docId] = photoSignature;
      }
    }

    // Normalize timestamps
    copy['syncedAt'] = FieldValue.serverTimestamp();

    await _incidentsCol.doc(docId).set(copy, SetOptions(merge: true));
  }

  @override
  Future<void> pushResourceLog(Map<String, dynamic> resourceData) async {
    final docId = resourceData[DatabaseConstants.colId] as String;
    final copy = Map<String, dynamic>.from(resourceData);
    copy['syncedAt'] = FieldValue.serverTimestamp();
    await _resourcesCol.doc(docId).set(copy, SetOptions(merge: true));
  }

  @override
  Future<void> pushActivityEvent(Map<String, dynamic> eventData) async {
    final docId = eventData[DatabaseConstants.colId] as String;
    final copy = Map<String, dynamic>.from(eventData);
    copy['syncedAt'] = FieldValue.serverTimestamp();
    await _eventsCol.doc(docId).set(copy, SetOptions(merge: true));
  }

  @override
  Future<void> deleteIncident(String incidentId) async {
    await _incidentsCol.doc(incidentId).delete();
  }

  @override
  Future<List<Map<String, dynamic>>> pullIncidents() async {
    final snapshot = await _incidentsCol.get();
    final List<Map<String, dynamic>> results = [];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data[DatabaseConstants.colId] = doc.id;

      // Restore Base64 images to local files if present
      final b64List = data['photoBase64s'];
      if (b64List is List && b64List.isNotEmpty) {
        final List<String> localPaths = [];
        for (final item in b64List) {
          final b64String = item.toString();
          final localPath = await PhotoFileResolver.saveBase64Photo(b64String);
          if (localPath != null) {
            localPaths.add(localPath);
          }
        }
        if (localPaths.isNotEmpty) {
          data[DatabaseConstants.colPhotoPath] = localPaths;
        }
      }

      results.add(data);
    }

    return results;
  }

  @override
  Future<List<Map<String, dynamic>>> pullResourceLogs({String? incidentId}) async {
    Query<Map<String, dynamic>> query = _resourcesCol;
    if (incidentId != null) {
      query = query.where(DatabaseConstants.colIncidentId, isEqualTo: incidentId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data[DatabaseConstants.colId] = d.id;
      return data;
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> pullActivityEvents({String? incidentId}) async {
    Query<Map<String, dynamic>> query = _eventsCol;
    if (incidentId != null) {
      query = query.where(DatabaseConstants.colIncidentId, isEqualTo: incidentId);
    }
    final snapshot = await query.get();
    return snapshot.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data[DatabaseConstants.colId] = d.id;
      return data;
    }).toList();
  }

  @override
  Future<Map<String, dynamic>?> getRemoteIncident(String incidentId) async {
    final doc = await _incidentsCol.doc(incidentId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data[DatabaseConstants.colId] = doc.id;
    return data;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchIncidents() {
    return _incidentsCol.snapshots().asyncMap((snapshot) async {
      final List<Map<String, dynamic>> results = [];
      for (final doc in snapshot.docs) {
        try {
          // Ignore local pending writes to prevent loop echoes
          if (doc.metadata.hasPendingWrites) continue;

          final data = Map<String, dynamic>.from(doc.data());
          data[DatabaseConstants.colId] = doc.id;

          // Restore Base64 images to local files if present
          final b64List = data['photoBase64s'];
          if (b64List is List && b64List.isNotEmpty) {
            final List<String> localPaths = [];
            for (final item in b64List) {
              final b64String = item.toString();
              final localPath = await PhotoFileResolver.saveBase64Photo(b64String);
              if (localPath != null) {
                localPaths.add(localPath);
              }
            }
            if (localPaths.isNotEmpty) {
              data[DatabaseConstants.colPhotoPath] = localPaths;
            }
          }

          results.add(data);
        } catch (_) {}
      }
      return results;
    });
  }

  @override
  Stream<Map<String, dynamic>?> watchIncident(String incidentId) {
    return _incidentsCol.doc(incidentId).snapshots().asyncMap((doc) async {
      try {
        if (!doc.exists || doc.data() == null) return null;
        if (doc.metadata.hasPendingWrites) return null;

        final data = Map<String, dynamic>.from(doc.data()!);
        data[DatabaseConstants.colId] = doc.id;

        final b64List = data['photoBase64s'];
        if (b64List is List && b64List.isNotEmpty) {
          final List<String> localPaths = [];
          for (final item in b64List) {
            final b64String = item.toString();
            final localPath = await PhotoFileResolver.saveBase64Photo(b64String);
            if (localPath != null) {
              localPaths.add(localPath);
            }
          }
          if (localPaths.isNotEmpty) {
            data[DatabaseConstants.colPhotoPath] = localPaths;
          }
        }

        return data;
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> watchResourceLogs(String incidentId) {
    return _resourcesCol
        .where(DatabaseConstants.colIncidentId, isEqualTo: incidentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((d) => !d.metadata.hasPendingWrites)
          .map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data[DatabaseConstants.colId] = d.id;
        return data;
      }).toList();
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> watchActivityEvents(String incidentId) {
    return _eventsCol
        .where(DatabaseConstants.colIncidentId, isEqualTo: incidentId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .where((d) => !d.metadata.hasPendingWrites)
          .map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data[DatabaseConstants.colId] = docId(d);
        return data;
      }).toList();
    });
  }

  String docId(DocumentSnapshot doc) => doc.id;
}
