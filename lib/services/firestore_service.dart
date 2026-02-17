import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple Firestore helpers for common CRUD operations.
///
/// Usage examples:
/// - Add: `await FirestoreService.add('users', {'name': 'Alice'});`
/// - Set: `await FirestoreService.set('users/uid', {'name': 'Bob'});`
/// - Update: `await FirestoreService.update('users/uid', {'age': 30});`
/// - Delete: `await FirestoreService.delete('users/uid');`
/// - Stream collection: `FirestoreService.collectionStream('users')`
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Adds a new document to [collectionPath]. Returns the created DocumentReference.
  static Future<DocumentReference> add(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    try {
      final ref = await _db.collection(collectionPath).add(data);
      return ref;
    } on FirebaseException {
      rethrow;
    }
  }

  /// Sets data at a document path (e.g. `users/uid`). Use [merge] to merge.
  static Future<void> set(
    String docPath,
    Map<String, dynamic> data, {
    bool merge = false,
  }) async {
    try {
      final ref = _db.doc(docPath);
      await ref.set(data, SetOptions(merge: merge));
    } on FirebaseException {
      rethrow;
    }
  }

  /// Updates fields on an existing document.
  static Future<void> update(String docPath, Map<String, dynamic> data) async {
    try {
      final ref = _db.doc(docPath);
      await ref.update(data);
    } on FirebaseException {
      rethrow;
    }
  }

  /// Deletes a document at [docPath].
  static Future<void> delete(String docPath) async {
    try {
      final ref = _db.doc(docPath);
      await ref.delete();
    } on FirebaseException {
      rethrow;
    }
  }

  /// Returns a stream of QuerySnapshot for a collection path.
  static Stream<QuerySnapshot> collectionStream(String collectionPath) {
    return _db.collection(collectionPath).snapshots().handleError((error) {
      if (error is FirebaseException && error.code == 'permission-denied') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message:
              'Permission denied when reading "$collectionPath". Ensure Firestore rules allow reads or authenticate the user before querying.',
        );
      }
      throw error;
    });
  }

  /// Reads a single document once. Returns null if not found.
  static Future<DocumentSnapshot?> getDocument(String docPath) async {
    try {
      final snap = await _db.doc(docPath).get();
      if (snap.exists) return snap;
      return null;
    } on FirebaseException {
      rethrow;
    }
  }
}
