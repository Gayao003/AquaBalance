import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hydration_models.dart';

class TemplateService {
  static final TemplateService _instance = TemplateService._internal();

  factory TemplateService() => _instance;

  TemplateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _collection(String userId) {
    return _firestore.collection('users').doc(userId).collection('templates');
  }

  Stream<List<HydrationTemplate>> watchTemplates(String userId) {
    return _collection(userId).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => HydrationTemplate.fromJson(doc.data()))
          .toList(),
    );
  }

  Future<void> addTemplate(String userId, HydrationTemplate template) async {
    await _collection(
      userId,
    ).doc(template.id).set(template.toJson(), SetOptions(merge: true));
  }
}
