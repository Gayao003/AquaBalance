import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import '../models/io_models.dart';
import '../models/hive_adapters.dart';

/// HybridSyncService provides offline-first functionality with Firebase sync
///
/// Architecture:
/// - User must be online to login initially
/// - After login, data stored locally in Hive
/// - When online: sync local → Firebase, pull Firebase → local
/// - When offline: work locally only
/// - Multi-device: same account pulls data from Firebase on login
class HybridSyncService {
  static final HybridSyncService _instance = HybridSyncService._internal();

  factory HybridSyncService() {
    return _instance;
  }

  HybridSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  late Box<IntakeEntry> _intakeBox;
  late Box<OutputEntry> _outputBox;
  late Box<DailyFluidSummary> _summaryBox;
  late Box<UserFluidRange> _rangeBox;

  bool _isOnline = true;
  final List<Future<void> Function()> _syncQueue = [];

  /// Initialize Hive boxes and check connectivity
  Future<void> initialize() async {
    try {
      // Register Hive adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(IntakeEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(OutputEntryAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(ShiftDataAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(DailyFluidSummaryAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(UserFluidRangeAdapter());
      }

      // Open boxes
      _intakeBox = await Hive.openBox<IntakeEntry>('intake_entries');
      _outputBox = await Hive.openBox<OutputEntry>('output_entries');
      _summaryBox = await Hive.openBox<DailyFluidSummary>('daily_summaries');
      _rangeBox = await Hive.openBox<UserFluidRange>('user_ranges');

      // Listen for connectivity changes
      _connectivity.onConnectivityChanged.listen((result) {
        _isOnline = result != ConnectivityResult.none;
        if (_isOnline) {
          _processSyncQueue();
        }
      });

      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
    } catch (e) {
      print('Error initializing HybridSyncService: $e');
    }
  }

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  /// Add intake entry locally and queue for sync
  Future<void> addIntakeEntry({
    required String userId,
    required double volume,
    required String fluidType,
    required String notes,
  }) async {
    final entry = IntakeEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      volume: volume,
      fluidType: fluidType,
      timestamp: DateTime.now(),
      notes: notes,
      shift: _getShift(DateTime.now()),
    );

    // Save locally first (offline-first)
    await _intakeBox.put(entry.id, entry);

    // Queue for sync if online
    if (_isOnline) {
      await _syncIntakeEntryToFirebase(entry);
    } else {
      _syncQueue.add(() => _syncIntakeEntryToFirebase(entry));
    }
  }

  /// Add output entry locally and queue for sync
  Future<void> addOutputEntry({
    required String userId,
    required double volume,
    required String outputType,
    required String notes,
  }) async {
    final entry = OutputEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      volume: volume,
      outputType: outputType,
      timestamp: DateTime.now(),
      notes: notes,
      shift: _getShift(DateTime.now()),
    );

    // Save locally first (offline-first)
    await _outputBox.put(entry.id, entry);

    // Queue for sync if online
    if (_isOnline) {
      await _syncOutputEntryToFirebase(entry);
    } else {
      _syncQueue.add(() => _syncOutputEntryToFirebase(entry));
    }
  }

  /// Get daily summary from local storage
  Future<DailyFluidSummary?> getDailySummary({
    required String userId,
    required DateTime date,
  }) async {
    try {
      // Check local cache first
      final key = '${userId}_${date.year}-${date.month}-${date.day}';
      final cached = _summaryBox.get(key);
      if (cached != null) {
        return cached;
      }

      // Calculate from entries
      final intakeEntries = _getIntakeEntriesForDate(userId, date);
      final outputEntries = _getOutputEntriesForDate(userId, date);

      if (intakeEntries.isEmpty && outputEntries.isEmpty) {
        return null;
      }

      double totalIntake = intakeEntries.fold(0, (sum, e) => sum + e.volume);
      double totalOutput = outputEntries.fold(0, (sum, e) => sum + e.volume);

      // Calculate shift data
      final morningIntake = intakeEntries
          .where((e) => e.shift == 'morning')
          .fold(0.0, (sum, e) => sum + e.volume);
      final morningOutput = outputEntries
          .where((e) => e.shift == 'morning')
          .fold(0.0, (sum, e) => sum + e.volume);

      final afternoonIntake = intakeEntries
          .where((e) => e.shift == 'afternoon')
          .fold(0.0, (sum, e) => sum + e.volume);
      final afternoonOutput = outputEntries
          .where((e) => e.shift == 'afternoon')
          .fold(0.0, (sum, e) => sum + e.volume);

      final nightIntake = intakeEntries
          .where((e) => e.shift == 'night')
          .fold(0.0, (sum, e) => sum + e.volume);
      final nightOutput = outputEntries
          .where((e) => e.shift == 'night')
          .fold(0.0, (sum, e) => sum + e.volume);

      final summary = DailyFluidSummary(
        date: date,
        totalIntake: totalIntake,
        totalOutput: totalOutput,
        intakeStatus: _getStatus(totalIntake, 1500), // Default target
        outputStatus: _getStatus(totalOutput, 1500),
        intakeEntries: intakeEntries,
        outputEntries: outputEntries,
        morningShift: ShiftData(
          totalIntake: morningIntake,
          totalOutput: morningOutput,
          intakeCount: intakeEntries.where((e) => e.shift == 'morning').length,
          outputCount: outputEntries.where((e) => e.shift == 'morning').length,
        ),
        afternoonShift: ShiftData(
          totalIntake: afternoonIntake,
          totalOutput: afternoonOutput,
          intakeCount: intakeEntries
              .where((e) => e.shift == 'afternoon')
              .length,
          outputCount: outputEntries
              .where((e) => e.shift == 'afternoon')
              .length,
        ),
        nightShift: ShiftData(
          totalIntake: nightIntake,
          totalOutput: nightOutput,
          intakeCount: intakeEntries.where((e) => e.shift == 'night').length,
          outputCount: outputEntries.where((e) => e.shift == 'night').length,
        ),
      );

      // Cache the summary
      await _summaryBox.put(key, summary);
      return summary;
    } catch (e) {
      print('Error getting daily summary: $e');
      return null;
    }
  }

  /// Sync user's Firebase data to local storage (called on login)
  Future<void> syncFromFirebase(String userId) async {
    if (!_isOnline) {
      print('Cannot sync: offline');
      return;
    }

    try {
      // Fetch intake entries from Firebase
      final intakeSnapshot = await _firestore
          .collection('intake_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(500) // Limit to last 500 entries
          .get();

      for (var doc in intakeSnapshot.docs) {
        final entry = IntakeEntry.fromJson(doc.data());
        await _intakeBox.put(entry.id, entry);
      }

      // Fetch output entries from Firebase
      final outputSnapshot = await _firestore
          .collection('output_entries')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(500)
          .get();

      for (var doc in outputSnapshot.docs) {
        final entry = OutputEntry.fromJson(doc.data());
        await _outputBox.put(entry.id, entry);
      }

      // Fetch user ranges
      final rangeDoc = await _firestore
          .collection('user_ranges')
          .doc(userId)
          .get();

      if (rangeDoc.exists) {
        final range = UserFluidRange.fromJson(rangeDoc.data()!);
        await _rangeBox.put(userId, range);
      }

      print('Successfully synced data from Firebase');
    } catch (e) {
      print('Error syncing from Firebase: $e');
    }
  }

  /// Process queued sync operations when coming online
  Future<void> _processSyncQueue() async {
    while (_syncQueue.isNotEmpty && _isOnline) {
      final syncOp = _syncQueue.removeAt(0);
      try {
        await syncOp();
      } catch (e) {
        print('Sync operation failed: $e');
        _syncQueue.insert(0, syncOp); // Re-queue on failure
        break;
      }
    }
  }

  /// Sync intake entry to Firebase
  Future<void> _syncIntakeEntryToFirebase(IntakeEntry entry) async {
    if (!_isOnline) return;

    try {
      await _firestore
          .collection('intake_entries')
          .doc(entry.id)
          .set(entry.toJson());
    } catch (e) {
      print('Error syncing intake entry: $e');
      throw e;
    }
  }

  /// Sync output entry to Firebase
  Future<void> _syncOutputEntryToFirebase(OutputEntry entry) async {
    if (!_isOnline) return;

    try {
      await _firestore
          .collection('output_entries')
          .doc(entry.id)
          .set(entry.toJson());
    } catch (e) {
      print('Error syncing output entry: $e');
      throw e;
    }
  }

  /// Get intake entries for a specific date from local storage
  List<IntakeEntry> _getIntakeEntriesForDate(String userId, DateTime date) {
    return _intakeBox.values
        .where(
          (entry) =>
              entry.userId == userId &&
              entry.timestamp.year == date.year &&
              entry.timestamp.month == date.month &&
              entry.timestamp.day == date.day,
        )
        .toList();
  }

  /// Get output entries for a specific date from local storage
  List<OutputEntry> _getOutputEntriesForDate(String userId, DateTime date) {
    return _outputBox.values
        .where(
          (entry) =>
              entry.userId == userId &&
              entry.timestamp.year == date.year &&
              entry.timestamp.month == date.month &&
              entry.timestamp.day == date.day,
        )
        .toList();
  }

  /// Determine shift based on hour
  String _getShift(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour >= 6 && hour < 14) {
      return 'morning';
    } else if (hour >= 14 && hour < 22) {
      return 'afternoon';
    } else {
      return 'night';
    }
  }

  /// Determine fluid status
  FluidStatus _getStatus(double value, double target) {
    if (value >= target * 0.9 && value <= target * 1.1) {
      return FluidStatus.within;
    } else if (value < target * 0.9) {
      return FluidStatus.below;
    } else {
      return FluidStatus.above;
    }
  }

  /// Clear all local data
  Future<void> clearAllData() async {
    await _intakeBox.clear();
    await _outputBox.clear();
    await _summaryBox.clear();
    await _rangeBox.clear();
  }
}
