
import 'package:flutter/material.dart';

import '../models/incident_model.dart';
import '../services/public_incident_service.dart';

class PublishPublicIncidentScreen extends StatefulWidget {
  final IncidentModel incident;

  const PublishPublicIncidentScreen({
    super.key,
    required this.incident,
  });

  @override
  State<PublishPublicIncidentScreen> createState() =>
      _PublishPublicIncidentScreenState();
}

class _PublishPublicIncidentScreenState
    extends State<PublishPublicIncidentScreen> {
  static const Color _purple = Color(0xFF8544C4);
  static const Color _background = Color(0xFFFFFAFF);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _summaryController = TextEditingController();
  final _service = PublicIncidentService();

  String _category = 'Facilities';
  bool _publishing = false;

  static const _categories = [
    'Facilities',
    'Safety',
    'Maintenance',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    if (_categories.contains(widget.incident.category)) {
      _category = widget.incident.category;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (_publishing) return;

    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Publish campus update?'),
        content: const Text(
          'This update will be visible to students. '
          'Confirm that the title and summary contain '
          'no names, email addresses, private details, '
          'or identifying information.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Review again'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
            ),
            child: const Text('Publish'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _publishing = true);

    try {
      await _service.publishIncident(
        incidentId: widget.incident.id,
        title: _titleController.text,
        summary: _summaryController.text,
        category: _category,
        status: widget.incident.status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Public campus update published successfully.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publishing failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('Public Campus Update'),
        foregroundColor: const Color(0xFF292033),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4E9FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        color: _purple,
                        size: 30,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Share a campus update',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Write a short, anonymous summary '
                        'of the campus issue. Do not include '
                        'the student’s identity or private '
                        'report details.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Public title',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  maxLength: 120,
                  decoration: _decoration(
                    'e.g. Water supply interruption',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter a public title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                const Text(
                  'Category',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _decoration('Category'),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _publishing
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() {
                              _category = value;
                            });
                          }
                        },
                ),
                const SizedBox(height: 24),

                const Text(
                  'Public summary',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _summaryController,
                  maxLines: 6,
                  maxLength: 1000,
                  decoration: _decoration(
                    'Describe the issue and any '
                    'relevant campus-wide information.',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Enter a public summary';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: _purple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Current incident status: '
                        '${widget.incident.status}',
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.publish_rounded,
                          ),
                    label: Text(
                      _publishing
                          ? 'Publishing...'
                          : 'Publish Public Update',
                    ),
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
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
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
}
