import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/database/database_constants.dart';
import '../../../../core/utils/photo_file_resolver.dart';

class IncidentRemotelyDeletedException implements Exception {
  final String incidentId;
  const IncidentRemotelyDeletedException(this.incidentId);

  @override
  String toString() => 'Incident $incidentId was deleted remotely.';
}

abstract class FirestoreRemoteDataSource {
  Future<void> pushIncident(Map<String, dynamic> incidentData, {bool isUpdate = false});
  Future<void> pushResourceLog(Map<String, dynamic> resourceData);
  Future<void> pushActivityEvent(Map<String, dynamic> eventData);
  Future<void> pushAssignment(Map<String, dynamic> assignmentData);
  Future<void> deleteIncident(String incidentId);
  Future<List<Map<String, dynamic>>> pullIncidents();
  Future<Set<String>> pullDeletedIncidentIds();
  Future<List<Map<String, dynamic>>> pullResourceLogs({String? incidentId});
  Future<List<Map<String, dynamic>>> pullActivityEvents({String? incidentId});
  Future<List<Map<String, dynamic>>> pullAssignments({String? incidentId});
  Future<List<Map<String, dynamic>>> fetchResponders();
  Future<Map<String, dynamic>?> getRemoteIncident(String incidentId);

  // Live WebSocket snapshot streams (zero polling, quota safe)
  Stream<List<Map<String, dynamic>>> watchIncidents();
  Stream<String> watchRemovedIncidentIds();
  Stream<List<String>> watchDeletedIncidentIds();
  Stream<List<Map<String, dynamic>>> watchAllAssignments();
  Stream<Map<String, dynamic>?> watchIncident(String incidentId);
  Stream<List<Map<String, dynamic>>> watchResourceLogs(String incidentId);
  Stream<List<Map<String, dynamic>>> watchActivityEvents(String incidentId);
  Stream<List<Map<String, dynamic>>> watchAssignments(String incidentId);
}

class FirestoreRemoteDataSourceImpl implements FirestoreRemoteDataSource {
  final FirebaseFirestore firestore;
  final Map<String, String> _pushedPhotoSignatures = {};

  FirestoreRemoteDataSourceImpl({required this.firestore});

  CollectionReference<Map<String, dynamic>> get _incidentsCol =>
      firestore.collection('incidents');
  CollectionReference<Map<String, dynamic>> get _deletedIncidentsCol =>
      firestore.collection('deleted_incidents');
  CollectionReference<Map<String, dynamic>> get _resourcesCol =>
      firestore.collection('resource_logs');
  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      firestore.collection('activity_events');
  CollectionReference<Map<String, dynamic>> get _assignmentsCol =>
      firestore.collection('assignments');
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      firestore.collection('users');

