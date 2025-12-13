import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gradecalculator/api/course_api.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/grade_range.dart';
import 'package:gradecalculator/models/records.dart';

class CourseProvider with ChangeNotifier {
  final CourseApi _courseApi = CourseApi();

  Course? _selectedCourse;

  Course? get selectedCourse => _selectedCourse;

  void selectCourse(Course course) {
    _selectedCourse = course;
    notifyListeners();
    _loadComponentsInBackground(course);
  }

  Future<void> _loadComponentsInBackground(Course course) async {
    try {
      final components = await _courseApi.loadCourseComponents(course.courseId);
      if (_selectedCourse?.courseId == course.courseId) {
        _selectedCourse = _createUpdatedCourse(course, components);
        notifyListeners();
      }
    } catch (e) {
      if (_selectedCourse?.courseId == course.courseId) {
        _selectedCourse = _createUpdatedCourse(course, []);
        notifyListeners();
      }
    }
  }

  Course _createUpdatedCourse(
    Course originalCourse,
    List<Component> components, {
    double? newGrade,
    double? newNumericalGrade,
    bool? wasRounded,
  }) {
    return Course(
      courseId: originalCourse.courseId,
      userId: originalCourse.userId,
      courseName: originalCourse.courseName,
      courseCode: originalCourse.courseCode,
      units: originalCourse.units,
      instructor: originalCourse.instructor,
      academicYear: originalCourse.academicYear,
      semester: originalCourse.semester,
      gradingSystem: originalCourse.gradingSystem,
      components: components,
      grade: newGrade ?? originalCourse.grade,
      numericalGrade: newNumericalGrade ?? originalCourse.numericalGrade,
      wasRounded: wasRounded ?? originalCourse.wasRounded,
    );
  }

  void clearSelectedCourse() {
    _selectedCourse = null;
    notifyListeners();
  }

  Future<String?> addCourse(Course course) async {
    final result = await _courseApi.addCourse(course);
    notifyListeners();
    return result;
  }

  Future<double> calculateCourseGrade({List<Component?>? components}) async {
    final courseComponents = components ?? _selectedCourse?.components ?? [];
    double totalGrade = 0.0;

    for (final component in courseComponents) {
      if (component == null) continue;
      final componentScore = await _calculateComponentScore(component);
      totalGrade += componentScore;
    }

    return double.parse(totalGrade.toStringAsFixed(2));
  }

  Future<double> _calculateComponentScore(Component component) async {
    return await _courseApi.calculateComponentScore(component);
  }

  (double?, bool) calculateNumericalGradeWithRounding(
    double percentage,
    List<GradeRange> gradeRanges,
  ) {
    final exactMatch = _findGradeInRanges(percentage, gradeRanges);
    if (exactMatch != null) return (exactMatch, false);

    final rounded =
        (percentage % 1 >= 0.5) ? percentage.ceil() : percentage.floor();
    final roundedMatch = _findGradeInRanges(rounded.toDouble(), gradeRanges);
    if (roundedMatch != null) return (roundedMatch, true);

    return (null, false);
  }

  double? calculateNumericalGrade(
    double percentage,
    List<GradeRange> gradeRanges,
  ) {
    final (grade, _) = calculateNumericalGradeWithRounding(
      percentage,
      gradeRanges,
    );
    return grade;
  }

  double? _findGradeInRanges(double value, List<GradeRange> gradeRanges) {
    for (final range in gradeRanges) {
      if (value >= range.min && value <= range.max) {
        return range.grade;
      }
    }
    return null;
  }

  Future<void> updateCourseGrade({List<Component?>? components}) async {
    if (_selectedCourse == null) return;

    try {
      final newPercentageGrade = await calculateCourseGrade(
        components: components,
      );
      final (numericalGrade, wasRounded) = calculateNumericalGradeWithRounding(
        newPercentageGrade,
        _selectedCourse!.gradingSystem.gradeRanges,
      );

      final result = await _courseApi.updateCourseGrades(
        courseId: _selectedCourse!.courseId,
        grade: newPercentageGrade,
        numericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        components?.cast<Component>() ??
            _selectedCourse!.components.cast<Component>(),
        newGrade: newPercentageGrade,
        newNumericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      notifyListeners();
    } catch (e) {
      print("Error updating course grade: $e");
    }
  }

  Future<void> addComponentAndUpdateGrade(Component component) async {
    if (_selectedCourse == null) return;

    try {
      final allComponents = await _courseApi.loadCourseComponents(
        _selectedCourse!.courseId,
      );
      await updateCourseGrade(components: allComponents.cast<Component?>());
    } catch (e) {
      print("Error in addComponentAndUpdateGrade: $e");
    }
  }

  Future<void> removeComponentAndUpdateGrade(String componentId) async {
    if (_selectedCourse == null) return;

    try {
      final updatedComponents =
          _selectedCourse!.components
              .where((comp) => comp?.componentId != componentId)
              .toList();

      final newPercentageGrade = await calculateCourseGrade(
        components: updatedComponents,
      );
      final (numericalGrade, wasRounded) = calculateNumericalGradeWithRounding(
        newPercentageGrade,
        _selectedCourse!.gradingSystem.gradeRanges,
      );

      final result = await _courseApi.updateCourseGrades(
        courseId: _selectedCourse!.courseId,
        grade: newPercentageGrade,
        numericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        updatedComponents.cast<Component>(),
        newGrade: newPercentageGrade,
        newNumericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      notifyListeners();
    } catch (e) {
      print("Error: $e");
    }
  }

  Future<void> createComponentWithRecords({
    required String componentName,
    required double weight,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    if (_selectedCourse == null) return;

    try {
      final createdComponent = await _courseApi.createComponentWithRecords(
        courseId: _selectedCourse!.courseId,
        componentName: componentName,
        weight: weight,
        recordsData: recordsData,
      );

      if (createdComponent == null) {
        print("Error creating component");
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));
      await addComponentAndUpdateGrade(createdComponent);
    } catch (e) {
      print("Error creating component: $e");
      rethrow;
    }
  }

  Future<void> updateComponentWithRecords({
    required String componentId,
    required String componentName,
    required double weight,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    if (_selectedCourse == null) return;

    try {
      final result = await _courseApi.updateComponentWithRecords(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: _selectedCourse!.courseId,
        recordsData: recordsData,
      );

      if (result != null) {
        print("Error updating component: $result");
        return;
      }

      await updateCourseGrade();
    } catch (e) {
      print("Error updating component: $e");
      rethrow;
    }
  }

  Future<List<Component>> loadCourseComponents(String courseId) async {
    return await _courseApi.loadCourseComponents(courseId);
  }

  void clearSelectedCourseOnNavigation() {
    _selectedCourse = null;
    notifyListeners();
  }

  Future<String?> deleteComponent(String componentId) async {
    final result = await _courseApi.deleteComponent(componentId);
    if (result == null) {
      await removeComponentAndUpdateGrade(componentId);
    }
    return result;
  }

  Future<String?> deleteCourse(String courseId) async {
    return await _courseApi.deleteCourse(courseId);
  }
}
