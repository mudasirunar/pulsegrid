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
}

class FirestoreRemoteDataSourceImpl implements FirestoreRemoteDataSource {
  final FirebaseFirestore firestore;

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

    final List<String> base64Photos = [];
    for (final path in photoPaths) {
      if (path.length > 200 && !path.contains('/') && !path.contains('\\')) {
        // Already a base64 string
        base64Photos.add(path);
      } else {
        final b64 = await PhotoFileResolver.photoPathToBase64(path);
        if (b64 != null) {
          base64Photos.add(b64);
        }
      }
    }
    copy['photoBase64s'] = base64Photos;

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
}
