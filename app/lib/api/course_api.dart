import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';
import 'package:gradecalculator/services/connectivity_service.dart';
import 'package:gradecalculator/services/offline_queue_service.dart';
import 'package:gradecalculator/services/local_storage_service.dart';
import 'package:uuid/uuid.dart';

class CourseApi {
  static const Duration _firestoreTimeout = Duration(seconds: 10);
  final FirebaseFirestore db = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService = ConnectivityService();
  final OfflineQueueService _offlineQueue = OfflineQueueService();
  final LocalStorageService _localStorage = LocalStorageService();
  final Uuid _uuid = const Uuid();

  Future<String?> addCourse(Course course) async {
    try {
      print('🚀 [addCourse] START - ${DateTime.now()}');

      // Generate conflict-free ID using UUID
      final courseId = 'course_${_uuid.v4()}';
      print('🆔 [addCourse] Generated courseId: $courseId');

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

      print('💾 [addCourse] Saving to Hive...');
      final saveStart = DateTime.now();

      // ALWAYS save to local storage first (offline-first)
      await _localStorage.saveCourse(courseWithId);

      final saveEnd = DateTime.now();
      final saveDuration = saveEnd.difference(saveStart).inMilliseconds;
      print('✅ [addCourse] Hive save completed in ${saveDuration}ms');

      print('🔄 [addCourse] Returning to caller (non-blocking)');

      // Fire-and-forget Firebase sync (non-blocking)
      if (_connectivityService.isOnline) {
        print('📡 [addCourse] Starting background Firebase sync...');
        // Don't await - sync in background
        db
            .collection('courses')
            .doc(courseId)
            .set(courseWithId.toMap())
            .then((_) {
              _localStorage.setLastFirebaseSync();
              print('✅ [addCourse] Firebase sync completed: $courseId');
            })
            .catchError((e) {
              print('⚠️ [addCourse] Firebase sync failed, queueing: $e');
              _offlineQueue.queueOperation(
                OfflineOperation(
                  id: courseId,
                  type: 'course',
                  data: courseWithId.toMap(),
                  timestamp: DateTime.now(),
                ),
              );
            });
      } else {
        // Offline: queue for sync when online
        print('📴 [addCourse] Offline - queueing for later sync');
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: courseId,
            type: 'course',
            data: courseWithId.toMap(),
            timestamp: DateTime.now(),
          ),
        );
      }

      print('✨ [addCourse] RETURN SUCCESS - ${DateTime.now()}');
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
      // ALWAYS update local storage first (offline-first)
      await _localStorage.updateCourseGrades(
        courseId: courseId,
        grade: grade,
        numericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );
      print('💾 Course grades updated locally: $courseId');

      final updates = {
        'grade': grade,
        'numericalGrade': numericalGrade,
        'wasRounded': wasRounded,
      };

      // Fire-and-forget Firebase sync (non-blocking)
      if (_connectivityService.isOnline) {
        // Don't await - sync in background
        db
            .collection('courses')
            .doc(courseId)
            .update(updates)
            .timeout(_firestoreTimeout)
            .then((_) {
              _localStorage.setLastFirebaseSync();
              print('✅ Course grades synced to Firebase: $courseId');
            })
            .catchError((e) {
              print('⚠️ Firebase sync failed, queueing: $e');
              _offlineQueue.queueOperation(
                OfflineOperation(
                  id:
                      '${courseId}_grades_${DateTime.now().millisecondsSinceEpoch}',
                  type: 'updateCourse',
                  data: {'courseId': courseId, 'updates': updates},
                  timestamp: DateTime.now(),
                ),
              );
            });
      } else {
        // Offline: queue for sync when online
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: '${courseId}_grades_${DateTime.now().millisecondsSinceEpoch}',
            type: 'updateCourse',
            data: {'courseId': courseId, 'updates': updates},
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Course grades queued for sync when online: $courseId');
      }

