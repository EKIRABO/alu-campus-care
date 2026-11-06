
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/incident_model.dart';
import '../services/incident_service.dart';

class IncidentProvider extends ChangeNotifier {
  final IncidentService _incidentService = IncidentService();

  StreamSubscription<List<IncidentModel>>? _subscription;

  List<IncidentModel> _incidents = [];

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  String? _currentUserId;

  // Getters
  List<IncidentModel> get incidents =>
      List.unmodifiable(_incidents);

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;

  // Report statistics
  int get totalCount => _incidents.length;

  int get pendingCount => _countByStatus('Pending');

  int get inProgressCount => _countByStatus('In Progress');

  int get resolvedCount => _countByStatus('Resolved');

  int get cancelledCount => _countByStatus('Cancelled');

  int _countByStatus(String status) {
    return _incidents
        .where((incident) => incident.status == status)
        .length;
  }

  // Start listening to the authenticated student's reports.
  void startListening(String userId) {
    if (_currentUserId == userId &&
        _subscription != null) {
      return;
    }

    _subscription?.cancel();

    _currentUserId = userId;
    _incidents = [];
    _error = null;
    _isLoading = true;

    notifyListeners();

    try {
      _subscription = _incidentService
          .getMyIncidents()
          .listen(
        (incidents) {
          if (_currentUserId != userId) return;

          _incidents = incidents;
          _isLoading = false;
          _error = null;

          notifyListeners();
        },
        onError: (Object error) {
          if (_currentUserId != userId) return;

          _isLoading = false;
          _error = error.toString();

          notifyListeners();
        },
      );
    } catch (error) {
      _isLoading = false;
      _error = error.toString();

      notifyListeners();
    }
  }

  // Create a new incident report.
  Future<String> createIncident({
    required String title,
    required String description,
    required String category,
    required String location,
    XFile? image,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      return await _incidentService.createIncident(
        title: title,
        description: description,
        category: category,
        location: location,
        image: image,
      );
    } catch (error) {
      // FIX:
      // Do not store submission errors in _error.
      //
      // _error is reserved for errors loading reports.
      // Submission errors are handled by ReportIncidentScreen.
      //
      // This prevents a failed photo upload from
      // replacing the dashboard statistics.

      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Edit an existing pending report.
  Future<void> updatePendingIncident({
    required String incidentId,
    required String title,
    required String description,
    required String category,
    required String location,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _incidentService.updatePendingIncident(
        incidentId: incidentId,
        title: title,
        description: description,
        category: category,
        location: location,
      );
    } catch (error) {
      // Keep submission errors separate from
      // report-loading errors.
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Cancel a pending report.
  Future<void> cancelPendingIncident({
    required String incidentId,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      await _incidentService.cancelPendingIncident(
        incidentId: incidentId,
      );
    } catch (error) {
      // Cancellation errors should be handled
      // by the screen performing the action.
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  // Clear private report data when the user signs out.
  void clear() {
    _subscription?.cancel();
    _subscription = null;

    _currentUserId = null;
    _incidents = [];
    _error = null;
    _isLoading = false;
    _isSubmitting = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
