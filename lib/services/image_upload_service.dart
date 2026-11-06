
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const String _bucketName = 'incident-images';

  Future<String> uploadIncidentImage({
    required XFile image,
    required String incidentId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('You must be logged in to upload an image.');
    }

    if (!user.emailVerified) {
      throw Exception('Verify your email before uploading images.');
    }

    final Uint8List imageBytes = await image.readAsBytes();

    // Maximum file size: 10 MB
    const int maxFileSize = 10 * 1024 * 1024;

    if (imageBytes.length > maxFileSize) {
      throw Exception('The image must be smaller than 10 MB.');
    }

    // Check the image type.
    final fileName = image.name.toLowerCase();

    final String contentType;

    if (fileName.endsWith('.jpg') ||
        fileName.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else if (fileName.endsWith('.png')) {
      contentType = 'image/png';
    } else {
      throw Exception('Only JPG and PNG images are allowed.');
    }

    // Store each image under the Firebase user's UID
    // and the corresponding incident ID.
    final timestamp = DateTime.now().microsecondsSinceEpoch;

    final extension =
        contentType == 'image/png' ? 'png' : 'jpg';

    final imagePath =
        '${user.uid}/$incidentId/$timestamp.$extension';

    await _supabase.storage.from(_bucketName).uploadBinary(
      imagePath,
      imageBytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    // Return the storage path, not a public URL.
    // We will save this path in Firestore.
    return imagePath;
  }
}