  DateTime? _parseUtcTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate().toUtc();
    if (raw is DateTime) return raw.toUtc();
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw)?.toUtc();
    }
    return null;
  }

  @override
  Future<void> pushIncident(
    Map<String, dynamic> incidentData, {
    bool isUpdate = false,
  }) async {
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
    if (photoPaths.isEmpty) {
      copy['photoBase64s'] = const <String>[];
      _pushedPhotoSignatures.remove(docId);
    } else if (_pushedPhotoSignatures[docId] != photoSignature) {
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

    final docRef = _incidentsCol.doc(docId);
    final deletedRef = _deletedIncidentsCol.doc(docId);

    await firestore.runTransaction((tx) async {
      // 1. Delete Always Wins: abort if a tombstone exists
      final deletedSnap = await tx.get(deletedRef);
      if (deletedSnap.exists) {
        throw IncidentRemotelyDeletedException(docId);
      }

      // 2. Check existing incident for delete-wins & Last-Write-Wins
      final existingSnap = await tx.get(docRef);
      if (isUpdate && !existingSnap.exists) {
        throw IncidentRemotelyDeletedException(docId);
      }

      if (existingSnap.exists && existingSnap.data() != null) {
        final remoteUpdated = _parseUtcTimestamp(
          existingSnap.data()![DatabaseConstants.colUpdatedAt],
        );
        final incomingUpdated = _parseUtcTimestamp(
          copy[DatabaseConstants.colUpdatedAt],
        );
        if (remoteUpdated != null &&
            incomingUpdated != null &&
            remoteUpdated.isAfter(incomingUpdated)) {
          // Remote already has a newer edit (Last-Write-Wins) -> keep remote
          return;
        }
      }

      tx.set(docRef, copy, SetOptions(merge: true));
    });
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
  Future<void> pushAssignment(Map<String, dynamic> assignmentData) async {
    final docId = assignmentData[DatabaseConstants.colId] as String;
    final copy = Map<String, dynamic>.from(assignmentData);
    copy['syncedAt'] = FieldValue.serverTimestamp();
    await _assignmentsCol.doc(docId).set(copy, SetOptions(merge: true));
  }

  @override
  Future<void> deleteIncident(String incidentId) async {
    // 1. Write lightweight (~50-byte) tombstone first so concurrent/offline
    //    edits cannot resurrect the incident after hard deletion.
    await _deletedIncidentsCol.doc(incidentId).set({
      'deletedAt': FieldValue.serverTimestamp(),
    });

    // 2. Hard-delete the incident document (frees all photo & field storage)
    await _incidentsCol.doc(incidentId).delete();
    _pushedPhotoSignatures.remove(incidentId);

    // 3. Clean up related resource_logs and activity_events in Firestore
    try {
      final resSnap = await _resourcesCol
          .where(DatabaseConstants.colIncidentId, isEqualTo: incidentId)
          .get();
      for (final d in resSnap.docs) {
        await d.reference.delete();
      }
      final evtSnap = await _eventsCol
          .where(DatabaseConstants.colIncidentId, isEqualTo: incidentId)
          .get();
      for (final d in evtSnap.docs) {
        await d.reference.delete();
      }
      final assignSnap = await _assignmentsCol
          .where(DatabaseConstants.colIncidentId, isEqualTo: incidentId)
          .get();
      for (final d in assignSnap.docs) {
        await d.reference.delete();
      }
    } catch (_) {
      // Best-effort cleanup of related logs/events/assignments
    }
  }

  @override
  Future<Set<String>> pullDeletedIncidentIds() async {
    final snapshot = await _deletedIncidentsCol.get();
    return snapshot.docs.map((d) => d.id).toSet();
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
  Future<List<Map<String, dynamic>>> pullAssignments({String? incidentId}) async {
    Query<Map<String, dynamic>> query = _assignmentsCol;
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
  Future<List<Map<String, dynamic>>> fetchResponders() async {
    final snapshot =
        await _usersCol.where('role', isEqualTo: 'responder').get();
    return snapshot.docs.map((d) {
      final data = Map<String, dynamic>.from(d.data());
      data['id'] = d.id;
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
  Stream<String> watchRemovedIncidentIds() {
    return _incidentsCol.snapshots().expand((snapshot) {
      return snapshot.docChanges
          .where((change) =>
              change.type == DocumentChangeType.removed &&
              !change.doc.metadata.hasPendingWrites)
          .map((change) => change.doc.id);
    });
  }

  @override
  Stream<List<String>> watchDeletedIncidentIds() {
    return _deletedIncidentsCol.snapshots().map((snapshot) {
      return snapshot.docs
          .where((d) => !d.metadata.hasPendingWrites)
          .map((d) => d.id)
          .toList();
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

  @override
  Stream<List<Map<String, dynamic>>> watchAllAssignments() {
    return _assignmentsCol.snapshots().map((snapshot) {
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
  Stream<List<Map<String, dynamic>>> watchAssignments(String incidentId) {
    return _assignmentsCol
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

  String docId(DocumentSnapshot doc) => doc.id;
}
