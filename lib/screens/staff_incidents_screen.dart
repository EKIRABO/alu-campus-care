
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incident_model.dart';
import '../services/staff_incident_service.dart';

class StaffIncidentsScreen extends StatefulWidget {
  const StaffIncidentsScreen({super.key});

  @override
  State<StaffIncidentsScreen> createState() =>
      _StaffIncidentsScreenState();
}

class _StaffIncidentsScreenState
    extends State<StaffIncidentsScreen> {
  final StaffIncidentService _service = StaffIncidentService();

  final SupabaseClient _supabase = Supabase.instance.client;

  late final Stream<List<IncidentModel>> _incidentsStream;

  String _selectedFilter = 'All';
  bool _updating = false;

  static const Color _purple = Color(0xFF8544C4);
  static const Color _background = Color(0xFFFFFAFF);

  final List<String> _filters = [
    'All',
    'Pending',
    'In Progress',
    'Resolved',
  ];

  @override
  void initState() {
    super.initState();
    _incidentsStream = _service.getAllIncidents();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;

      case 'In Progress':
        return Colors.blue;

      case 'Resolved':
        return Colors.green;

      default:
        return Colors.grey;
    }
  }

  // ============================================
  // PRIVATE INCIDENT IMAGE
  // ============================================

  Future<String> _getStaffImageUrl(String imagePath) async {
    return await _supabase.storage
        .from('incident-images')
        .createSignedUrl(imagePath, 60);
  }

  // ============================================
  // UPDATE INCIDENT STATUS
  // ============================================

  Future<void> _updateStatus(
    IncidentModel incident,
    String newStatus,
  ) async {
    if (_updating) return;

    setState(() => _updating = true);

    try {
      await _service.updateIncidentStatus(
        incidentId: incident.id,
        newStatus: newStatus,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Incident updated to $newStatus.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Update failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  // ============================================
  // INCIDENT DETAILS
  // ============================================

  void _showIncidentDetails(IncidentModel incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _background,
      builder: (sheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // INCIDENT TITLE

                  Text(
                    incident.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // INCIDENT INFORMATION

                  _detailRow(
                    'Category',
                    incident.category,
                  ),

                  _detailRow(
                    'Location',
                    incident.location,
                  ),

                  _detailRow(
                    'Status',
                    incident.status,
                  ),

                  _detailRow(
                    'Reported by',
                    incident.reporterEmail,
                  ),

                  const SizedBox(height: 20),

                  // INCIDENT DESCRIPTION

                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    incident.description,
                  ),

                  const SizedBox(height: 24),

                  // ====================================
                  // PRIVATE INCIDENT ATTACHMENTS
                  // ====================================

                  if (incident.imageUrls.isNotEmpty) ...[
                    const Text(
                      'Incident Attachment',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FutureBuilder<String>(
                      future: _getStaffImageUrl(
                        incident.imageUrls.first,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(
                                color: _purple,
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError ||
                            !snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            child: Text(
                              'Unable to load the attachment. '
                              'Please check staff storage '
                              'permissions.',
                              style: TextStyle(
                                color: Colors.redAccent,
                              ),
                            ),
                          );
                        }

                        return ClipRRect(
                          borderRadius:
                              BorderRadius.circular(16),
                          child: Image.network(
                            snapshot.data!,
                            width: double.infinity,
                            height: 240,
                            fit: BoxFit.cover,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'Could not display this image.',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ====================================
                  // INCIDENT STATUS MANAGEMENT
                  // ====================================

                  if (incident.status == 'Pending')
                    _actionButton(
                      incident,
                      'In Progress',
                      'Start Reviewing',
                    ),

                  if (incident.status == 'In Progress')
                    _actionButton(
                      incident,
                      'Resolved',
                      'Mark as Resolved',
                    ),

                  if (incident.status == 'Resolved')
                    const Text(
                      'This incident has been resolved.',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                  if (incident.status == 'Cancelled')
                    const Text(
                      'This incident was cancelled '
                      'by the student.',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================
  // STATUS ACTION BUTTON
  // ============================================

  Widget _actionButton(
    IncidentModel incident,
    String newStatus,
    String label,
  ) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _updating
            ? null
            : () => _updateStatus(
                  incident,
                  newStatus,
                ),
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  // ============================================
  // INCIDENT DETAIL ROW
  // ============================================

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // INCIDENT CARD
  // ============================================

  Widget _incidentCard(
    IncidentModel incident,
  ) {
    final statusColor = _statusColor(
      incident.status,
    );

    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: Color(0xFFECE4F2),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showIncidentDetails(
          incident,
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      incident.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (incident.imageUrls.isNotEmpty)
                    const Icon(
                      Icons.attach_file_rounded,
                      color: _purple,
                      size: 20,
                    ),
                ],
              ),

              const SizedBox(height: 9),

              Text(
                '${incident.category} • '
                '${incident.location}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  incident.status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // STAFF INCIDENTS SCREEN
  // ============================================

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              22,
              24,
              22,
              8,
            ),
            child: Text(
              'Manage Incidents',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // ====================================
          // STATUS FILTERS
          // ====================================

          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
              ),
              children: _filters.map((filter) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected:
                        _selectedFilter == filter,
                    selectedColor:
                        const Color(0xFFF4E9FF),
                    onSelected: (_) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // ====================================
          // LIVE FIRESTORE INCIDENTS
          // ====================================

          Expanded(
            child: StreamBuilder<List<IncidentModel>>(
              stream: _incidentsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load incidents:\n'
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

                final incidents = snapshot.data!
                    .where(
                      (incident) =>
                          _selectedFilter == 'All' ||
                          incident.status ==
                              _selectedFilter,
                    )
                    .toList();

                if (incidents.isEmpty) {
                  return const Center(
                    child: Text(
                      'No incidents found.',
                      style: TextStyle(
                        color: Colors.black54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    return _incidentCard(
                      incidents[index],
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
}
