import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';
import 'package:gradecalculator/services/connectivity_service.dart';
import 'package:gradecalculator/services/offline_queue_service.dart';
import 'package:uuid/uuid.dart';

class CourseApi {
  static const Duration _firestoreTimeout = Duration(seconds: 10);
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final Uuid _uuid = const Uuid();

  Future<String?> addCourse(Course course) async {
    try {
      // Generate conflict-free ID using UUID
      final courseId = 'course_${_uuid.v4()}';
      final courseWithId = Course(
        courseId: courseId,
        userId: course.userId,
        courseName: course.courseName,
        courseCode: course.courseCode,
        units: course.units,
        instructor: course.instructor,
        academicYear: course.academicYear,
        semester: course.semester,
        gradingSystem: course.gradingSystem,
        components: course.components,
        grade: course.grade,
        numericalGrade: course.numericalGrade,
      );

      if (_connectivityService.isOnline) {
        // Online: Save directly to Firestore
        await db.collection('courses').doc(courseId).set(courseWithId.toMap());
        print('✅ Course saved online: $courseId');
      } else {
        // Offline: Queue the operation
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: courseId,
            type: 'course',
            data: courseWithId.toMap(),
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Course queued for offline sync: $courseId');
      }
      
      return null; // Success
    } catch (e) {
      return "Failed to add course: $e";
    }
  }

  Future<String?> updateCourseGrades({
    required String courseId,
    required double grade,
    required double? numericalGrade,
    required bool wasRounded,
  }) async {
    try {
      final updates = {
        'grade': grade,
        'numericalGrade': numericalGrade,
        'wasRounded': wasRounded,
      };

      if (_connectivityService.isOnline) {
        await db
            .collection('courses')
            .doc(courseId)
            .update(updates)
            .timeout(_firestoreTimeout);
        print('✅ Course grades updated online: $courseId');
      } else {
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: '${courseId}_grades_${DateTime.now().millisecondsSinceEpoch}',
            type: 'updateCourse',
            data: {
              'courseId': courseId,
              'updates': updates,
            },
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Course grades queued for offline sync: $courseId');
      }
      
      return null; // Success
    } catch (e) {
      return "Failed to update course grades: $e";
    }
  }

  Future<List<Component>> loadCourseComponents(String courseId) async {
    try {
      final snapshot = await db
          .collection('components')
          .where('courseId', isEqualTo: courseId)
          .get()
          .timeout(_firestoreTimeout);

      return snapshot.docs.map((doc) => Component.fromMap(doc.data())).toList();
    } on TimeoutException {
      print("Loading components timed out - returning empty list");
      return [];
    } catch (e) {
      print("Error loading components (offline?): $e");
      return [];
    }
  }

  Future<Component?> createComponentWithRecords({
    required String courseId,
    required String componentName,
    required double weight,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    try {
      // Generate conflict-free ID using UUID
      final componentId = 'component_${_uuid.v4()}';

      final component = Component(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: courseId,
      );

      final records =
          recordsData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final name = (data['name'] as String).trim();

            return Records(
              recordId: 'record_${_uuid.v4()}',
              componentId: componentId,
              name: name.isEmpty ? (index + 1).toString() : name,
              score: data['score'] as double,
              total: data['total'] as double,
            );
          }).toList();

      if (_connectivityService.isOnline) {
        // Online: Save directly to Firestore
        await db.collection('components').doc(componentId).set(component.toMap());

        final batch = db.batch();
        for (final record in records) {
          final recordDocRef = db.collection('records').doc(record.recordId);
          batch.set(recordDocRef, record.toMap());
        }
        await batch.commit();
        print('✅ Component saved online: $componentId');
      } else {
        // Offline: Queue the operation
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: componentId,
            type: 'component',
            data: {
              'component': component.toMap(),
              'records': records.map((r) => r.toMap()).toList(),
            },
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Component queued for offline sync: $componentId');
      }

      return component;
    } catch (e) {
      print("Error creating component: $e");
      return null;
    }
  }

  Future<String?> updateComponentWithRecords({
    required String componentId,
    required String componentName,
    required double weight,
    required String courseId,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    try {
      final updatedComponent = Component(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: courseId,
      );

      final records =
          recordsData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final name = (data['name'] as String).trim();

            return Records(
              recordId: 'record_${_uuid.v4()}',
              componentId: componentId,
              name: name.isEmpty ? (index + 1).toString() : name,
              score: data['score'] as double,
              total: data['total'] as double,
            );
          }).toList();

      if (_connectivityService.isOnline) {
        // Online: Update directly in Firestore
        await db
            .collection('components')
            .doc(componentId)
            .update(updatedComponent.toMap());

        final existingRecordsSnapshot =
            await db
                .collection('records')
                .where('componentId', isEqualTo: componentId)
                .get();

        final batch = db.batch();

        for (final doc in existingRecordsSnapshot.docs) {
          batch.delete(doc.reference);
        }

        for (final record in records) {
          final recordDocRef = db.collection('records').doc(record.recordId);
          batch.set(recordDocRef, record.toMap());
        }

        await batch.commit();
        print('✅ Component updated online: $componentId');
      } else {
        // Offline: Queue the operation
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: '${componentId}_update_${DateTime.now().millisecondsSinceEpoch}',
            type: 'updateComponent',
            data: {
              'componentId': componentId,
              'component': updatedComponent.toMap(),
              'records': records.map((r) => r.toMap()).toList(),
            },
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Component update queued for offline sync: $componentId');
      }

      return null; // Success
    } catch (e) {
      return "Error updating component: $e";
    }
  }

  Future<double> calculateComponentScore(Component component) async {
    try {
      final recordsSnapshot = await db
          .collection('records')
          .where('componentId', isEqualTo: component.componentId)
          .get()
          .timeout(_firestoreTimeout);

      double totalScore = 0.0;
      double totalPossible = 0.0;

      for (final doc in recordsSnapshot.docs) {
        final record = Records.fromMap(doc.data());
        totalScore += record.score;
        totalPossible += record.total;
      }

      if (totalPossible <= 0) {
        return 0.0;
      }

      final componentPercentage = (totalScore / totalPossible) * 100;
      final weightedScore = componentPercentage * (component.weight / 100);

      return weightedScore;
    } catch (e) {
      print("Error calculating component score: $e");
      return 0.0;
    }
  }

  Future<String?> deleteComponent(String componentId) async {
    try {
      final batch = db.batch();

      
      final recordsQuery =
          await db
              .collection('records')
              .where('componentId', isEqualTo: componentId)
              .get();

      for (final doc in recordsQuery.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(db.collection('components').doc(componentId));

      await batch.commit();
      return null; 
    } catch (e) {
      return "Error deleting component: $e";
    }
  }

  Future<String?> deleteCourse(String courseId) async {
    try {
      final batch = db.batch();

    
      final componentsSnapshot =
          await db
              .collection('components')
              .where('courseId', isEqualTo: courseId)
              .get();

      for (final componentDoc in componentsSnapshot.docs) {
        final componentId = componentDoc.id;

      
        final recordsSnapshot =
            await db
                .collection('records')
                .where('componentId', isEqualTo: componentId)
                .get();

        for (final recordDoc in recordsSnapshot.docs) {
          batch.delete(recordDoc.reference);
        }

     
        batch.delete(componentDoc.reference);
      }


      batch.delete(db.collection('courses').doc(courseId));

      await batch.commit();
      return null;
    } catch (e) {
      return "Error deleting course: $e";
    }
  }
}
