
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

class StudentUpdatesScreen extends StatefulWidget {
  const StudentUpdatesScreen({super.key});

  @override
  State<StudentUpdatesScreen> createState() =>
      _StudentUpdatesScreenState();
}

class _StudentUpdatesScreenState
    extends State<StudentUpdatesScreen> {
  static const Color purple = Color(0xFF8544C4);
  static const Color background = Color(0xFFFFFAFF);
  static const Color lightPurple = Color(0xFFF4E9FF);
  static const Color darkText = Color(0xFF292033);

  final NotificationService _service = NotificationService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late final Stream<
      List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _notificationsStream;

  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    _notificationsStream = _service.getMyNotifications();
  }

  Future<void> _markAllAsRead() async {
    if (_markingAll) return;

    setState(() => _markingAll = true);

    try {
      await _service.markAllAsRead();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update notifications: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _markingAll = false);
      }
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to mark notification as read: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ALU CAMPUS CARE',
                style: TextStyle(
                  color: purple,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your updates ✦',
                style: TextStyle(
                  color: darkText,
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Track what is happening with your reports.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: StreamBuilder<
                    List<QueryDocumentSnapshot<
                        Map<String, dynamic>>>>(
                  stream: _notificationsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _messageState(
                        Icons.error_outline_rounded,
                        'Unable to load updates',
                        'Please check your connection and try again.',
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: purple,
                        ),
                      );
                    }

                    final notifications = snapshot.data!;

                    if (notifications.isEmpty) {
                      return _messageState(
                        Icons.notifications_none_rounded,
                        'No updates yet',
                        'Updates about your incident reports '
                            'will appear here.',
                      );
                    }

                    final unreadCount = notifications
                        .where((doc) => doc.data()['isRead'] != true)
                        .length;

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                unreadCount == 0
                                    ? 'All caught up!'
                                    : '$unreadCount unread '
                                        '${unreadCount == 1 ? 'update' : 'updates'}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: darkText,
                                ),
                              ),
                            ),
                            if (unreadCount > 0)
                              TextButton(
                                onPressed: _markingAll
                                    ? null
                                    : _markAllAsRead,
                                child: Text(
                                  _markingAll
                                      ? 'Updating...'
                                      : 'Mark all as read',
                                  style: const TextStyle(
                                    color: purple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: ListView.separated(
                            itemCount: notifications.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final document = notifications[index];

                              return _notificationCard(
                                document.id,
                                document.data(),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationCard(
    String notificationId,
    Map<String, dynamic> notification,
  ) {
    final incidentId =
        notification['incidentId'] as String? ?? '';

    if (incidentId.isEmpty) {
      return _buildCardContent(
        notificationId: notificationId,
        notification: notification,
        incident: null,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('incidents')
          .doc(incidentId)
          .snapshots(),
      builder: (context, snapshot) {
        return _buildCardContent(
          notificationId: notificationId,
          notification: notification,
          incident: snapshot.data?.data(),
        );
      },
    );
  }

  Widget _buildCardContent({
    required String notificationId,
    required Map<String, dynamic> notification,
    required Map<String, dynamic>? incident,
  }) {
    final isRead = notification['isRead'] == true;
    final type = notification['type'] as String? ?? '';
    final title =
        notification['title'] as String? ?? 'Report update';
    final timestamp = notification['createdAt'] as Timestamp?;

    final incidentTitle =
        incident?['title'] as String? ?? '';
    final incidentLocation =
        incident?['location'] as String? ?? '';
    final incidentStatus =
        incident?['status'] as String? ?? '';

    IconData icon;
    Color iconColor;

    switch (type) {
      case 'submitted':
        icon = Icons.send_rounded;
        iconColor = purple;
        break;
      case 'in_progress':
        icon = Icons.autorenew_rounded;
        iconColor = const Color(0xFF2878BE);
        break;
      case 'resolved':
        icon = Icons.check_circle_outline_rounded;
        iconColor = const Color(0xFF248A61);
        break;
      case 'cancelled':
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFB45B54);
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = purple;
    }

    final String message;

    if (incidentTitle.isNotEmpty) {
      switch (type) {
        case 'submitted':
          message = 'Your report "$incidentTitle" '
              'was submitted successfully.';
          break;
        case 'in_progress':
          message = 'Your report "$incidentTitle" '
              'is now being reviewed by campus staff.';
          break;
        case 'resolved':
          message = 'Your report "$incidentTitle" '
              'has been resolved.';
          break;
        case 'cancelled':
          message = 'Your report "$incidentTitle" '
              'has been cancelled.';
          break;
        default:
          message = notification['message'] as String? ?? '';
      }
    } else {
      message = notification['message'] as String? ?? '';
    }

    return Material(
      color: isRead ? Colors.white : lightPurple,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isRead
            ? null
            : () => _markAsRead(notificationId),
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isRead
                  ? const Color(0xFFF0EAF4)
                  : const Color(0xFFE1C8F4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: darkText,
                              fontSize: 15,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: purple,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (incidentTitle.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        incidentTitle,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    if (incidentLocation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              incidentLocation,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        if (incidentStatus.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(
                                alpha: 0.10,
                              ),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Current: $incidentStatus',
                              style: TextStyle(
                                color: iconColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          _formatDate(timestamp),
                          style: const TextStyle(
                            color: Colors.black45,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.isNegative ||
        difference.inMinutes < 1) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _messageState(
    IconData icon,
    String title,
    String message,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: lightPurple,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 38,
              color: purple,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: darkText,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
