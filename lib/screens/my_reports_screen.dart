
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incident_model.dart';
import '../providers/incident_provider.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController =
      TextEditingController();

  static const Color _purple = Color(0xFF8544C4);
  static const Color _background = Color(0xFFFFFAFF);
  static const Color _lightPurple = Color(0xFFF4E9FF);
  static const Color _darkText = Color(0xFF292033);

  String _selectedFilter = 'All';
  String _searchQuery = '';
  bool _cancelling = false;

  final Map<String, Future<String>> _imageUrlCache = {};

  final List<String> _filters = [
    'All',
    'Pending',
    'In Progress',
    'Resolved',
    'Cancelled',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange.shade800;
      case 'In Progress':
        return Colors.blue.shade700;
      case 'Resolved':
        return Colors.green.shade700;
      case 'Cancelled':
        return Colors.grey.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Safety Concern':
        return Icons.health_and_safety_outlined;
      case 'Theft or Lost Property':
        return Icons.inventory_2_outlined;
      case 'Harassment':
        return Icons.report_problem_outlined;
      case 'Facility or Maintenance':
        return Icons.handyman_outlined;
      case 'Health or Medical Concern':
        return Icons.medical_services_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  // Generate a signed URL for an image in private Supabase Storage.
  Future<String> _getImageUrl(String imagePath) async {
    try {
      debugPrint('Loading incident image: $imagePath');

      final signedUrl = await _supabase.storage
          .from('incident-images')
          .createSignedUrl(imagePath, 300);

      debugPrint('Signed URL created successfully');

      return signedUrl;
    } on StorageException catch (error) {
      debugPrint('SUPABASE IMAGE ERROR');
      debugPrint('Message: ${error.message}');
      debugPrint('Status code: ${error.statusCode}');
      debugPrint('Error: ${error.error}');

      rethrow;
    } catch (error) {
      debugPrint('IMAGE LOADING ERROR: $error');
      rethrow;
    }
  }

  // Display a private incident photo.
  Widget _buildIncidentImage(String imagePath) {
    final imageFuture = _imageUrlCache.putIfAbsent(
      imagePath,
      () => _getImageUrl(imagePath),
    );

    return FutureBuilder<String>(
      future: imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            height: 190,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _lightPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const CircularProgressIndicator(
              color: _purple,
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _lightPurple,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  color: _purple,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This attachment could not be loaded.',
                  ),
                ),
              ],
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            snapshot.data!,
            width: double.infinity,
            height: 210,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('IMAGE NETWORK ERROR: $error');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _lightPurple,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: _purple,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Unable to display this photo.',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Confirm cancellation of a pending report.
  Future<void> _confirmCancellation(
    IncidentModel incident,
    BuildContext sheetContext,
  ) async {
    if (_cancelling) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Report?'),
          content: const Text(
            'Are you sure you want to cancel this report? '
            'It will remain in your report history, '
            'but it cannot be reopened.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(false),
              child: const Text('Keep Report'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel Report'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);

    try {
      await context
          .read<IncidentProvider>()
          .cancelPendingIncident(
            incidentId: incident.id,
          );

      if (!mounted) return;

      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your report has been cancelled.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not cancel report: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelling = false);
      }
    }
  }

  // Show the full details of a report.
  void _showReportDetails(IncidentModel incident) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.75,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),

                  const SizedBox(height: 12),

                  _statusBadge(incident.status),

                  const SizedBox(height: 26),

                  _detailRow(
                    Icons.category_outlined,
                    'Category',
                    incident.category,
                  ),

                  _detailRow(
                    Icons.location_on_outlined,
                    'Location',
                    incident.location,
                  ),

                  _detailRow(
                    Icons.calendar_today_outlined,
                    'Submitted',
                    DateFormat('MMM d, yyyy • h:mm a')
                        .format(incident.createdAt),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'What happened',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    incident.description,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),

                  // Attached photos.
                  if (incident.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 26),

                    const Row(
                      children: [
                        Icon(
                          Icons.image_outlined,
                          color: _purple,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Attached Photo',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _darkText,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    ...incident.imageUrls.map(
                      (imagePath) => Padding(
                        padding: const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _buildIncidentImage(imagePath),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Status information.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _lightPurple,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: _purple,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            incident.status == 'Cancelled'
                                ? 'You cancelled this report. '
                                  'It remains in your history.'
                                : incident.status == 'Resolved'
                                    ? 'This incident has been marked '
                                      'as resolved.'
                                    : 'Your report is being tracked. '
                                      'Its status will update when '
                                      'the campus team takes action.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Cancel a pending report.
                  if (incident.status == 'Pending') ...[
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelling
                            ? null
                            : () => _confirmCancellation(
                                  incident,
                                  sheetContext,
                                ),
                        icon: const Icon(
                          Icons.cancel_outlined,
                        ),
                        label: const Text('Cancel Report'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(
                            color: Colors.red.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 15,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Display a labeled detail row.
  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _purple,
            size: 21,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Display a report status badge.
  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Individual report card.
  Widget _reportCard(IncidentModel incident) {
    return InkWell(
      onTap: () => _showReportDetails(incident),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
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
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    _categoryIcon(incident.category),
                    color: _purple,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    incident.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ),

                if (incident.imageUrls.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: _purple,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 15),

            Text(
              incident.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                _statusBadge(incident.status),
                const Spacer(),
                Flexible(
                  child: Text(
                    DateFormat('MMM d, yyyy')
                        .format(incident.createdAt),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Consumer<IncidentProvider>(
        builder: (context, incidentProvider, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page heading.
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  22, 25, 22, 8,
                ),
                child: Text(
                  'My Reports',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(
                  22, 0, 22, 20,
                ),
                child: Text(
                  'Track the incidents you have reported.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),

              // Search reports.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  22, 0, 22, 18,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery =
                          value.trim().toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search your reports...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _purple,
                    ),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(
                      vertical: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFECE4F2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFECE4F2),
                      ),
                    ),
                  ),
                ),
              ),

              // Status filters.
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 9),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];

                    return ChoiceChip(
                      label: Text(filter),
                      selected:
                          _selectedFilter == filter,
                      selectedColor: _lightPurple,
                      onSelected: (_) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Report results.
              Expanded(
                child: _buildReportsContent(
                  incidentProvider,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportsContent(
    IncidentProvider incidentProvider,
  ) {
    if (incidentProvider.error != null &&
        incidentProvider.incidents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Could not load your reports. '
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (incidentProvider.isLoading &&
        incidentProvider.incidents.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: _purple,
        ),
      );
    }

    final reports = incidentProvider.incidents.where(
      (incident) {
        final matchesStatus =
            _selectedFilter == 'All' ||
            incident.status == _selectedFilter;

        final matchesSearch =
            _searchQuery.isEmpty ||
            incident.title.toLowerCase().contains(
              _searchQuery,
            ) ||
            incident.description.toLowerCase().contains(
              _searchQuery,
            ) ||
            incident.category.toLowerCase().contains(
              _searchQuery,
            ) ||
            incident.location.toLowerCase().contains(
              _searchQuery,
            );

        return matchesStatus && matchesSearch;
      },
    ).toList();

    // Scrollable empty state.
    if (reports.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox_outlined,
                      size: 60,
                      color: _purple,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No matching reports'
                          : _selectedFilter == 'All'
                              ? 'No reports yet'
                              : 'No $_selectedFilter reports',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try a different search term '
                            'or change the status filter.'
                          : 'Your submitted incidents '
                            'will appear here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        22, 8, 22, 24,
      ),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        return _reportCard(reports[index]);
      },
    );
  }
}
