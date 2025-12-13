import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';
import 'package:gradecalculator/services/local_storage_service.dart';
import 'connectivity_service.dart';

/// Represents a queued offline operation
class OfflineOperation {
  final String id;
  final String type; // 'course', 'component', 'updateCourse', 'updateComponent'
  final Map<String, dynamic> data;
  final DateTime timestamp;

  OfflineOperation({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'data': data,
    'timestamp': timestamp.toIso8601String(),
  };

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'],
      type: json['type'],
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Service to manage offline operations queue and synchronization
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;

  OfflineQueueService._internal() {
    _initialize();
  }

  final ConnectivityService _connectivityService = ConnectivityService();
  final LocalStorageService _localStorage = LocalStorageService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isSyncing = false;
  StreamSubscription? _connectivitySubscription;

  Future<void> _initialize() async {
    // Listen for connectivity changes to auto-sync
    _connectivitySubscription = _connectivityService.statusStream.listen((
      isOnline,
    ) async {
      if (isOnline && pendingCount > 0) {
        print('📡 Connection restored, syncing $pendingCount operations...');
        await syncQueue();
      }
    });

    // Try initial sync if online
    if (_connectivityService.isOnline && pendingCount > 0) {
      await syncQueue();
    }
  }

  /// Add operation to offline queue
  Future<void> queueOperation(OfflineOperation operation) async {
    await _localStorage.queueOperation(operation.toJson());
    print('➕ Queued ${operation.type} operation: ${operation.id}');
  }

  /// Get number of pending operations
  int get pendingCount => _localStorage.queuedOperationsCount;

  /// Sync all queued operations when online
  Future<void> syncQueue() async {
    if (_isSyncing || pendingCount == 0 || !_connectivityService.isOnline) {
      return;
    }

    _isSyncing = true;
    final operations = _localStorage.getQueuedOperations();
    print('🔄 Starting sync of ${operations.length} operations...');

    int successCount = 0;
    int failCount = 0;

    for (final opJson in operations) {
      try {
        final operation = OfflineOperation.fromJson(opJson);
        await _executeOperation(operation);
        await _localStorage.removeQueuedOperation(operation.id);
        successCount++;
        print('✅ Synced ${operation.type}: ${operation.id}');
      } catch (e) {
        failCount++;
        print('❌ Failed to sync operation: $e');
      }
    }

    _isSyncing = false;

    if (failCount == 0) {
      print('✨ All $successCount operations synced successfully!');
      await _localStorage.setLastFirebaseSync();
    } else {
      print('⚠️ Sync complete: $successCount succeeded, $failCount failed');
    }
  }

  Future<void> _executeOperation(OfflineOperation operation) async {
    switch (operation.type) {
      case 'course':
        await _syncCourse(operation.data);
        break;
      case 'component':
        await _syncComponent(operation.data);
        break;
      case 'updateCourse':
        await _syncCourseUpdate(operation.data);
        break;
      case 'updateComponent':
        await _syncComponentUpdate(operation.data);
        break;
      case 'deleteComponent':
        await _syncComponentDelete(operation.data);
        break;
      case 'deleteCourse':
        await _syncCourseDelete(operation.data);
        break;
      default:
        print('⚠️ Unknown operation type: ${operation.type}');
    }
  }

  Future<void> _syncCourse(Map<String, dynamic> data) async {
    final course = Course.fromMap(data);
    await _db.collection('courses').doc(course.courseId).set(course.toMap());
  }

  Future<void> _syncComponent(Map<String, dynamic> data) async {
    final componentData = Map<String, dynamic>.from(data['component'] as Map);
    final recordsData =
        (data['records'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final component = Component.fromMap(componentData);

    // Create component
    await _db
        .collection('components')
        .doc(component.componentId)
        .set(component.toMap());

    // Create records in batch
    final batch = _db.batch();
    for (final recordData in recordsData) {
      final record = Records.fromMap(recordData);
      final recordDocRef = _db.collection('records').doc(record.recordId);
      batch.set(recordDocRef, record.toMap());
    }
    await batch.commit();
  }

  Future<void> _syncCourseUpdate(Map<String, dynamic> data) async {
    final courseId = data['courseId'] as String;
    final updates = Map<String, dynamic>.from(data['updates'] as Map);
    try {
      await _db.collection('courses').doc(courseId).update(updates);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        print(
          '⚠️ Course $courseId not found in Firebase (may have been deleted)',
        );
        // Silently skip - document was already deleted
      } else {
        rethrow;
      }
    }
  }

  Future<void> _syncComponentUpdate(Map<String, dynamic> data) async {
    final componentId = data['componentId'] as String;
    final componentData = Map<String, dynamic>.from(data['component'] as Map);
    final recordsData =
        (data['records'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    // Update component
    try {
      await _db.collection('components').doc(componentId).update(componentData);
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        print(
          '⚠️ Component $componentId not found in Firebase (may have been deleted)',
        );
        return; // Skip the rest - component was deleted
      } else {
        rethrow;
      }
    }

    // Delete existing records and create new ones
    final existingRecordsSnapshot =
        await _db
            .collection('records')
            .where('componentId', isEqualTo: componentId)
            .get();

    final batch = _db.batch();

    // Delete old records
    for (final doc in existingRecordsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Create new records
    for (final recordData in recordsData) {
      final record = Records.fromMap(recordData);
      final recordDocRef = _db.collection('records').doc(record.recordId);
      batch.set(recordDocRef, record.toMap());
    }

    await batch.commit();
  }

  Future<void> _syncComponentDelete(Map<String, dynamic> data) async {
    final componentId = data['componentId'] as String;

    try {
      // Delete all records for this component
      final recordsSnapshot =
          await _db
              .collection('records')
              .where('componentId', isEqualTo: componentId)
              .get();

      final batch = _db.batch();
      for (final doc in recordsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the component
      batch.delete(_db.collection('components').doc(componentId));

      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        print('⚠️ Component $componentId already deleted from Firebase');
        // Silently skip - already deleted
      } else {
        rethrow;
      }
    }
  }

  Future<void> _syncCourseDelete(Map<String, dynamic> data) async {
    final courseId = data['courseId'] as String;

    try {
      // Delete all components and their records for this course
      final componentsSnapshot =
          await _db
              .collection('components')
              .where('courseId', isEqualTo: courseId)
              .get();

      final batch = _db.batch();

      for (final componentDoc in componentsSnapshot.docs) {
        final componentId = componentDoc.id;

        // Delete records for this component
        final recordsSnapshot =
            await _db
                .collection('records')
                .where('componentId', isEqualTo: componentId)
                .get();

        for (final recordDoc in recordsSnapshot.docs) {
          batch.delete(recordDoc.reference);
        }

        // Delete the component
        batch.delete(componentDoc.reference);
      }

      // Delete the course
      batch.delete(_db.collection('courses').doc(courseId));

      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') {
        print('⚠️ Course $courseId already deleted from Firebase');
        // Silently skip - already deleted
      } else {
        rethrow;
      }
    }
  }

  /// Clear all pending operations (use with caution)
  Future<void> clearQueue() async {
    await _localStorage.clearQueue();
    print('🗑️ Cleared offline queue');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
