
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../models/incident_model.dart';
import 'image_upload_service.dart';

class IncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageUploadService _imageUploadService = ImageUploadService();

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _firestore.collection('incidents');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  User _requireVerifiedUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to continue.');
    }

    if (!user.emailVerified) {
      throw StateError(
        'Please verify your email before reporting incidents.',
      );
    }

    return user;
  }

  Future<String> createIncident({
    required String title,
    required String description,
    required String category,
    required String location,
    XFile? image,
  }) async {
    final user = _requireVerifiedUser();

    if (title.trim().isEmpty ||
        description.trim().isEmpty ||
        category.trim().isEmpty ||
        location.trim().isEmpty) {
      throw ArgumentError('All incident details are required.');
    }

    final document = _incidents.doc();
    String? uploadedImagePath;

    if (image != null) {
      try {
        uploadedImagePath =
            await _imageUploadService.uploadIncidentImage(
          image: image,
          incidentId: document.id,
        );
      } catch (error) {
        throw StateError(
          'Image upload failed. Your incident was not submitted. $error',
        );
      }
    }

    try {
      final batch = _firestore.batch();

      batch.set(document, {
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'location': location.trim(),
        'status': 'Pending',
        'reporterId': user.uid,
        'reporterEmail': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'imageUrls': uploadedImagePath == null
            ? <String>[]
            : <String>[uploadedImagePath],
        'isPublic': false,
      });

      batch.set(
        _notifications.doc('${document.id}_submitted'),
        {
          'recipientId': user.uid,
          'incidentId': document.id,
          'title': 'Report submitted',
          'message':
              'Your incident report was submitted successfully.',
          'type': 'submitted',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (error) {
      throw StateError(
        'Unable to confirm incident submission. '
        'Check My Reports before trying again. $error',
      );
    }

    return document.id;
  }

  Stream<List<IncidentModel>> getMyIncidents() {
    final user = _requireVerifiedUser();

    return _incidents
        .where('reporterId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final incidents = snapshot.docs
          .map((doc) => IncidentModel.fromDocument(doc))
          .toList();

      incidents.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return incidents;
    });
  }

  Future<IncidentModel?> getIncidentById(String incidentId) async {
    final user = _requireVerifiedUser();
    final document = await _incidents.doc(incidentId).get();

    if (!document.exists) return null;

    final incident = IncidentModel.fromDocument(document);

    if (incident.reporterId != user.uid) {
      throw StateError(
        'You do not have permission to view this report.',
      );
    }

    return incident;
  }

  Future<void> updatePendingIncident({
    required String incidentId,
    required String title,
    required String description,
    required String category,
    required String location,
  }) async {
    final user = _requireVerifiedUser();
    final reference = _incidents.doc(incidentId);

    if (title.trim().isEmpty ||
        description.trim().isEmpty ||
        category.trim().isEmpty ||
        location.trim().isEmpty) {
      throw ArgumentError('All incident details are required.');
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Incident not found.');
      }

      final data = snapshot.data()!;

      if (data['reporterId'] != user.uid) {
        throw StateError(
          'You can only edit your own incidents.',
        );
      }

      if (data['status'] != 'Pending') {
        throw StateError(
          'Only pending incidents can be edited.',
        );
      }

      transaction.update(reference, {
        'title': title.trim(),
        'description': description.trim(),
        'category': category.trim(),
        'location': location.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelPendingIncident({
    required String incidentId,
  }) async {
    final user = _requireVerifiedUser();
    final reference = _incidents.doc(incidentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Incident not found.');
      }

      final data = snapshot.data()!;

      if (data['reporterId'] != user.uid) {
        throw StateError(
          'You can only cancel your own reports.',
        );
      }

      if (data['status'] != 'Pending') {
        throw StateError(
          'Only pending reports can be cancelled.',
        );
      }

      transaction.update(reference, {
        'status': 'Cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(
        _notifications.doc('${incidentId}_cancelled'),
        {
          'recipientId': user.uid,
          'incidentId': incidentId,
          'title': 'Report cancelled',
          'message': 'Your incident report has been cancelled.',
          'type': 'cancelled',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }

  Stream<Map<String, int>> getMyIncidentStats() {
    return getMyIncidents().map((incidents) {
      return {
        'total': incidents.length,
        'pending':
            incidents.where((i) => i.status == 'Pending').length,
        'inProgress':
            incidents.where((i) => i.status == 'In Progress').length,
        'resolved':
            incidents.where((i) => i.status == 'Resolved').length,
        'cancelled':
            incidents.where((i) => i.status == 'Cancelled').length,
      };
    });
  }
}
