import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';
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

  static const String _queueKey = 'offline_operations_queue';
  final ConnectivityService _connectivityService = ConnectivityService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  List<OfflineOperation> _queue = [];
  bool _isSyncing = false;

  StreamSubscription? _connectivitySubscription;

  Future<void> _initialize() async {
    await _loadQueue();
    
    // Listen for connectivity changes to auto-sync
    _connectivitySubscription = _connectivityService.statusStream.listen((isOnline) {
      if (isOnline && _queue.isNotEmpty) {
        print('📡 Connection restored, syncing ${_queue.length} operations...');
        syncQueue();
      }
    });

    // Try initial sync if online
    if (_connectivityService.isOnline && _queue.isNotEmpty) {
      syncQueue();
    }
  }

  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);
      
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded.map((item) => OfflineOperation.fromJson(item)).toList();
        print('📥 Loaded ${_queue.length} offline operations from storage');
      }
    } catch (e) {
      print('❌ Error loading offline queue: $e');
      _queue = [];
    }
  }

  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((op) => op.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
      print('💾 Saved ${_queue.length} operations to offline queue');
    } catch (e) {
      print('❌ Error saving offline queue: $e');
    }
  }

  /// Add operation to offline queue
  Future<void> queueOperation(OfflineOperation operation) async {
    _queue.add(operation);
    await _saveQueue();
    print('➕ Queued ${operation.type} operation: ${operation.id}');
  }

  /// Get number of pending operations
  int get pendingCount => _queue.length;

  /// Sync all queued operations when online
  Future<void> syncQueue() async {
    if (_isSyncing || _queue.isEmpty || !_connectivityService.isOnline) {
      return;
    }

    _isSyncing = true;
    print('🔄 Starting sync of ${_queue.length} operations...');

    final failedOperations = <OfflineOperation>[];

    for (final operation in List.from(_queue)) {
      try {
        await _executeOperation(operation);
        print('✅ Synced ${operation.type}: ${operation.id}');
      } catch (e) {
        print('❌ Failed to sync ${operation.type} ${operation.id}: $e');
        failedOperations.add(operation);
      }
    }

    // Keep only failed operations in queue
    _queue = failedOperations;
    await _saveQueue();

    _isSyncing = false;
    
    if (failedOperations.isEmpty) {
      print('✨ All operations synced successfully!');
    } else {
      print('⚠️ ${failedOperations.length} operations failed, will retry later');
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
      default:
        print('⚠️ Unknown operation type: ${operation.type}');
    }
  }

  Future<void> _syncCourse(Map<String, dynamic> data) async {
    final course = Course.fromMap(data);
    await _db.collection('courses').doc(course.courseId).set(course.toMap());
  }

  Future<void> _syncComponent(Map<String, dynamic> data) async {
    final componentData = Map<String, dynamic>.from(data['component']);
    final recordsData = List<Map<String, dynamic>>.from(data['records']);
    
    final component = Component.fromMap(componentData);
    
    // Create component
    await _db.collection('components').doc(component.componentId).set(component.toMap());
    
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
    final updates = Map<String, dynamic>.from(data['updates']);
    await _db.collection('courses').doc(courseId).update(updates);
  }

  Future<void> _syncComponentUpdate(Map<String, dynamic> data) async {
    final componentId = data['componentId'] as String;
    final componentData = Map<String, dynamic>.from(data['component']);
    final recordsData = List<Map<String, dynamic>>.from(data['records']);
    
    // Update component
    await _db.collection('components').doc(componentId).update(componentData);
    
    // Delete existing records and create new ones
    final existingRecordsSnapshot = await _db
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

  /// Clear all pending operations (use with caution)
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
    print('🗑️ Cleared offline queue');
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
