
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:provider/provider.dart';

import '../providers/incident_provider.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() =>
      _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();

  final _imagePicker = ImagePicker();

  static const Color _purple = Color(0xFF8544C4);
  static const Color _background = Color(0xFFFFFAFF);
  static const Color _lightPurple = Color(0xFFF4E9FF);

  final List<String> _categories = [
    'Safety Concern',
    'Theft or Lost Property',
    'Harassment',
    'Facility or Maintenance',
    'Health or Medical Concern',
    'Other',
  ];

  String? _selectedCategory;
  XFile? _selectedImage;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Browse files using file_picker 13.x.
  Future<void> _browseFiles() async {
    if (_isSubmitting) return;

    try {
      final file = await fp.FilePicker.pickFile(
        type: fp.FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );

      if (file == null) return;

      final filePath = file.path;

      if (filePath == null) {
        _showError('Could not access the selected file.');
        return;
      }

      final fileSize =
          file.lengthSync() ?? await file.length();

      const maxSize = 10 * 1024 * 1024;

      if (fileSize == null || fileSize > maxSize) {
        _showError(
          'Could not verify the file size, or the image '
          'is larger than 10 MB.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = XFile(
          filePath,
          name: file.name,
        );
      });
    } catch (error) {
      if (!mounted) return;

      _showError('Could not browse files: $error');
    }
  }

  // Select an image from Gallery or Camera.
  Future<void> _pickImage(ImageSource source) async {
    if (_isSubmitting) return;

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );

      if (!mounted || image == null) return;

      final imageName = image.name.toLowerCase();

      final isValidType =
          imageName.endsWith('.jpg') ||
          imageName.endsWith('.jpeg') ||
          imageName.endsWith('.png');

      if (!isValidType) {
        _showError('Please select a JPG or PNG image.');
        return;
      }

      final imageSize = await image.length();

      const maxSize = 10 * 1024 * 1024;

      if (imageSize > maxSize) {
        _showError(
          'Please select an image smaller than 10 MB.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) return;

      _showError('Could not select photo: $error');
    }
  }

  // Remove the selected image.
  void _removeImage() {
    if (_isSubmitting) return;

    setState(() {
      _selectedImage = null;
    });
  }

  // Display an error message.
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // Submit incident through Provider.
  Future<void> _submitIncident() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await context.read<IncidentProvider>().createIncident(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory!,
        location: _locationController.text.trim(),
        image: _selectedImage,
      );

      if (!mounted) return;

      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();

      setState(() {
        _selectedCategory = null;
        _selectedImage = null;
      });

      _formKey.currentState?.reset();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: _purple,
              size: 52,
            ),
            title: const Text(
              'Report submitted!',
              textAlign: TextAlign.center,
            ),
            content: const Text(
              'Your incident has been submitted successfully. '
              'You can track its progress in My Reports.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;

      final message = error.toString();

      if (message.contains('was created, but its photo')) {
        _showError(
          'Your report was saved, but the photo could not '
          'be attached. Check My Reports before submitting '
          'again to avoid duplicates. Details: $error',
        );
      } else {
        _showError('Could not submit report: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // Shared input field styling.
  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: _purple),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE7DDEE),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE7DDEE),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: _purple,
          width: 1.8,
        ),
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }

  // Optional photo attachment section.
  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              color: _purple,
            ),
            SizedBox(width: 10),
            Text(
              'Attach a Photo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF292033),
              ),
            ),
            Spacer(),
            Text(
              'Optional',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const Text(
          'Add a photo to help explain what happened.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 14),

        if (_selectedImage == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE7DDEE),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    color: _purple,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Add photo evidence',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 16),

                // FIRST OPTION: Browse Files
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : _browseFiles,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.folder_open_outlined,
                    ),
                    label: const Text('Browse Files'),
                  ),
                ),

                const SizedBox(height: 12),

                // Other options: Gallery and Camera
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickImage(
                                ImageSource.gallery,
                              ),
                      icon: const Icon(
                        Icons.photo_library_outlined,
                      ),
                      label: const Text('Gallery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _pickImage(
                                ImageSource.camera,
                              ),
                      icon: const Icon(
                        Icons.camera_alt_outlined,
                      ),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE7DDEE),
              ),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImage!.path),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: _purple,
                      size: 20,
                    ),

                    const SizedBox(width: 8),

                    const Expanded(
                      child: Text(
                        'Photo selected',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    TextButton.icon(
                      onPressed:
                          _isSubmitting ? null : _removeImage,
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        'Remove',
                        style: TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        const SizedBox(height: 10),

        const Text(
          'JPG or PNG only. Maximum size: 10 MB. '
          'Photos are stored privately.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.edit_note_rounded,
                    color: _purple,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Tell us what happened',
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF292033),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Your voice matters. Share the details so '
                  'the campus team can help.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 28),

                // Incident title
                TextFormField(
                  controller: _titleController,
                  maxLength: 100,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    label: 'Incident title',
                    hint: 'Give your report a short title',
                    icon: Icons.title_rounded,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter an incident title.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Category
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    label: 'Category',
                    hint: 'Select a category',
                    icon: Icons.category_outlined,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a category.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 22),

                // Location
                TextFormField(
                  controller: _locationController,
                  maxLength: 150,
                  decoration: _inputDecoration(
                    label: 'Location',
                    hint: 'Where did it happen?',
                    icon: Icons.location_on_outlined,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please enter the location.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 6,
                  minLines: 4,
                  maxLength: 2000,
                  textCapitalization:
                      TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    label: 'Description',
                    hint: 'Describe what happened in detail...',
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Please describe the incident.';
                    }

                    if (value.trim().length < 15) {
                      return 'Please provide at least 15 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 22),

                // Photo attachment
                _buildImageUploadSection(),

                const SizedBox(height: 22),

                // Privacy information
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        color: _purple,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your report is private by default. '
                          'Only authorized campus staff should '
                          'be able to review it.',
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

                // Submit button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton.icon(
                    onPressed: _isSubmitting
                        ? null
                        : _submitIncident,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(17),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Submitting...'
                          : 'Submit Report',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
