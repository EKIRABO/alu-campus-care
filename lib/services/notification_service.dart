
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  User _requireUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in to continue.');
    }

    if (!user.emailVerified) {
      throw StateError('Please verify your email first.');
    }

    return user;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getMyNotifications() {
    final user = _requireUser();

    return _notifications
        .where('recipientId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
      final notifications = snapshot.docs.toList();

      notifications.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;

        return (bTime?.millisecondsSinceEpoch ?? 0)
            .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
      });

      return notifications;
    });
  }

  Stream<int> getUnreadCount() {
    return getMyNotifications().map((notifications) {
      return notifications
          .where((notification) =>
              notification.data()['isRead'] != true)
          .length;
    });
  }

  Future<void> markAsRead(String notificationId) async {
    final user = _requireUser();
    final reference = _notifications.doc(notificationId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Notification not found.');
      }

      if (snapshot.data()?['recipientId'] != user.uid) {
        throw StateError('Permission denied.');
      }

      if (snapshot.data()?['isRead'] == true) {
        return;
      }

      transaction.update(reference, {'isRead': true});
    });
  }

  Future<void> markAllAsRead() async {
    final user = _requireUser();

    final snapshot = await _notifications
        .where('recipientId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .get();

    const batchSize = 400;

    for (var start = 0;
        start < snapshot.docs.length;
        start += batchSize) {
      final batch = _firestore.batch();

      final end = (start + batchSize < snapshot.docs.length)
          ? start + batchSize
          : snapshot.docs.length;

      for (final document in snapshot.docs.sublist(start, end)) {
        batch.update(document.reference, {'isRead': true});
      }

      await batch.commit();
    }
  }
}
