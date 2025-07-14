import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/records.dart';

class CourseApi {
  static const Duration _firestoreTimeout = Duration(seconds: 10);
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Future<String?> addCourse(Course course) async {
    try {
      final docRef = db.collection('courses').doc();
      final courseWithId = Course(
        courseId: docRef.id,
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
      await docRef.set(courseWithId.toMap());
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
      await db
          .collection('courses')
          .doc(courseId)
          .update({
            'grade': grade,
            'numericalGrade': numericalGrade,
            'wasRounded': wasRounded,
          })
          .timeout(_firestoreTimeout);
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
      final componentDocRef = db.collection('components').doc();
      final componentId = componentDocRef.id;

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
              recordId:
                  DateTime.now().millisecondsSinceEpoch.toString() + '_$index',
              componentId: componentId,
              name: name.isEmpty ? (index + 1).toString() : name,
              score: data['score'] as double,
              total: data['total'] as double,
            );
          }).toList();

      await componentDocRef.set(component.toMap());

      final batch = db.batch();
      for (final record in records) {
        final recordDocRef = db.collection('records').doc(record.recordId);
        batch.set(recordDocRef, record.toMap());
      }
      await batch.commit();

      return component; // ✅ Return the created component
    } catch (e) {
      print("Error creating component: $e");
      return null; // ✅ Return null on error
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

      final records =
          recordsData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final name = (data['name'] as String).trim();

            return Records(
              recordId:
                  DateTime.now().millisecondsSinceEpoch.toString() + '_$index',
              componentId: componentId,
              name: name.isEmpty ? (index + 1).toString() : name,
              score: data['score'] as double,
              total: data['total'] as double,
            );
          }).toList();

      for (final record in records) {
        final recordDocRef = db.collection('records').doc(record.recordId);
        batch.set(recordDocRef, record.toMap());
      }

      await batch.commit();

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
