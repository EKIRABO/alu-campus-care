
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/incident_model.dart';

class StaffIncidentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _incidents =>
      _firestore.collection('incidents');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  // Check that the current user has a trusted staff role.
  Future<User> _requireStaff() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to continue.');
    }

    if (!user.emailVerified) {
      throw StateError('Please verify your email first.');
    }

    final tokenResult = await user.getIdTokenResult();

    if (tokenResult.claims?['user_role'] != 'staff') {
      throw StateError(
        'You do not have permission to manage incidents.',
      );
    }

    return user;
  }

  // READ: Stream all student incidents.
  Stream<List<IncidentModel>> getAllIncidents() async* {
    await _requireStaff();

    yield* _incidents.snapshots().map((snapshot) {
      final incidents = snapshot.docs
          .map((doc) => IncidentModel.fromDocument(doc))
          .toList();

      incidents.sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return incidents;
    });
  }

  // READ: Stream incidents matching a particular status.
  Stream<List<IncidentModel>> getIncidentsByStatus(
    String status,
  ) {
    return getAllIncidents().map((incidents) {
      if (status == 'All') {
        return incidents;
      }

      return incidents
          .where((incident) => incident.status == status)
          .toList();
    });
  }

  // READ: Calculate live staff dashboard statistics.
  Stream<Map<String, int>> getIncidentStats() {
    return getAllIncidents().map((incidents) {
      return {
        'total': incidents.length,

        'pending': incidents
            .where((incident) => incident.status == 'Pending')
            .length,

        'inProgress': incidents
            .where((incident) => incident.status == 'In Progress')
            .length,

        'resolved': incidents
            .where((incident) => incident.status == 'Resolved')
            .length,

        'cancelled': incidents
            .where((incident) => incident.status == 'Cancelled')
            .length,
      };
    });
  }

  // UPDATE: Staff change an incident's status
  // and notify its student in the same transaction.
  Future<void> updateIncidentStatus({
    required String incidentId,
    required String newStatus,
  }) async {
    final staffUser = await _requireStaff();

    const allowedStatuses = {
      'Pending',
      'In Progress',
      'Resolved',
    };

    if (!allowedStatuses.contains(newStatus)) {
      throw ArgumentError('Invalid incident status.');
    }

    final reference = _incidents.doc(incidentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Incident not found.');
      }

      final data = snapshot.data()!;
      final currentStatus = data['status'];
      final reporterId = data['reporterId'] as String?;

      if (reporterId == null || reporterId.isEmpty) {
        throw StateError('Incident reporter not found.');
      }

      if (currentStatus == 'Resolved') {
        throw StateError(
          'Resolved incidents cannot be modified.',
        );
      }

      final validTransition =
          (currentStatus == 'Pending' &&
              newStatus == 'In Progress') ||
          (currentStatus == 'In Progress' &&
              newStatus == 'Resolved');

      if (!validTransition) {
        throw StateError(
          'Invalid status transition: '
          '$currentStatus to $newStatus.',
        );
      }

      transaction.update(reference, {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedBy': staffUser.uid,
      });

      final isInProgress = newStatus == 'In Progress';

      final notificationType =
          isInProgress ? 'in_progress' : 'resolved';

      transaction.set(
        _notifications.doc(
          '${incidentId}_$notificationType',
        ),
        {
          'recipientId': reporterId,
          'incidentId': incidentId,
          'title': isInProgress
              ? 'Report in progress'
              : 'Report resolved',
          'message': isInProgress
              ? 'Your incident report is now being reviewed.'
              : 'Your incident report has been resolved.',
          'type': notificationType,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
    });
  }
}
