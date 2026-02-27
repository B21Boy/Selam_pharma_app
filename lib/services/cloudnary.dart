import 'dart:convert';
import 'dart:io';
// 'dart:typed_data' is provided via 'package:flutter/foundation.dart'.
// Removed explicit import to satisfy analyzer.
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;

/// Cloudinary helper utilities.
///
/// This service reads Cloudinary configuration from environment variables:
/// - `CLOUDINARY_CLOUD_NAME`
/// - `CLOUDINARY_UPLOAD_PRESET`
///
/// If those aren't provided, the original hard-coded defaults are used as
/// a fallback.
class CloudinaryService {
  // Helper that safely reads from dotenv, returning `fallback` if the
  // environment hasn't been loaded yet or if any error occurs. Without this
  // guard reading `dotenv.env` throws [NotInitializedError], which was
  // causing image uploads to fail during early sync when the .env file could
  // not be loaded.
  static String _safeEnv(String key, String fallback) {
    try {
      return dotenv.env[key] ?? fallback;
    } catch (e) {
      // dotenv wasn't initialized yet (or another issue); fall back.
      debugPrint(
        'CloudinaryService: dotenv not initialized while reading $key, using fallback',
      );
      return fallback;
    }
  }

  // Fallback defaults (preserve previous behavior if dotenv not loaded)
  static String get _cloudName =>
      _safeEnv('CLOUDINARY_CLOUD_NAME', 'dwfz6c6x0');

  static String get _uploadPreset =>
      _safeEnv('CLOUDINARY_UPLOAD_PRESET', 'pharmacy_app');

  /// Uploads a `File` to Cloudinary. Returns the secure URL on success.
  ///
  /// Throws an [HttpException] on network/HTTP errors or a [FormatException]
  /// if the response can't be parsed.
  static Future<Map<String, String>> uploadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final filename = imageFile.path.split(Platform.pathSeparator).last;
    return uploadImageBytes(bytes, filename);
  }

  /// Uploads raw image bytes to Cloudinary. Provide a filename (e.g. "img.jpg").
  /// Returns a map with keys `secure_url` and `public_id` on success or throws on failure.
  static Future<Map<String, String>> uploadImageBytes(
    Uint8List bytes,
    String filename,
  ) async {
    // Build upload URL
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    // Prepare multipart request
    final request = http.MultipartRequest('POST', url);
    request.fields['upload_preset'] = _uploadPreset;

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    );

    request.files.add(multipartFile);

    // Send request and parse response
    debugPrint(
      'CloudinaryService: starting upload to ${url.toString()} (preset=$_uploadPreset)',
    );
    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();
    debugPrint('CloudinaryService: upload HTTP ${streamedResponse.statusCode}');

    if (streamedResponse.statusCode >= 200 &&
        streamedResponse.statusCode < 300) {
      try {
        final jsonData = jsonDecode(responseBody);
        if (jsonData is Map && jsonData.containsKey('secure_url')) {
          final imageUrl = jsonData['secure_url'] as String;
          final publicId = jsonData['public_id']?.toString();
          debugPrint(
            'Cloudinary upload successful: $imageUrl (public_id=$publicId)',
          );
          return {'secure_url': imageUrl, 'public_id': publicId ?? ''};
        } else {
          final available = jsonData.keys.join(', ');
          final msg =
              'Unexpected Cloudinary response: missing secure_url. Keys: $available. Body: $responseBody';
          debugPrint('CloudinaryService: $msg');
          throw FormatException(msg);
        }
      } catch (e) {
        debugPrint('CloudinaryService: failed to parse response: $e');
        rethrow;
      }
    } else {
      // Try to include any error info from the body
      String message =
          'Cloudinary upload failed (status ${streamedResponse.statusCode})';
      try {
        final err = jsonDecode(responseBody);
        message += ': $err';
      } catch (_) {
        message += ': $responseBody';
      }
      debugPrint('CloudinaryService: upload error: $message');
      throw HttpException(message);
    }
  }

  /// Deletes an image from Cloudinary by its `publicId`.
  /// Requires `CLOUDINARY_API_KEY` and `CLOUDINARY_API_SECRET` to be present in env.
  static Future<void> deleteImage(String publicId) async {
    // reading the credentials may also throw if dotenv is uninitialized, so
    // we'll use our helper so the call fails gracefully in offline/early-start
    // situations.  We still require both values to be non-empty, however.
    final apiKey = _safeEnv('CLOUDINARY_API_KEY', '');
    final apiSecret = _safeEnv('CLOUDINARY_API_SECRET', '');
    if (apiKey.isEmpty || apiSecret.isEmpty) {
      throw StateError(
        'CLOUDINARY_API_KEY and CLOUDINARY_API_SECRET required to delete images',
      );
    }

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toString();
    final toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    // compute sha1 signature
    final sig = _sha1Hex(toSign);

    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/destroy',
    );
    final response = await http.post(
      url,
      body: {
        'public_id': publicId,
        'api_key': apiKey,
        'timestamp': timestamp,
        'signature': sig,
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Cloudinary delete failed: ${response.statusCode} ${response.body}',
      );
    }
    final jsonData = jsonDecode(response.body);
    if (jsonData['result'] != 'ok' && jsonData['result'] != 'not found') {
      throw HttpException('Cloudinary delete unexpected result: $jsonData');
    }
  }

  static String _sha1Hex(String input) {
    // Lazy import of crypto to avoid adding on top-level if not available
    // Use package:crypto
    final bytes = utf8.encode(input);
    final digest = crypto.sha1.convert(bytes);
    return digest.toString();
  }
}
