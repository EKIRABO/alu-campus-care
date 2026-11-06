
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color purple = Color(0xFF8544C4);
  static const Color background = Color(0xFFFFFAFF);
  static const Color lightPurple = Color(0xFFF4E9FF);
  static const Color darkText = Color(0xFF292033);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _categories = [
    'All',
    'Facilities',
    'Safety',
    'Maintenance',
    'Other',
  ];

  String _selectedCategory = 'All';

  late final Stream<QuerySnapshot<Map<String, dynamic>>>
      _announcementsStream;

  @override
  void initState() {
    super.initState();

    // Only published announcements can appear on Explore.
    // Firestore security rules also protect unpublished records.
    _announcementsStream = _firestore
        .collection('public_incidents')
        .where('published', isEqualTo: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),

              const SizedBox(height: 24),

              _buildHero(),

              const SizedBox(height: 30),

              _buildSectionHeading(
                'Campus announcements',
                'Stay informed about what is happening on campus',
              ),

              const SizedBox(height: 16),

              _buildFilters(),

              const SizedBox(height: 16),

              _buildAnnouncements(),

              const SizedBox(height: 30),

              _buildSectionHeading(
                'Campus essentials',
                'Useful resources, all in one place',
              ),

              const SizedBox(height: 16),

              _buildResources(),

              const SizedBox(height: 24),

              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
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

              const SizedBox(height: 9),

              const Text(
                'Explore campus ✦',
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Stay aware. Stay connected.',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: lightPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.explore_outlined,
            color: purple,
            size: 28,
          ),
        ),
      ],
    );
  }

  // ============================================
  // HERO SECTION
  // ============================================

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF8544C4),
            Color(0xFFA56DD8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -12,
            top: -20,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 115,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.diversity_3_outlined,
                color: Colors.white,
                size: 34,
              ),

              SizedBox(height: 22),

              Text(
                'A better campus\nstarts with us.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),

              SizedBox(height: 12),

              Text(
                'Discover campus announcements, find '
                'helpful resources, and stay informed.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // SECTION HEADINGS
  // ============================================

  Widget _buildSectionHeading(
    String title,
    String subtitle,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: darkText,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  // ============================================
  // CATEGORY FILTERS
  // ============================================

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((category) {
          final selected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              selectedColor: purple,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selected ? Colors.white : darkText,
                fontWeight: FontWeight.w600,
              ),
              side: BorderSide(
                color: selected
                    ? purple
                    : const Color(0xFFECE4F2),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================
  // PUBLISHED ANNOUNCEMENTS
  // ============================================

  Widget _buildAnnouncements() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _announcementsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageCard(
            Icons.lock_outline_rounded,
            'Announcements unavailable',
            'Campus announcements are not available '
            'right now. Please try again later.',
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                color: purple,
              ),
            ),
          );
        }

        final announcements = snapshot.data!.docs.where((doc) {
          final data = doc.data();

          if (data['published'] != true) {
            return false;
          }

          if (_selectedCategory == 'All') {
            return true;
          }

          return data['category'] == _selectedCategory;
        }).toList();

        // Display the most recently published first.
        announcements.sort((a, b) {
          final aDate = a.data()['publishedAt'];
          final bDate = b.data()['publishedAt'];

          final aTime = aDate is Timestamp
              ? aDate.millisecondsSinceEpoch
              : 0;

          final bTime = bDate is Timestamp
              ? bDate.millisecondsSinceEpoch
              : 0;

          return bTime.compareTo(aTime);
        });

        if (announcements.isEmpty) {
          return _messageCard(
            Icons.inbox_outlined,
            'No announcements yet',
            _selectedCategory == 'All'
                ? 'Campus announcements will appear '
                    'here when available.'
                : 'No announcements in this category yet.',
          );
        }

        return Column(
          children: announcements.map((doc) {
            final data = doc.data();

            final title = data['title'] is String
                ? data['title'] as String
                : 'Campus announcement';

            final summary = data['summary'] is String
                ? data['summary'] as String
                : '';

            final category = data['category'] is String
                ? data['category'] as String
                : 'Other';

            // Older incident-based announcements may have
            // an incident status. New general announcements
            // do not require one.
            final status = data['status'] is String
                ? data['status'] as String
                : null;

            final publishedAt = data['publishedAt'];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _announcementCard(
                title: title,
                summary: summary,
                category: category,
                status: status,
                publishedAt: publishedAt is Timestamp
                    ? publishedAt.toDate()
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ============================================
  // ANNOUNCEMENT CARD
  // ============================================

  Widget _announcementCard({
    required String title,
    required String summary,
    required String category,
    String? status,
    DateTime? publishedAt,
  }) {
    return Container(
      width: double.infinity,
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: purple,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  category,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: darkText,
                  ),
                ),
              ),

              // Only show incident statuses for older
              // incident-based announcements.
              if (status != null)
                _statusBadge(status),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),

          if (summary.isNotEmpty) ...[
            const SizedBox(height: 8),

            Text(
              summary,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],

          if (publishedAt != null) ...[
            const SizedBox(height: 14),

            Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: Colors.black45,
                ),

                const SizedBox(width: 6),

                Text(
                  _formatDate(publishedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year;

    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  // ============================================
  // LEGACY INCIDENT STATUS BADGES
  // ============================================

  Widget _statusBadge(String status) {
    Color color;

    switch (status) {
      case 'Resolved':
        color = Colors.green;
        break;
      case 'In Progress':
        color = Colors.blue;
        break;
      case 'Pending':
        color = Colors.orange;
        break;
      default:
        color = purple;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ============================================
  // CAMPUS RESOURCES
  // ============================================

  Widget _buildResources() {
    final resources = [
      (
        'Safety guide',
        'Know what to do',
        Icons.shield_outlined,
      ),
      (
        'Get help',
        'Campus contacts',
        Icons.support_agent_rounded,
      ),
      (
        'Campus spaces',
        'Find key locations',
        Icons.location_on_outlined,
      ),
      (
        'Report tips',
        'Report effectively',
        Icons.assignment_outlined,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: resources.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 148,
      ),
      itemBuilder: (context, index) {
        final resource = resources[index];

        return InkWell(
          onTap: () => _showResource(
            resource.$1,
            resource.$2,
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lightPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    resource.$3,
                    color: purple,
                    size: 23,
                  ),
                ),

                const Spacer(),

                Text(
                  resource.$1,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  resource.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // RESOURCE DETAILS
  // ============================================

  void _showResource(
    String title,
    String subtitle,
  ) {
    String content;

    switch (title) {
      case 'Safety guide':
        content =
            'If you notice a safety concern on campus, '
            'move to a safe location before reporting it.\n\n'
            'For immediate danger, contact campus security '
            'or local emergency services directly. '
            'Campus Care is not an emergency response service.\n\n'
            'For non-emergency concerns, submit a report '
            'through Campus Care with clear details.';
        break;

      case 'Get help':
        content =
            'For urgent assistance, contact the appropriate '
            'campus support team directly.\n\n'
            'For non-emergency incidents, use the Report '
            'Incident feature so authorized staff can '
            'review your concern.\n\n'
            'Official campus contact information should '
            'be obtained from ALU staff or verified '
            'university communication channels.';
        break;

      case 'Campus spaces':
        content =
            'When submitting a report, describe the '
            'location as clearly as possible.\n\n'
            'Include the building, room, floor, or nearby '
            'landmark when relevant.\n\n'
            'Avoid including unnecessary personal '
            'information about other students.';
        break;

      case 'Report tips':
        content =
            'A useful incident report should explain:\n\n'
            '1. What happened.\n'
            '2. Where it happened.\n'
            '3. When it happened, if known.\n'
            '4. Why the issue needs attention.\n\n'
            'You may attach a relevant photo when '
            'appropriate. Avoid sharing sensitive '
            'or identifying information unnecessarily.';
        break;

      default:
        content = subtitle;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24, 12, 24, 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.pop(sheetContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: purple,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // EMPTY AND ERROR STATES
  // ============================================

  Widget _messageCard(
    IconData icon,
    String title,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: lightPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: purple,
            size: 30,
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: darkText,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // FOOTER
  // ============================================

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'A caring campus is a connected campus. 💜',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black54,
          fontSize: 12,
        ),
      ),
    );
  }
}