      return null; // Success
    } catch (e) {
      return "Failed to update course grades: $e";
    }
  }

  Future<List<Component>> loadCourseComponents(String courseId) async {
    try {
      // OFFLINE-FIRST: Always load from local storage first
      final localComponents = _localStorage.getComponentsByCourseId(courseId);

      if (!_connectivityService.isOnline) {
        // Offline: return local data immediately
        print(
          '📦 Loaded ${localComponents.length} components from local storage (offline)',
        );
        return localComponents;
      }

      // Online: try to sync from Firebase, fallback to local
      try {
        final snapshot = await db
            .collection('components')
            .where('courseId', isEqualTo: courseId)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(_firestoreTimeout);

        final firebaseComponents =
            snapshot.docs.map((doc) => Component.fromMap(doc.data())).toList();

        // Update local storage with fresh data
        for (final component in firebaseComponents) {
          await _localStorage.saveComponent(component);
        }

        await _localStorage.setLastFirebaseSync();
        print(
          '📦 Loaded ${firebaseComponents.length} components from Firebase and cached locally',
        );
        return firebaseComponents;
      } catch (e) {
        print('⚠️ Firebase load failed, using local data: $e');
        print(
          '📦 Loaded ${localComponents.length} components from local storage (fallback)',
        );
        return localComponents;
      }
    } catch (e) {
      print("❌ Error loading components: $e");
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

      // Create component with records for local usage
      final component = Component(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: courseId,
        records: records,
      );

      // ALWAYS save to local storage first (offline-first)
      await _localStorage.saveComponent(component);
      await _localStorage.saveRecordsBatch(records);
      print('💾 Component and records saved locally: $componentId');

      // Fire-and-forget Firebase sync (non-blocking)
      if (_connectivityService.isOnline) {
        // Don't await - sync in background
        Future(() async {
          await db
              .collection('components')
              .doc(componentId)
              .set(component.toMap());

          final batch = db.batch();
          for (final record in records) {
            final recordDocRef = db.collection('records').doc(record.recordId);
            batch.set(recordDocRef, record.toMap());
          }
          await batch.commit();
          await _localStorage.setLastFirebaseSync();
          print('✅ Component synced to Firebase: $componentId');
        }).catchError((e) {
          print('⚠️ Firebase sync failed, queueing: $e');
          _offlineQueue.queueOperation(
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
        });
      } else {
        // Offline: queue for sync when online
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
        print('📴 Component queued for sync when online: $componentId');
      }

      return component;
    } catch (e) {
      print("Error creating component: $e");
      return null;
    }
  }

  Future<Component?> updateComponentWithRecords({
    required String componentId,
    required String componentName,
    required double weight,
    required String courseId,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    try {
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

      final updatedComponent = Component(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: courseId,
        records: records,
      );

      // ALWAYS save to local storage first (offline-first)
      await _localStorage.deleteRecordsByComponentId(componentId);
      await _localStorage.saveComponent(updatedComponent);
      await _localStorage.saveRecordsBatch(records);
      print('💾 Component and records updated locally: $componentId');

      // Fire-and-forget Firebase sync (non-blocking)
      if (_connectivityService.isOnline) {
        // Don't await - sync in background
        Future(() async {
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
          await _localStorage.setLastFirebaseSync();
          print('✅ Component synced to Firebase: $componentId');
        }).catchError((e) {
          print('⚠️ Firebase sync failed, queueing: $e');
          _offlineQueue.queueOperation(
            OfflineOperation(
              id:
                  '${componentId}_update_${DateTime.now().millisecondsSinceEpoch}',
              type: 'updateComponent',
              data: {
                'componentId': componentId,
                'component': updatedComponent.toMap(),
                'records': records.map((r) => r.toMap()).toList(),
              },
              timestamp: DateTime.now(),
            ),
          );
        });
      } else {
        // Offline: queue for sync when online
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
        print('📴 Component queued for sync when online: $componentId');
      }

      print('🎯 Returning updated component from updateComponentWithRecords');
      return updatedComponent; // Success
    } catch (e) {
      print("Error updating component: $e");
      return null;
    }
  }

  Future<double> calculateComponentScore(Component component) async {
    try {
      // OFFLINE-FIRST: Try to use component's embedded records first
      List<Records> records = component.records ?? [];

      // If no embedded records, load from local storage
      if (records.isEmpty) {
        records = _localStorage.getRecordsByComponentId(component.componentId);
      }

      // If still no records and we're online, try Firebase
      if (records.isEmpty && _connectivityService.isOnline) {
        try {
          final recordsSnapshot = await db
              .collection('records')
              .where('componentId', isEqualTo: component.componentId)
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(_firestoreTimeout);

          records =
              recordsSnapshot.docs
                  .map((doc) => Records.fromMap(doc.data()))
                  .toList();

          // Cache records locally
          if (records.isNotEmpty) {
            await _localStorage.saveRecordsBatch(records);
          }
        } catch (e) {
          print("⚠️ Firebase load failed for records: $e");
        }
      }

      // Calculate score from records
      if (records.isEmpty) return 0.0;

      double totalScore = 0.0;
      double totalPossible = 0.0;

      for (final record in records) {
        totalScore += record.score;
        totalPossible += record.total;
      }

      if (totalPossible <= 0) return 0.0;

      final componentPercentage = (totalScore / totalPossible) * 100;
      final weightedScore = componentPercentage * (component.weight / 100);

      return weightedScore;
    } catch (e) {
      print("❌ Error calculating component score: $e");
      return 0.0;
    }
  }

  Future<String?> deleteComponent(String componentId) async {
    try {
      // ALWAYS delete from local storage first (offline-first)
      await _localStorage.deleteRecordsByComponentId(componentId);
      await _localStorage.deleteComponent(componentId);
      print('💾 Component deleted from local storage: $componentId');

      if (_connectivityService.isOnline) {
        // Online: sync deletion to Firestore
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
          await _localStorage.setLastFirebaseSync();
          print('✅ Component deleted from Firebase: $componentId');
        } catch (e) {
          print('⚠️ Firebase deletion failed, will retry: $e');
          await _offlineQueue.queueOperation(
            OfflineOperation(
              id:
                  '${componentId}_delete_${DateTime.now().millisecondsSinceEpoch}',
              type: 'deleteComponent',
              data: {'componentId': componentId},
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        // Offline: queue deletion for sync when online
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: '${componentId}_delete_${DateTime.now().millisecondsSinceEpoch}',
            type: 'deleteComponent',
            data: {'componentId': componentId},
            timestamp: DateTime.now(),
          ),
        );
        print(
          '📴 Component deletion queued for sync when online: $componentId',
        );
      }

      return null;
    } catch (e) {
      return "Error deleting component: $e";
    }
  }

  Future<String?> deleteCourse(String courseId) async {
    try {
      // ALWAYS delete from local storage first (offline-first)
      await _localStorage.deleteCourseComplete(courseId);
      print('💾 Course and related data deleted from local storage: $courseId');

      if (_connectivityService.isOnline) {
        // Online: sync deletion to Firestore
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
          await _localStorage.setLastFirebaseSync();
          print('✅ Course deleted from Firebase: $courseId');
        } catch (e) {
          print('⚠️ Firebase deletion failed, will retry: $e');
          await _offlineQueue.queueOperation(
            OfflineOperation(
              id: '${courseId}_delete_${DateTime.now().millisecondsSinceEpoch}',
              type: 'deleteCourse',
              data: {'courseId': courseId},
              timestamp: DateTime.now(),
            ),
          );
        }
      } else {
        // Offline: queue deletion for sync when online
        await _offlineQueue.queueOperation(
          OfflineOperation(
            id: '${courseId}_delete_${DateTime.now().millisecondsSinceEpoch}',
            type: 'deleteCourse',
            data: {'courseId': courseId},
            timestamp: DateTime.now(),
          ),
        );
        print('📴 Course deletion queued for sync when online: $courseId');
      }

      return null;
    } catch (e) {
      return "Error deleting course: $e";
    }
  }
}
