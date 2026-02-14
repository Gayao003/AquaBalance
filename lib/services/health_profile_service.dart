import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_profile.dart';

class HealthProfileService {
  static final HealthProfileService _instance =
      HealthProfileService._internal();

  factory HealthProfileService() {
    return _instance;
  }

  HealthProfileService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _healthProfilesCollection = 'health_profiles';

  /// Create a new health profile
  Future<HealthProfile> createHealthProfile({
    required String userId,
    required List<String> conditions,
    String? customCondition,
    int? reminderIntervalMinutes,
    String messageTone = 'neutral',
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection(_healthProfilesCollection).doc();

      final healthProfile = HealthProfile(
        id: docRef.id,
        userId: userId,
        conditions: conditions,
        customCondition: customCondition,
        reminderIntervalMinutes: reminderIntervalMinutes,
        messageTone: messageTone,
        isEnabled: true,
        createdAt: now,
        updatedAt: now,
      );

      await docRef.set(healthProfile.toJson());
      return healthProfile;
    } catch (e) {
      print('Error creating health profile: $e');
      rethrow;
    }
  }

  /// Get user's active health profile
  Future<HealthProfile?> getActiveHealthProfile(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_healthProfilesCollection)
          .where('userId', isEqualTo: userId)
          .where('isEnabled', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return HealthProfile.fromJson(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('Error getting active health profile: $e');
      return null;
    }
  }

  /// Get all health profiles for a user
  Future<List<HealthProfile>> getUserHealthProfiles(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_healthProfilesCollection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => HealthProfile.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error getting user health profiles: $e');
      return [];
    }
  }

  /// Stream of user's health profiles for real-time updates
  Stream<List<HealthProfile>> streamUserHealthProfiles(String userId) {
    return _firestore
        .collection(_healthProfilesCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs
              .map((doc) => HealthProfile.fromJson(doc.data()))
              .toList();
        })
        .handleError((error) {
          print('Error streaming health profiles: $error');
          return <HealthProfile>[];
        });
  }

  /// Update health profile
  Future<void> updateHealthProfile(HealthProfile profile) async {
    try {
      await _firestore
          .collection(_healthProfilesCollection)
          .doc(profile.id)
          .update({...profile.copyWith(updatedAt: DateTime.now()).toJson()});
    } catch (e) {
      print('Error updating health profile: $e');
      rethrow;
    }
  }

  /// Disable health profile
  Future<void> disableHealthProfile(String profileId) async {
    try {
      await _firestore
          .collection(_healthProfilesCollection)
          .doc(profileId)
          .update({
            'isEnabled': false,
            'updatedAt': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      print('Error disabling health profile: $e');
      rethrow;
    }
  }

  /// Enable health profile (disable others)
  Future<void> setActiveHealthProfile(String userId, String profileId) async {
    try {
      final batch = _firestore.batch();

      // Disable all profiles for this user
      final allProfiles = await _firestore
          .collection(_healthProfilesCollection)
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in allProfiles.docs) {
        batch.update(doc.reference, {
          'isEnabled': false,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }

      // Enable the selected profile
      batch.update(
        _firestore.collection(_healthProfilesCollection).doc(profileId),
        {'isEnabled': true, 'updatedAt': DateTime.now().toIso8601String()},
      );

      await batch.commit();
    } catch (e) {
      print('Error setting active health profile: $e');
      rethrow;
    }
  }

  /// Delete health profile
  Future<void> deleteHealthProfile(String profileId) async {
    try {
      await _firestore
          .collection(_healthProfilesCollection)
          .doc(profileId)
          .delete();
    } catch (e) {
      print('Error deleting health profile: $e');
      rethrow;
    }
  }
}
