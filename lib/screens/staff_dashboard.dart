
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/public_incident_service.dart';
import '../services/staff_incident_service.dart';
import 'staff_incidents_screen.dart';

const Color _purple = Color(0xFF8544C4);
const Color _background = Color(0xFFFFFAFF);
const Color _lightPurple = Color(0xFFF4E9FF);
const Color _darkText = Color(0xFF292033);

const List<String> _announcementCategories = [
  'Facilities',
  'Safety',
  'Maintenance',
  'Other',
];

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  String _announcementFilter = 'All';
  bool _announcementBusy = false;

  final StaffIncidentService _staffIncidentService =
      StaffIncidentService();

  final PublicIncidentService _publicIncidentService =
      PublicIncidentService();

  late final Stream<Map<String, int>> _statsStream;

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _announcementsStream;

  @override
  void initState() {
    super.initState();

    _statsStream = _staffIncidentService.getIncidentStats();

    _announcementsStream =
        _publicIncidentService.getAllAnnouncements();
  }

  String get _firstName {
    final name =
        FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';

    return name.isEmpty ? 'Staff' : name.split(' ').first;
  }

  void _changeTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _announcementStatus(Map<String, dynamic> data) {
    final lifecycle = data['lifecycleStatus'];

    if (lifecycle == 'draft' ||
        lifecycle == 'published' ||
        lifecycle == 'unpublished') {
      return lifecycle as String;
    }

    return data['published'] == true
        ? 'published'
        : 'unpublished';
  }

  String _formatDate(dynamic value) {
    if (value is! Timestamp) return 'Not published';

    final date = value.toDate().toLocal();

    String twoDigits(int number) =>
        number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/'
        '${date.year} ${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }

  // ============================================
  // OPEN ANNOUNCEMENT FORM
  // ============================================

  Future<void> _openAnnouncementForm({
    String? announcementId,
    Map<String, dynamic>? existingData,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _background,
      builder: (sheetContext) {
        return _AnnouncementForm(
          service: _publicIncidentService,
          announcementId: announcementId,
          existingData: existingData,
        );
      },
    );

    if (!mounted || result == null) return;

    _showMessage(result);
  }

  // ============================================
  // ANNOUNCEMENT ACTIONS
  // ============================================

  Future<void> _performAnnouncementAction({
    required String announcementId,
    required String action,
  }) async {
    if (_announcementBusy) return;

    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Delete announcement?'),
            content: const Text(
              'This action permanently deletes the announcement.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !mounted) return;
    }

    setState(() => _announcementBusy = true);

    try {
      switch (action) {
        case 'publish':
          await _publicIncidentService.publishAnnouncement(
            announcementId,
          );
          _showMessage('Announcement published.');
          break;

        case 'unpublish':
          await _publicIncidentService.unpublishAnnouncement(
            announcementId,
          );
          _showMessage('Announcement unpublished.');
          break;

        case 'delete':
          await _publicIncidentService.deleteAnnouncement(
            announcementId,
          );
          _showMessage('Announcement deleted.');
          break;
      }
    } catch (error) {
      _showMessage('Action failed: $error');
    } finally {
      if (mounted) {
        setState(() => _announcementBusy = false);
      }
    }
  }

  // ============================================
  // STAFF UPDATES TAB
  // ============================================

  Widget _buildAnnouncements() {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Campus Updates',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create and manage announcements '
                  'for the ALU community.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openAnnouncementForm(),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create Announcement'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            height: 54,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                'All',
                'Published',
                'Drafts',
                'Unpublished',
              ].map((filter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: _announcementFilter == filter,
                    selectedColor: _lightPurple,
                    onSelected: (_) {
                      setState(() {
                        _announcementFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream: _announcementsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Unable to load announcements:\n'
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: _purple,
                    ),
                  );
                }

                final documents = snapshot.data!.docs.where((doc) {
                  final status = _announcementStatus(doc.data());

                  switch (_announcementFilter) {
                    case 'Published':
                      return status == 'published';
                    case 'Drafts':
                      return status == 'draft';
                    case 'Unpublished':
                      return status == 'unpublished';
                    default:
                      return true;
                  }
                }).toList();

                if (documents.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.campaign_outlined,
                            size: 55,
                            color: _purple,
                          ),
                          const SizedBox(height: 15),
                          Text(
                            _announcementFilter == 'All'
                                ? 'No announcements yet'
                                : 'No ${_announcementFilter.toLowerCase()} announcements',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create an announcement to get started.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];

                    return _announcementCard(
                      document.id,
                      document.data(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ANNOUNCEMENT CARD
  // ============================================

  Widget _announcementCard(
    String announcementId,
    Map<String, dynamic> data,
  ) {
    final status = _announcementStatus(data);
    final isPublished = status == 'published';

    final statusColor = isPublished
        ? Colors.green
        : status == 'draft'
            ? Colors.orange
            : Colors.grey;

    final title = data['title']?.toString() ?? 'Untitled';
    final summary = data['summary']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'Other';

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFECE4F2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status[0].toUpperCase() +
                        status.substring(1),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Text(
              category,
              style: const TextStyle(
                color: _purple,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              summary,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                height: 1.5,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              isPublished
                  ? 'Published: ${_formatDate(data['publishedAt'])}'
                  : status == 'draft'
                      ? 'Saved as draft'
                      : 'Not currently visible to students',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),

            const Divider(height: 28),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _announcementBusy
                      ? null
                      : () => _openAnnouncementForm(
                            announcementId: announcementId,
                            existingData: data,
                          ),
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 17,
                  ),
                  label: const Text('Edit'),
                ),

                if (!isPublished)
                  FilledButton.icon(
                    onPressed: _announcementBusy
                        ? null
                        : () => _performAnnouncementAction(
                              announcementId: announcementId,
                              action: 'publish',
                            ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                    ),
                    icon: const Icon(
                      Icons.publish_outlined,
                      size: 17,
                    ),
                    label: const Text('Publish'),
                  ),

                if (isPublished)
                  OutlinedButton.icon(
                    onPressed: _announcementBusy
                        ? null
                        : () => _performAnnouncementAction(
                              announcementId: announcementId,
                              action: 'unpublish',
                            ),
                    icon: const Icon(
                      Icons.visibility_off_outlined,
                      size: 17,
                    ),
                    label: const Text('Unpublish'),
                  ),

                IconButton(
                  tooltip: 'Delete announcement',
                  onPressed: _announcementBusy
                      ? null
                      : () => _performAnnouncementAction(
                            announcementId: announcementId,
                            action: 'delete',
                          ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // MAIN DASHBOARD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHome(),
          const StaffIncidentsScreen(),
          _buildAnnouncements(),
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _changeTab,
        backgroundColor: Colors.white,
        indicatorColor: _lightPurple,
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: _purple,
            ),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(
              Icons.assignment_rounded,
              color: _purple,
            ),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(
              Icons.campaign_rounded,
              color: _purple,
            ),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: _purple,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================
  // HOME TAB
  // ============================================

  Widget _buildHome() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            const Text(
              'ALU CAMPUS CARE',
              style: TextStyle(
                color: _purple,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Good to see you, $_firstName 👋',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Here is your campus care workspace.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 28),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(23),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8544C4),
                    Color(0xFFA56DD8),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 32,
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Every report matters.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 9),

                  const Text(
                    'Help make campus safer by reviewing '
                    'student concerns and responding promptly.',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed: () => _changeTab(1),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _purple,
                    ),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('View Incidents'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              'Incident overview',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),

            const SizedBox(height: 15),

            StreamBuilder<Map<String, int>>(
              stream: _statsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _noticeCard(
                    Icons.error_outline,
                    'Unable to load statistics',
                    'Please check your connection and '
                        'staff account permissions.',
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(
                        color: _purple,
                      ),
                    ),
                  );
                }

                final stats = snapshot.data!;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Pending',
                            stats['pending'] ?? 0,
                            Icons.schedule_rounded,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'In Progress',
                            stats['inProgress'] ?? 0,
                            Icons.autorenew_rounded,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Resolved',
                            stats['resolved'] ?? 0,
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statCard(
                            'Total',
                            stats['total'] ?? 0,
                            Icons.assignment_outlined,
                            _purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _statCard(
                            'Cancelled',
                            stats['cancelled'] ?? 0,
                            Icons.cancel_outlined,
                            Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            _noticeCard(
              Icons.info_outline,
              'Incident management',
              'Statistics update automatically when '
                  'students submit or cancel reports, '
                  'or when staff update incident statuses.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFECE4F2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),

          const SizedBox(height: 16),

          Text(
            '$count',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeCard(
    IconData icon,
    String title,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _lightPurple,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // PROFILE TAB
  // ============================================

  Widget _buildProfile() {
    final user = FirebaseAuth.instance.currentUser;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 15),

            const Text(
              'Staff Profile',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: _darkText,
              ),
            ),

            const SizedBox(height: 30),

            Center(
              child: CircleAvatar(
                radius: 45,
                backgroundColor: _lightPurple,
                child: Text(
                  _firstName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: _purple,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Text(
                user?.displayName ?? 'ALU Staff',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Center(
              child: Text(
                user?.email ?? '',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 30),

            _noticeCard(
              Icons.verified_user_outlined,
              'Staff account',
              'Staff access requires an administrator-assigned '
                  'Firebase role.',
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _purple,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                  ),
                  side: const BorderSide(color: _purple),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// ANNOUNCEMENT FORM
// MANAGES ITS OWN WIDGET LIFECYCLE
// ============================================

class _AnnouncementForm extends StatefulWidget {
  final PublicIncidentService service;
  final String? announcementId;
  final Map<String, dynamic>? existingData;

  const _AnnouncementForm({
    required this.service,
    this.announcementId,
    this.existingData,
  });

  @override
  State<_AnnouncementForm> createState() =>
      _AnnouncementFormState();
}

class _AnnouncementFormState extends State<_AnnouncementForm> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _summaryController;

  late String _category;

  bool _saving = false;

  bool get _isEditing => widget.announcementId != null;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.existingData?['title']?.toString() ?? '',
    );

    _summaryController = TextEditingController(
      text: widget.existingData?['summary']?.toString() ?? '',
    );

    _category =
        widget.existingData?['category']?.toString() ??
            'Facilities';

    if (!_announcementCategories.contains(_category)) {
      _category = 'Other';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();

    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ============================================
  // PRIVACY CONFIRMATION
  // ============================================

  Future<bool> _confirmPublication() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Publish campus announcement?',
          ),
          content: const Text(
            'This announcement will be visible to students. '
            'Make sure it does not contain student names, '
            'email addresses, private incident details, '
            'or identifying information.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Review again'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
              ),
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    return confirmed == true;
  }

  // ============================================
  // SAVE ANNOUNCEMENT
  // ============================================

  Future<void> _submit({
    required bool publishNow,
  }) async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (publishNow) {
      final confirmed = await _confirmPublication();

      if (!confirmed || !mounted) {
        return;
      }
    }

    setState(() => _saving = true);

    String? successMessage;

    try {
      if (_isEditing) {
        await widget.service.updateAnnouncement(
          announcementId: widget.announcementId!,
          title: _titleController.text,
          summary: _summaryController.text,
          category: _category,
        );

        successMessage =
            'Announcement updated successfully.';
      } else {
        await widget.service.createAnnouncement(
          title: _titleController.text,
          summary: _summaryController.text,
          category: _category,
          publishNow: publishNow,
        );

        successMessage = publishNow
            ? 'Announcement published successfully.'
            : 'Announcement saved as draft.';
      }
    } catch (error) {
      _showError(
        'Could not save announcement: $error',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }

    // Close only after the save has completed.
    // The parent dashboard shows the success message.
    if (successMessage != null && mounted) {
      Navigator.of(context).pop(successMessage);
    }
  }

  // ============================================
  // INPUT DECORATION
  // ============================================

  InputDecoration _inputDecoration(
    String label,
    String hint,
  ) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFECE4F2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _purple,
          width: 2,
        ),
      ),
    );
  }

  // ============================================
  // FORM UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing
                            ? 'Edit Announcement'
                            : 'Create Announcement',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _darkText,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                const Text(
                  'Share important campus information '
                  'with the ALU community.',
                  style: TextStyle(
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 25),

                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  enabled: !_saving,
                  decoration: _inputDecoration(
                    'Announcement title',
                    'e.g. Scheduled water maintenance',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter an announcement title';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _inputDecoration(
                    'Category',
                    'Choose a category',
                  ),
                  items: _announcementCategories.map((item) {
                    return DropdownMenuItem(
                      value: item,
                      child: Text(item),
                    );
                  }).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _category = value;
                            });
                          }
                        },
                ),

                const SizedBox(height: 22),

                TextFormField(
                  controller: _summaryController,
                  maxLines: 6,
                  maxLength: 1000,
                  enabled: !_saving,
                  decoration: _inputDecoration(
                    'Announcement message',
                    'Write the information students '
                        'need to know...',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter an announcement message';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 15),

                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: _purple,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Do not include student identities, '
                          'private report details, or sensitive '
                          'information in public announcements.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                if (!_isEditing)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _submit(
                                    publishNow: false,
                                  ),
                          icon: const Icon(
                            Icons.save_outlined,
                          ),
                          label: const Text('Save Draft'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _purple,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving
                              ? null
                              : () => _submit(
                                    publishNow: true,
                                  ),
                          icon: const Icon(
                            Icons.publish_rounded,
                          ),
                          label: const Text('Publish Now'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _purple,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : () => _submit(
                                publishNow: false,
                              ),
                      icon: const Icon(
                        Icons.save_outlined,
                      ),
                      label: const Text('Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),

                if (_saving) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: CircularProgressIndicator(
                      color: _purple,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
