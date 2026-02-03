import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hydration_models.dart';

class CheckInService {
  static final CheckInService _instance = CheckInService._internal();

  factory CheckInService() => _instance;

  CheckInService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('checkins');
  }

  Future<void> addCheckIn(String userId, HydrationCheckIn checkIn) async {
    await _collection(
      userId,
    ).doc(checkIn.id).set(checkIn.toJson(), SetOptions(merge: true));
  }

  Stream<List<HydrationCheckIn>> watchCheckInsInRange(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _collection(userId)
        .where('timestamp', isGreaterThanOrEqualTo: start.toIso8601String())
        .where('timestamp', isLessThanOrEqualTo: end.toIso8601String())
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HydrationCheckIn.fromJson(doc.data()))
              .toList(),
        );
  }
}
