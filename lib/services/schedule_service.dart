import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hydration_models.dart';

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();

  factory ScheduleService() => _instance;

  ScheduleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('schedules');
  }

  Stream<List<HydrationSchedule>> watchSchedules(String userId) {
    return _collection(userId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => HydrationSchedule.fromJson(doc.data()))
          .toList(),
    );
  }

  Future<void> upsertSchedule(String userId, HydrationSchedule schedule) async {
    await _collection(userId)
        .doc(schedule.id.toString())
        .set(schedule.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteSchedule(String userId, int id) async {
    await _collection(userId).doc(id.toString()).delete();
  }

  Future<void> replaceSchedules(
    String userId,
    List<HydrationSchedule> schedules,
  ) async {
    final batch = _firestore.batch();
    final existing = await _collection(userId).get();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }

    for (final schedule in schedules) {
      final ref = _collection(userId).doc(schedule.id.toString());
      batch.set(ref, schedule.toJson());
    }

    await batch.commit();
  }
}
