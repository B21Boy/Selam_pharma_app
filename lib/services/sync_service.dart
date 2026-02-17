import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/medicine.dart';
import 'cloudnary.dart';

/// SyncService keeps Hive `medicines` box, Firestore per-user
/// `users/{uid}/medicines` collection, and Cloudinary images in sync.
class SyncService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Box<Medicine>? _medicineBox;
  StreamSubscription? _hiveSub;
  StreamSubscription? _firestoreSub;
  StreamSubscription<User?>? _authSub;
  String? _uid;
  // Stream of human-readable Firestore error messages for UI diagnostics.
  final _errorController = StreamController<String?>.broadcast();

  Stream<String?> get errorStream => _errorController.stream;

  // local caches and guards to avoid cycles
  final Map<String, Medicine> _lastKnown = {};
  final Set<String> _updatingFromFirestore = {};
  final Set<String> _updatingFromHive = {};

  Future<void> init() async {
    debugPrint(
      'SyncService: initializing (will open per-user Hive box on auth)',
    );

    // Listen for auth changes and open/close per-user Hive boxes.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final newUid = user?.uid;
      final oldUid = _uid;

      // If UID changed in any way, close previous box and open a new per-user box.
      if (oldUid != newUid) {
        // close and cancel previous hive watcher
        try {
          await _hiveSub?.cancel();
        } catch (_) {}
        try {
          if (_medicineBox != null && _medicineBox!.isOpen) {
            await _medicineBox!.close();
          }
        } catch (e) {
          debugPrint('SyncService: error closing previous box: $e');
        }

        _lastKnown.clear();

        // open new box for this uid (use 'medicines_guest' when uid is null)
        final boxName = _boxNameForUid(newUid);
        try {
          _medicineBox = await Hive.openBox<Medicine>(boxName);
          // prime cache from this user's local box
          for (final m in _medicineBox!.values) {
            _lastKnown[m.id] = m;
          }
          _hiveSub = _medicineBox!.watch().listen(_onHiveEvent);
        } catch (e) {
          debugPrint('SyncService: failed to open box $boxName: $e');
          _medicineBox = null;
        }
      }

      _uid = newUid;
      _attachFirestoreListener();
    });
  }

  String _boxNameForUid(String? uid) =>
      uid == null ? 'medicines_guest' : 'medicines_$uid';

  Future<void> dispose() async {
    await _hiveSub?.cancel();
    await _firestoreSub?.cancel();
    await _authSub?.cancel();
  }

  void _attachFirestoreListener() {
    _firestoreSub?.cancel();
    if (_uid == null) return;
    _firestoreSub = _db
        .collection('users')
        .doc(_uid)
        .collection('medicines')
        .snapshots()
        .listen(_onFirestoreSnapshot, onError: _onFirestoreError);
  }

  void _onFirestoreError(Object e) {
    final msg = e.toString();
    debugPrint('SyncService: firestore listener error: $msg');
    try {
      _errorController.add(msg);
    } catch (_) {}
    // Common recoverable errors: permission-denied (rules), unavailable (network).
    // Don't rethrow — keep app running. Consider notifying user or signing out
    // if permission issues persist.
  }

  /// Clear the last reported Firestore error (UI helper).
  void clearError() {
    try {
      _errorController.add(null);
    } catch (_) {}
  }

  void _onHiveEvent(BoxEvent event) async {
    final id = event.key as String;
    debugPrint('SyncService: Hive event for id=$id deleted=${event.deleted}');
    if (_updatingFromFirestore.remove(id)) {
      // change originated from Firestore apply; ignore
      debugPrint(
        'SyncService: ignoring hive event for $id because updatingFromFirestore',
      );
      return;
    }

    if (event.deleted) {
      final old = _lastKnown[id];
      _lastKnown.remove(id);
      await _handleLocalDelete(id, old);
      return;
    }

    final medicine = _medicineBox?.get(id);
    debugPrint('SyncService: Hive put for id=$id');
    if (medicine == null) return;

    // update cache
    _lastKnown[id] = medicine;

    // skip if change was applied by sync service itself
    if (_updatingFromHive.contains(id)) {
      _updatingFromHive.remove(id);
      return;
    }

    await _handleLocalPut(medicine);
  }

  Future<void> _handleLocalPut(Medicine medicine) async {
    try {
      // If there's image bytes but no cloudinaryPublicId, upload image first
      if (medicine.imageBytes != null &&
          (medicine.cloudinaryPublicId == null ||
              medicine.cloudinaryPublicId!.isEmpty)) {
        debugPrint('SyncService: uploading image for medicine ${medicine.id}');
        final filename = '${medicine.id}.jpg';
        final res = await CloudinaryService.uploadImageBytes(
          medicine.imageBytes!,
          filename,
        );
        debugPrint('SyncService: upload result $res');
        medicine.imageUrl = res['secure_url'];
        medicine.cloudinaryPublicId = res['public_id'];
        medicine.lastModifiedMillis = DateTime.now().millisecondsSinceEpoch;
        _updatingFromHive.add(medicine.id);
        await medicine.save();
      }

      // Write to Firestore
      if (_uid == null) {
        debugPrint('SyncService: no user signed in, skipping firestore write');
        return;
      }

      final docRef = _db
          .collection('users')
          .doc(_uid)
          .collection('medicines')
          .doc(medicine.id);
      final data = {
        'id': medicine.id,
        'name': medicine.name,
        'totalQty': medicine.totalQty,
        'buyPrice': medicine.buyPrice,
        'sellPrice': medicine.sellPrice,
        'soldQty': medicine.soldQty,
        'category': medicine.category,
        'barcode': medicine.barcode,
        'imageUrl': medicine.imageUrl,
        'cloudinaryPublicId': medicine.cloudinaryPublicId,
        'lastModifiedMillis':
            medicine.lastModifiedMillis ??
            DateTime.now().millisecondsSinceEpoch,
      };

      debugPrint('SyncService: writing medicine ${medicine.id} to firestore');
      _updatingFromHive.add(medicine.id);
      await docRef.set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SyncService._handleLocalPut error: $e');
    }
  }

  Future<void> _handleLocalDelete(String id, Medicine? old) async {
    try {
      // delete in firestore
      if (_uid == null) {
        debugPrint('SyncService: no user signed in, skipping firestore delete');
        return;
      }

      final docRef = _db
          .collection('users')
          .doc(_uid)
          .collection('medicines')
          .doc(id);
      // attempt to delete cloudinary image if known
      final publicId = old?.cloudinaryPublicId;
      if (publicId != null && publicId.isNotEmpty) {
        debugPrint(
          'SyncService: deleting cloudinary image for $id publicId=$publicId',
        );
        try {
          await CloudinaryService.deleteImage(publicId);
        } catch (e) {
          debugPrint('Cloudinary delete error for $publicId: $e');
        }
      }

      _updatingFromHive.add(id);
      await docRef.delete();
    } catch (e) {
      debugPrint('SyncService._handleLocalDelete error: $e');
    }
  }

  void _onFirestoreSnapshot(QuerySnapshot snap) async {
    for (final change in snap.docChanges) {
      final doc = change.doc;
      final id = doc.id;
      debugPrint('SyncService: firestore change type=${change.type} id=$id');

      if (_updatingFromHive.remove(id)) {
        // change was originated from Hive write, ignore
        continue;
      }

      if (change.type == DocumentChangeType.removed) {
        // remove locally
        if (_medicineBox?.containsKey(id) == true) {
          _updatingFromFirestore.add(id);
          await _medicineBox?.delete(id);
          _lastKnown.remove(id);
        }
        continue;
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final remoteLast = (data['lastModifiedMillis'] as int?) ?? 0;
      final local = _medicineBox?.get(id);
      final localLast = local?.lastModifiedMillis ?? 0;
      if (local != null && localLast >= remoteLast) {
        // local is newer or equal, skip applying remote
        continue;
      }

      // construct medicine from remote
      final newMed = Medicine(
        id: data['id'] as String? ?? id,
        name: data['name'] as String? ?? '',
        totalQty: (data['totalQty'] as int?) ?? 0,
        buyPrice: (data['buyPrice'] as int?) ?? 0,
        sellPrice: (data['sellPrice'] as int?) ?? 0,
        imageBytes: null,
        soldQty: (data['soldQty'] as int?) ?? 0,
        category: data['category'] as String? ?? 'Others',
        barcode: data['barcode'] as String?,
      );

      newMed.imageUrl = data['imageUrl'] as String?;
      newMed.cloudinaryPublicId = data['cloudinaryPublicId'] as String?;
      newMed.lastModifiedMillis = remoteLast > 0
          ? remoteLast
          : DateTime.now().millisecondsSinceEpoch;

      // if imageUrl exists, try to download bytes
      if (newMed.imageUrl != null && newMed.imageUrl!.isNotEmpty) {
        try {
          final resp = await http.get(Uri.parse(newMed.imageUrl!));
          if (resp.statusCode == 200) newMed.imageBytes = resp.bodyBytes;
        } catch (e) {
          debugPrint('Failed to download image for $id: $e');
        }
      }

      _updatingFromFirestore.add(id);
      await _medicineBox?.put(id, newMed);
      _lastKnown[id] = newMed;
    }
  }
}
