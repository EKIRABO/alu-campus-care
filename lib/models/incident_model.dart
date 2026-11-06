
import 'package:cloud_firestore/cloud_firestore.dart';

class IncidentModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String location;
  final String status;
  final String reporterId;
  final String reporterEmail;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> imageUrls;
  final bool isPublic;

  const IncidentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.status,
    required this.reporterId,
    required this.reporterEmail,
    required this.createdAt,
    this.updatedAt,
    this.imageUrls = const [],
    this.isPublic = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'location': location,
      'status': status,
      'reporterId': reporterId,
      'reporterEmail': reporterEmail,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt == null
          ? null
          : Timestamp.fromDate(updatedAt!),
      'imageUrls': imageUrls,
      'isPublic': isPublic,
    };
  }

  factory IncidentModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};

    return IncidentModel(
      id: document.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      category: data['category'] ?? '',
      location: data['location'] ?? '',
      status: data['status'] ?? 'Pending',
      reporterId: data['reporterId'] ?? '',
      reporterEmail: data['reporterEmail'] ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
      updatedAt:
          (data['updatedAt'] as Timestamp?)?.toDate(),
      imageUrls: List<String>.from(
        data['imageUrls'] ?? [],
      ),
      isPublic: data['isPublic'] ?? false,
    );
  }

  IncidentModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? location,
    String? status,
    String? reporterId,
    String? reporterEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? imageUrls,
    bool? isPublic,
  }) {
    return IncidentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      status: status ?? this.status,
      reporterId: reporterId ?? this.reporterId,
      reporterEmail: reporterEmail ?? this.reporterEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      imageUrls: imageUrls ?? this.imageUrls,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
