import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class TutorialService {
  static final TutorialService _instance = TutorialService._internal();

  factory TutorialService() => _instance;

  TutorialService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();

  Future<bool> shouldShowPageTutorial(String pageId) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return false;

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final seenMap = (data?['tutorialSeenPages'] as Map?) ?? const {};
      return seenMap[pageId] != true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markPageTutorialSeen(String pageId) async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    await _firestore.collection('users').doc(userId).set({
      'tutorialSeenPages': {pageId: true},
      'lastUpdated': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> resetAllTutorials() async {
    final userId = _authService.currentUser?.uid ?? '';
    if (userId.isEmpty) return;

    await _firestore.collection('users').doc(userId).set({
      'tutorialSeenPages': <String, bool>{},
      'lastUpdated': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
