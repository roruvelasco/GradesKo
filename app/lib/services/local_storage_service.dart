import 'package:hive_flutter/hive_flutter.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';
import 'package:gradecalculator/models/grading_system.dart';
import 'package:gradecalculator/models/grade_range.dart';

/// Service for managing local storage with Hive
/// Provides offline-first architecture with automatic persistence
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  // Box names
  static const String _coursesBox = 'courses';
  static const String _componentsBox = 'components';
  static const String _recordsBox = 'records';
  static const String _offlineQueueBox = 'offline_queue';
  static const String _metadataBox = 'metadata';

  // Lazy box accessors
  late Box<Course> _courses;
  late Box<Component> _components;
  late Box<Records> _records;
  late Box<Map<dynamic, dynamic>> _offlineQueue;
  late Box<dynamic> _metadata;

  bool _isInitialized = false;

  /// Initialize Hive and open all boxes
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(CourseAdapter());
      if (!Hive.isAdapterRegistered(1))
        Hive.registerAdapter(ComponentAdapter());
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(RecordsAdapter());
      if (!Hive.isAdapterRegistered(3))
        Hive.registerAdapter(GradingSystemAdapter());
      if (!Hive.isAdapterRegistered(4))
        Hive.registerAdapter(GradeRangeAdapter());

      // Open boxes
      _courses = await Hive.openBox<Course>(_coursesBox);
      _components = await Hive.openBox<Component>(_componentsBox);
      _records = await Hive.openBox<Records>(_recordsBox);
      _offlineQueue = await Hive.openBox<Map<dynamic, dynamic>>(
        _offlineQueueBox,
      );
      _metadata = await Hive.openBox(_metadataBox);

      _isInitialized = true;
      print('✅ Local storage initialized successfully');
      print(
        '📊 Courses: ${_courses.length}, Components: ${_components.length}, Records: ${_records.length}',
      );
    } catch (e) {
      print('❌ Error initializing local storage: $e');
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'LocalStorageService not initialized. Call initialize() first.',
      );
    }
  }

  // ==================== COURSES ====================

  /// Save a course to local storage
  /// IMPORTANT: Always rebuilds the course with latest components from storage
  Future<void> saveCourse(Course course) async {
    print('🗄️ [LocalStorage.saveCourse] START - ${course.courseId}');
    final startTime = DateTime.now();

    _ensureInitialized();

    // Get the latest components from storage to ensure consistency
    print('📦 [LocalStorage.saveCourse] Fetching latest components...');
    final latestComponents = getComponentsByCourseId(course.courseId);
    print(
      '📦 [LocalStorage.saveCourse] Found ${latestComponents.length} components',
    );

    // Rebuild course with latest components to avoid stale data
    final courseToSave = Course(
      courseId: course.courseId,
      userId: course.userId,
      courseName: course.courseName,
      courseCode: course.courseCode,
      units: course.units,
      instructor: course.instructor,
      academicYear: course.academicYear,
      semester: course.semester,
      gradingSystem: course.gradingSystem,
      components: latestComponents,
      grade: course.grade,
      numericalGrade: course.numericalGrade,
      wasRounded: course.wasRounded,
    );

    print('💾 [LocalStorage.saveCourse] Writing to Hive box...');
    final putStart = DateTime.now();
    await _courses.put(course.courseId, courseToSave);
    final putEnd = DateTime.now();
    print(
      '✅ [LocalStorage.saveCourse] Hive put() took ${putEnd.difference(putStart).inMilliseconds}ms',
    );

    await _setLastSyncTime('course_${course.courseId}');

    final endTime = DateTime.now();
    final totalDuration = endTime.difference(startTime).inMilliseconds;
    print('✨ [LocalStorage.saveCourse] COMPLETE in ${totalDuration}ms');
    print(
      '💾 Saved course locally with ${latestComponents.length} components: ${course.courseId}',
    );
  }

  /// Get a course by ID
  /// Always returns course with latest components from storage
  Course? getCourse(String courseId) {
    _ensureInitialized();
    final course = _courses.get(courseId);
    if (course == null) return null;

    // Rebuild with latest components to ensure consistency
    final latestComponents = getComponentsByCourseId(courseId);

    return Course(
      courseId: course.courseId,
      userId: course.userId,
      courseName: course.courseName,
      courseCode: course.courseCode,
      units: course.units,
      instructor: course.instructor,
      academicYear: course.academicYear,
      semester: course.semester,
      gradingSystem: course.gradingSystem,
      components: latestComponents,
      grade: course.grade,
      numericalGrade: course.numericalGrade,
      wasRounded: course.wasRounded,
    );
  }

  /// Get all courses for a user
  /// Always returns courses with latest components from storage
  List<Course> getCoursesByUserId(String userId) {
    _ensureInitialized();
    return _courses.values
        .where((course) => course.userId == userId)
        .map((course) => getCourse(course.courseId)!)
        .toList();
  }

  /// Get all courses
  /// Always returns courses with latest components from storage
  List<Course> getAllCourses() {
    _ensureInitialized();
    return _courses.values
        .map((course) => getCourse(course.courseId)!)
        .where((course) => course != null)
        .toList();
  }

  /// Delete a course
  Future<void> deleteCourse(String courseId) async {
    _ensureInitialized();
    await _courses.delete(courseId);
    print('🗑️ Deleted course locally: $courseId');
  }

  /// Update course grades
  Future<void> updateCourseGrades({
    required String courseId,
    required double grade,
    required double? numericalGrade,
    required bool wasRounded,
  }) async {
    _ensureInitialized();
    final course = _courses.get(courseId);
    if (course == null) return;

    final updatedCourse = Course(
      courseId: course.courseId,
      userId: course.userId,
      courseName: course.courseName,
      courseCode: course.courseCode,
      units: course.units,
      instructor: course.instructor,
      academicYear: course.academicYear,
      semester: course.semester,
      gradingSystem: course.gradingSystem,
      components: course.components,
      grade: grade,
      numericalGrade: numericalGrade,
      wasRounded: wasRounded,
    );

    await _courses.put(courseId, updatedCourse);
    await _setLastSyncTime('course_grades_$courseId');
    print('💾 Updated course grades locally: $courseId');
  }

  // ==================== COMPONENTS ====================

  /// Save a component to local storage
  Future<void> saveComponent(Component component) async {
    _ensureInitialized();
    await _components.put(component.componentId, component);
    await _setLastSyncTime('component_${component.componentId}');
    print('💾 Saved component locally: ${component.componentId}');
  }

  /// Get a component by ID with records embedded
  Component? getComponent(String componentId) {
    _ensureInitialized();
    final component = _components.get(componentId);
    if (component == null) return null;

    // Embed records from storage for offline access
    final records = getRecordsByComponentId(componentId);

    return Component(
      componentId: component.componentId,
      componentName: component.componentName,
      weight: component.weight,
      courseId: component.courseId,
      records: records,
    );
  }

  /// Get all components for a course with records embedded
  List<Component> getComponentsByCourseId(String courseId) {
    _ensureInitialized();
    return _components.values
        .where((component) => component.courseId == courseId)
        .map((component) => getComponent(component.componentId)!)
        .where((component) => component != null)
        .toList();
  }

  /// Delete a component
  Future<void> deleteComponent(String componentId) async {
    _ensureInitialized();
    await _components.delete(componentId);
    print('🗑️ Deleted component locally: $componentId');
  }

  // ==================== RECORDS ====================

  /// Save a record to local storage
  Future<void> saveRecord(Records record) async {
    _ensureInitialized();
    await _records.put(record.recordId, record);
    print('💾 Saved record locally: ${record.recordId}');
  }

  /// Save multiple records in batch
  Future<void> saveRecordsBatch(List<Records> records) async {
    _ensureInitialized();
    final Map<String, Records> recordsMap = {
      for (var record in records) record.recordId: record,
    };
    await _records.putAll(recordsMap);
    print('💾 Saved ${records.length} records locally');
  }

  /// Get all records for a component
  List<Records> getRecordsByComponentId(String componentId) {
    _ensureInitialized();
    return _records.values
        .where((record) => record.componentId == componentId)
        .toList();
  }

  /// Delete all records for a component
  Future<void> deleteRecordsByComponentId(String componentId) async {
    _ensureInitialized();
    final recordsToDelete = getRecordsByComponentId(componentId);
    for (final record in recordsToDelete) {
      await _records.delete(record.recordId);
    }
    print(
      '🗑️ Deleted ${recordsToDelete.length} records for component: $componentId',
    );
  }

  // ==================== OFFLINE QUEUE ====================

  /// Add operation to offline queue
  Future<void> queueOperation(Map<String, dynamic> operation) async {
    _ensureInitialized();
    final id = operation['id'] as String;
    await _offlineQueue.put(id, operation);
    print('➕ Queued operation: $id');
  }

  /// Get all queued operations
  List<Map<String, dynamic>> getQueuedOperations() {
    _ensureInitialized();
    return _offlineQueue.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Remove operation from queue
  Future<void> removeQueuedOperation(String id) async {
    _ensureInitialized();
    await _offlineQueue.delete(id);
    print('✅ Removed queued operation: $id');
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    _ensureInitialized();
    await _offlineQueue.clear();
    print('🗑️ Cleared offline queue');
  }

  /// Get number of pending operations
  int get queuedOperationsCount {
    _ensureInitialized();
    return _offlineQueue.length;
  }

  // ==================== METADATA ====================

  /// Set last sync timestamp for an entity
  Future<void> _setLastSyncTime(String key) async {
    await _metadata.put('last_sync_$key', DateTime.now().toIso8601String());
  }

  /// Get last sync timestamp for an entity
  DateTime? getLastSyncTime(String key) {
    final timeString = _metadata.get('last_sync_$key');
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }

  /// Set last successful Firebase sync
  Future<void> setLastFirebaseSync() async {
    await _metadata.put('last_firebase_sync', DateTime.now().toIso8601String());
  }

  /// Get last successful Firebase sync
  DateTime? getLastFirebaseSync() {
    final timeString = _metadata.get('last_firebase_sync');
    if (timeString == null) return null;
    return DateTime.tryParse(timeString);
  }

  // ==================== BULK OPERATIONS ====================

  /// Save full course with components and records
  Future<void> saveCourseComplete({
    required Course course,
    required List<Component> components,
    required Map<String, List<Records>> recordsByComponent,
  }) async {
    _ensureInitialized();

    // Save course
    await saveCourse(course);

    // Save components
    for (final component in components) {
      await saveComponent(component);

      // Save records for this component
      final records = recordsByComponent[component.componentId];
      if (records != null && records.isNotEmpty) {
        await saveRecordsBatch(records);
      }
    }

    print('💾 Saved complete course data: ${course.courseId}');
  }

  /// Delete full course with all components and records
  Future<void> deleteCourseComplete(String courseId) async {
    _ensureInitialized();

    // Get all components for this course
    final components = getComponentsByCourseId(courseId);

    // Delete all records for each component
    for (final component in components) {
      await deleteRecordsByComponentId(component.componentId);
      await deleteComponent(component.componentId);
    }

    // Delete the course
    await deleteCourse(courseId);

    print('🗑️ Deleted complete course data: $courseId');
  }

  // ==================== UTILITY ====================

  /// Clear all local data (use with caution!)
  Future<void> clearAllData() async {
    _ensureInitialized();
    await _courses.clear();
    await _components.clear();
    await _records.clear();
    await _offlineQueue.clear();
    await _metadata.clear();
    print('🗑️ Cleared all local data');
  }

  /// Get storage statistics
  Map<String, int> getStorageStats() {
    _ensureInitialized();
    return {
      'courses': _courses.length,
      'components': _components.length,
      'records': _records.length,
      'queuedOperations': _offlineQueue.length,
    };
  }

  /// Close all boxes (call on app termination)
  Future<void> close() async {
    if (!_isInitialized) return;
    await Hive.close();
    _isInitialized = false;
    print('📦 Local storage closed');
  }
}
