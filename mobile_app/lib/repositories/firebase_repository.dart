import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/emergency_contact.dart';
import '../models/incident.dart';
import '../models/user_profile.dart';

/// Repository layer isolating Firebase Auth & Cloud Firestore calls.
/// When Firebase is not initialized (e.g. local unit tests or unconfigured
/// developer machines), operations return cleanly without crashing.
class FirebaseRepository {
  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;

  FirebaseAuth? get _auth =>
      isFirebaseInitialized ? FirebaseAuth.instance : null;
  FirebaseFirestore? get _db =>
      isFirebaseInitialized ? FirebaseFirestore.instance : null;

  User? get currentFirebaseUser => _auth?.currentUser;

  Future<String?> signInWithEmail(String email, String password) async {
    if (_auth == null) return null;
    final cred = await _auth!.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return cred.user?.uid;
  }

  Future<String?> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_auth == null) return null;
    final cred = await _auth!.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(displayName.trim());
    await cred.user?.sendEmailVerification();
    return cred.user?.uid;
  }

  Future<void> sendPasswordReset(String email) async {
    if (_auth == null) return;
    await _auth!.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    if (_db == null) return;
    await _db!
        .collection('users')
        .doc(profile.uid)
        .set(profile.toMap(), SetOptions(merge: true));
  }

  Future<void> saveContact(String uid, EmergencyContact contact) async {
    if (_db == null) return;
    await _db!
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(contact.id)
        .set(contact.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteContact(String uid, String contactId) async {
    if (_db == null) return;
    await _db!
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .doc(contactId)
        .delete();
  }

  Future<void> saveIncident(Incident incident) async {
    if (_db == null) return;
    await _db!
        .collection('incidents')
        .doc(incident.id)
        .set(incident.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteIncident(String incidentId) async {
    if (_db == null) return;
    await _db!.collection('incidents').doc(incidentId).delete();
  }

  Future<void> deleteAllUserData(String uid) async {
    if (_db == null) return;
    final contacts = await _db!
        .collection('users')
        .doc(uid)
        .collection('contacts')
        .get();
    final batch = _db!.batch();
    for (final doc in contacts.docs) {
      batch.delete(doc.reference);
    }
    final incidents = await _db!
        .collection('incidents')
        .where('userId', isEqualTo: uid)
        .get();
    for (final doc in incidents.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db!.collection('users').doc(uid));
    await batch.commit();
    await _auth?.currentUser?.delete();
  }
}
