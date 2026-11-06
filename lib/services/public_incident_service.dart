
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PublicIncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _publicIncidents =>
      _firestore.collection('public_incidents');

  static const Set<String> _allowedCategories = {
    'Facilities',
    'Safety',
    'Maintenance',
    'Other',
  };

  static const Set<String> _allowedStatuses = {
    'Pending',
    'In Progress',
    'Resolved',
  };

  // ============================================
  // STAFF AUTHORIZATION
  // ============================================

  Future<User> _requireStaff() async {
    final user = _auth.currentUser;

    if (user == null || !user.emailVerified) {
      throw StateError(
        'A verified staff account is required.',
      );
    }

    final token = await user.getIdTokenResult(true);

    final isStaff =
        token.claims?['user_role'] == 'staff' ||
        (user.email
                ?.toLowerCase()
                .endsWith('@alueducation.com') ??
            false);

    if (!isStaff) {
      throw StateError(
        'Only authorized staff can manage announcements.',
      );
    }

    return user;
  }

  // ============================================
  // VALIDATE ANNOUNCEMENT CONTENT
  // ============================================

  void _validateContent({
    required String title,
    required String summary,
    required String category,
  }) {
    if (title.trim().isEmpty ||
        summary.trim().isEmpty) {
      throw ArgumentError(
        'An announcement title and message are required.',
      );
    }

    if (title.trim().length > 120) {
      throw ArgumentError(
        'The title cannot exceed 120 characters.',
      );
    }

    if (summary.trim().length > 1000) {
      throw ArgumentError(
        'The message cannot exceed 1000 characters.',
      );
    }

    if (!_allowedCategories.contains(category)) {
      throw ArgumentError(
        'Invalid announcement category.',
      );
    }
  }

  // ============================================
  // CREATE ANNOUNCEMENT
  // ============================================

  Future<String> createAnnouncement({
    required String title,
    required String summary,
    required String category,
    bool publishNow = false,
  }) async {
    final user = await _requireStaff();

    _validateContent(
      title: title,
      summary: summary,
      category: category,
    );

    final document = await _publicIncidents.add({
      'title': title.trim(),
      'summary': summary.trim(),
      'category': category,
      'published': publishNow,
      'lifecycleStatus':
          publishNow ? 'published' : 'draft',
      'publishedAt': publishNow
          ? FieldValue.serverTimestamp()
          : null,
      'publishedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  // ============================================
  // LEGACY INCIDENT-BASED PUBLISHING
  // ============================================

  Future<void> publishIncident({
    required String incidentId,
    required String title,
    required String summary,
    required String category,
    required String status,
  }) async {
    final user = await _requireStaff();

    _validateContent(
      title: title,
      summary: summary,
      category: category,
    );

    if (!_allowedStatuses.contains(status)) {
      throw ArgumentError(
        'Invalid incident status.',
      );
    }

    final incidentSnapshot = await _firestore
        .collection('incidents')
        .doc(incidentId)
        .get();

    if (!incidentSnapshot.exists) {
      throw StateError(
        'The original incident was not found.',
      );
    }

    final currentStatus =
        incidentSnapshot.data()?['status'];

    if (currentStatus == 'Cancelled') {
      throw StateError(
        'Cancelled incidents cannot be published.',
      );
    }

    if (currentStatus != status) {
      throw StateError(
        'The incident status has changed. '
        'Please reopen the report and try again.',
      );
    }

    await _publicIncidents.add({
      'title': title.trim(),
      'summary': summary.trim(),
      'category': category,
      'status': status,
      'published': true,
      'lifecycleStatus': 'published',
      'publishedAt': FieldValue.serverTimestamp(),
      'publishedBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================
  // READ ALL ANNOUNCEMENTS - STAFF
  // ============================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getAllAnnouncements() {
    return _publicIncidents
        .orderBy('publishedAt', descending: true)
        .snapshots();
  }

  // ============================================
  // READ PUBLISHED ANNOUNCEMENTS
  // ============================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getPublishedAnnouncements() {
    return _publicIncidents
        .where('published', isEqualTo: true)
        .orderBy('publishedAt', descending: true)
        .snapshots();
  }

  // ============================================
  // UPDATE ANNOUNCEMENT
  // ============================================

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String summary,
    required String category,
  }) async {
    await _requireStaff();

    _validateContent(
      title: title,
      summary: summary,
      category: category,
    );

    final document =
        _publicIncidents.doc(announcementId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError(
          'Announcement not found.',
        );
      }

      final data = snapshot.data()!;

      // Older announcements may not have lifecycleStatus.
      // Convert them to the current format when edited.
      final bool isPublished =
          data['published'] == true;

      final existingLifecycle =
          data['lifecycleStatus'];

      String lifecycleStatus;

      if (existingLifecycle == 'draft' ||
          existingLifecycle == 'published' ||
          existingLifecycle == 'unpublished') {
        lifecycleStatus =
            existingLifecycle as String;
      } else {
        lifecycleStatus = isPublished
            ? 'published'
            : 'unpublished';
      }

      transaction.update(document, {
        'title': title.trim(),
        'summary': summary.trim(),
        'category': category,
        'lifecycleStatus': lifecycleStatus,
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================
  // PUBLISH / REPUBLISH ANNOUNCEMENT
  // ============================================

  Future<void> publishAnnouncement(
    String announcementId,
  ) async {
    await _requireStaff();

    final document =
        _publicIncidents.doc(announcementId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError(
          'Announcement not found.',
        );
      }

      final data = snapshot.data()!;

      if (data['published'] == true) {
        throw StateError(
          'This announcement is already published.',
        );
      }

      transaction.update(document, {
        'published': true,
        'lifecycleStatus': 'published',
        'publishedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================
  // UNPUBLISH ANNOUNCEMENT
  // ============================================

  Future<void> unpublishAnnouncement(
    String announcementId,
  ) async {
    await _requireStaff();

    final document =
        _publicIncidents.doc(announcementId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);

      if (!snapshot.exists) {
        throw StateError(
          'Announcement not found.',
        );
      }

      final data = snapshot.data()!;

      if (data['published'] != true) {
        throw StateError(
          'This announcement is not published.',
        );
      }

      transaction.update(document, {
        'published': false,
        'lifecycleStatus': 'unpublished',
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================
  // DELETE ANNOUNCEMENT
  // ============================================

  Future<void> deleteAnnouncement(
    String announcementId,
  ) async {
    await _requireStaff();

    await _publicIncidents
        .doc(announcementId)
        .delete();
  }
}
