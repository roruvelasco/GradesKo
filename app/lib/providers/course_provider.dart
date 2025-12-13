import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gradecalculator/api/course_api.dart';
import 'package:gradecalculator/models/course.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/grade_range.dart';
import 'package:gradecalculator/services/local_storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CourseProvider with ChangeNotifier {
  final CourseApi _courseApi = CourseApi();
  final LocalStorageService _localStorage = LocalStorageService();

  Course? _selectedCourse;
  final _coursesStreamController = StreamController<List<Course>>.broadcast();
  String? _currentUserId;
  StreamSubscription? _firebaseSubscription;

  Course? get selectedCourse => _selectedCourse;
  Stream<List<Course>> get coursesStream => _coursesStreamController.stream;

  /// Get courses for a user from local storage (synchronous)
  List<Course> getCoursesForUser(String userId) {
    return _localStorage
        .getAllCourses()
        .where((c) => c.userId == userId)
        .toList();
  }

  void selectCourse(Course course) {
    // OFFLINE-FIRST: Always load from local storage first
    final localCourse = _localStorage.getCourse(course.courseId);
    _selectedCourse = localCourse ?? course;
    notifyListeners();

    // Load components in background
    if (_selectedCourse!.components.isEmpty) {
      _loadComponentsInBackground(_selectedCourse!);
    }
  }

  Future<void> _loadComponentsInBackground(Course course) async {
    try {
      final components = await _courseApi.loadCourseComponents(course.courseId);
      if (_selectedCourse?.courseId == course.courseId) {
        _selectedCourse = _createUpdatedCourse(course, components);
        if (_selectedCourse != null) {
          // Save to local storage for persistence
          await _localStorage.saveCourse(_selectedCourse!);
        }
        notifyListeners();
      }
    } catch (e) {
      if (_selectedCourse?.courseId == course.courseId) {
        _selectedCourse = _createUpdatedCourse(course, []);
        if (_selectedCourse != null) {
          await _localStorage.saveCourse(_selectedCourse!);
        }
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

  /// Initialize courses stream for a user (offline-first)
  void initCoursesStream(String userId) {
    print('🔄 [initCoursesStream] START for userId: $userId');

    // Always emit initial local data first (for immediate UI update)
    print('📤 [initCoursesStream] Emitting initial local courses...');
    final initialCourses =
        _localStorage.getAllCourses().where((c) => c.userId == userId).toList();
    print(
      '✅ [initCoursesStream] Initial emit: ${initialCourses.length} courses',
    );
    _coursesStreamController.add(initialCourses);

    // Prevent multiple subscriptions for the same user
    if (_currentUserId == userId && _firebaseSubscription != null) {
      print(
        '✅ [initCoursesStream] Already subscribed for this user, skipping Firebase setup',
      );
      return;
    }

    // Cancel existing subscription if switching users
    _firebaseSubscription?.cancel();
    _currentUserId = userId;

    print('📡 [initCoursesStream] Setting up Firebase listener...');

    // Listen to Firebase changes (background sync)
    _firebaseSubscription = FirebaseFirestore.instance
        .collection('courses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen(
          (snapshot) async {
            print(
              '📥 [initCoursesStream] Firebase snapshot received (${snapshot.docs.length} courses)',
            );

            // Sync Firebase data to local storage (background)
            for (final doc in snapshot.docs) {
              try {
                final firebaseCourse = Course.fromMap(doc.data());
                await _localStorage.saveCourse(firebaseCourse);
              } catch (e) {
                print(
                  '⚠️ [initCoursesStream] Error saving course to local: $e',
                );
              }
            }

            // Emit fresh list from local storage (source of truth)
            final courses =
                _localStorage
                    .getAllCourses()
                    .where((c) => c.userId == userId)
                    .toList();

            print(
              '✅ [initCoursesStream] Emitting ${courses.length} courses to stream',
            );
            _coursesStreamController.add(courses);
          },
          onError: (error) {
            print('⚠️ [initCoursesStream] Firebase error: $error');
            // If Firebase fails, still show local courses
            final localCourses =
                _localStorage
                    .getAllCourses()
                    .where((c) => c.userId == userId)
                    .toList();
            _coursesStreamController.add(localCourses);
          },
        );
  }

  Future<String?> addCourse(Course course) async {
    print('🎯 [CourseProvider.addCourse] START - ${DateTime.now()}');

    final apiStart = DateTime.now();
    final result = await _courseApi.addCourse(course);
    final apiEnd = DateTime.now();
    final apiDuration = apiEnd.difference(apiStart).inMilliseconds;

    print('⏱️ [CourseProvider.addCourse] API call took ${apiDuration}ms');

    // Emit updated courses list immediately after adding
    if (result == null && _currentUserId != null) {
      print(
        '📤 [CourseProvider.addCourse] Emitting updated courses to stream...',
      );
      final streamStart = DateTime.now();

      final courses =
          _localStorage
              .getAllCourses()
              .where((c) => c.userId == _currentUserId)
              .toList();
      _coursesStreamController.add(courses);

      final streamEnd = DateTime.now();
      final streamDuration = streamEnd.difference(streamStart).inMilliseconds;
      print(
        '✅ [CourseProvider.addCourse] Stream updated in ${streamDuration}ms (${courses.length} courses)',
      );
    }

    print('🔔 [CourseProvider.addCourse] Calling notifyListeners()...');
    notifyListeners();

    print('✨ [CourseProvider.addCourse] COMPLETE - ${DateTime.now()}');
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
    print('🧮 updateCourseGrade: Starting...');
    if (_selectedCourse == null) {
      print('❌ No selected course');
      return;
    }

    try {
      print('📊 Calculating course grade...');
      final newPercentageGrade = await calculateCourseGrade(
        components: components,
      );
      print('📊 Calculated percentage grade: $newPercentageGrade');

      final (numericalGrade, wasRounded) = calculateNumericalGradeWithRounding(
        newPercentageGrade,
        _selectedCourse!.gradingSystem.gradeRanges,
      );
      print('📊 Numerical grade: $numericalGrade, wasRounded: $wasRounded');

      print('💾 Updating course grades in Firestore...');
      await _courseApi.updateCourseGrades(
        courseId: _selectedCourse!.courseId,
        grade: newPercentageGrade,
        numericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      print('🔄 Updating local course state...');
      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        components?.cast<Component>() ??
            _selectedCourse!.components.cast<Component>(),
        newGrade: newPercentageGrade,
        newNumericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );

      if (_selectedCourse != null) {
        await _localStorage.saveCourse(_selectedCourse!);
      }

      print('🔔 Notifying listeners...');
      notifyListeners();
      print('✅ updateCourseGrade: Completed');
    } catch (e) {
      print("❌ Error updating course grade: $e");
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
      print(
        "⚠️ Error in addComponentAndUpdateGrade: $e. Will update with component only.",
      );
      // Even if loading or calculation fails, update UI with the new component
      final updatedComponents = [..._selectedCourse!.components, component];
      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        updatedComponents.cast<Component>(),
      );
      if (_selectedCourse != null) {
        await _localStorage.saveCourse(_selectedCourse!);
      }
      notifyListeners();
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

      await _courseApi.updateCourseGrades(
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

      if (_selectedCourse != null) {
        await _localStorage.saveCourse(_selectedCourse!);
      }

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
    print('🔄 CourseProvider: Starting component creation');
    if (_selectedCourse == null) {
      print('❌ No selected course');
      return;
    }

    try {
      print('📡 Calling API to create component...');
      final createdComponent = await _courseApi.createComponentWithRecords(
        courseId: _selectedCourse!.courseId,
        componentName: componentName,
        weight: weight,
        recordsData: recordsData,
      );

      if (createdComponent == null) {
        print("❌ Error creating component (returned null)");
        return;
      }
      print('✅ Component API call completed successfully');

      // Optimistic update
      print('🧮 Step 5: Starting grade calculation (Optimistic)...');

      // Update components list with new component
      print('📋 Updating components list...');
      final updatedComponents = [
        ..._selectedCourse!.components,
        createdComponent,
      ];
      print(
        '✅ Components list updated (${updatedComponents.length} components)',
      );

      // Calculate new grade manually with error handling
      print('🧮 Step 6: Calculating total grade...');
      double totalGrade = 0.0;
      try {
        for (int i = 0; i < updatedComponents.length; i++) {
          final comp = updatedComponents[i];
          if (comp == null) {
            print('  - Component $i: null, skipping');
            continue;
          }
          print(
            '  - Component $i: ${comp.componentName} (ID: ${comp.componentId})',
          );

          if (comp.componentId == createdComponent.componentId) {
            // Use local calculation for the NEW component
            print('    → Using local calculation for NEW component');
            final score = _calculateComponentScoreFromData(
              recordsData: recordsData,
              weight: weight,
            );
            print('    → Score: $score');
            totalGrade += score;
          } else {
            // Use API for other components
            print('    → Fetching score from API...');
            final score = await _calculateComponentScore(comp);
            print('    → Score: $score');
            totalGrade += score;
          }
        }
        print('📊 Total grade calculated: $totalGrade');
      } catch (e) {
        print('⚠️ Error calculating grade: $e. Will retry later.');
        // Even if grade calculation fails, still update UI with the new component
        _selectedCourse = _createUpdatedCourse(
          _selectedCourse!,
          updatedComponents.cast<Component>(),
        );
        if (_selectedCourse != null) {
          await _localStorage.saveCourse(_selectedCourse!);
        }
        print('🔔 Notifying listeners (partial update)...');
        notifyListeners();
        print('⚠️ Returning early due to grade calculation error');
        return;
      }

      print('🎯 Step 7: Converting grade to numerical...');
      final newPercentageGrade = double.parse(totalGrade.toStringAsFixed(2));
      final (numericalGrade, wasRounded) = calculateNumericalGradeWithRounding(
        newPercentageGrade,
        _selectedCourse!.gradingSystem.gradeRanges,
      );
      print(
        '📊 New grade: $newPercentageGrade% (numerical: $numericalGrade, wasRounded: $wasRounded)',
      );

      // Update course grades
      print('💾 Step 8: Updating course grades in Firestore...');
      try {
        await _courseApi.updateCourseGrades(
          courseId: _selectedCourse!.courseId,
          grade: newPercentageGrade,
          numericalGrade: numericalGrade,
          wasRounded: wasRounded,
        );
        print('✅ Course grades updated successfully');
      } catch (e) {
        print('⚠️ Error updating course grades: $e. Will retry later.');
      }

      // Update local state
      print('📝 Step 9: Updating local course state...');
      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        updatedComponents.cast<Component>(),
        newGrade: newPercentageGrade,
        newNumericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );
      if (_selectedCourse != null) {
        await _localStorage.saveCourse(_selectedCourse!);
      }
      print('✅ Local state updated and persisted');

      print('🔔 Step 10: Notifying listeners...');
      notifyListeners();
      print('✅ Listeners notified');
      print('🎉 Component creation complete!');
    } catch (e) {
      print("❌ Error creating component: $e");
      rethrow;
    }
  }

  // Calculate component score locally from records data
  double _calculateComponentScoreFromData({
    required List<Map<String, dynamic>> recordsData,
    required double weight,
  }) {
    double totalScore = 0.0;
    double totalPossible = 0.0;

    for (final data in recordsData) {
      totalScore += (data['score'] as double?) ?? 0.0;
      totalPossible += (data['total'] as double?) ?? 0.0;
    }

    if (totalPossible <= 0) return 0.0;

    final componentPercentage = (totalScore / totalPossible) * 100;
    final weightedScore = componentPercentage * (weight / 100);
    return weightedScore;
  }

  Future<void> updateComponentWithRecords({
    required String componentId,
    required String componentName,
    required double weight,
    required List<Map<String, dynamic>> recordsData,
  }) async {
    print('🔄 CourseProvider: Starting component update');
    if (_selectedCourse == null) {
      print('❌ No selected course');
      return;
    }

    try {
      print('📡 Calling API to update component...');
      final updatedComponent = await _courseApi.updateComponentWithRecords(
        componentId: componentId,
        componentName: componentName,
        weight: weight,
        courseId: _selectedCourse!.courseId,
        recordsData: recordsData,
      );

      if (updatedComponent == null) {
        print("❌ Error updating component (returned null)");
        return;
      }

      print('✅ Component API call completed successfully');

      // Calculate new grade optimistically using local data
      print('🧮 Step 5: Starting grade calculation...');
      print('✅ Updated component created');

      // Update components list with new component
      print('📋 Updating components list...');
      final updatedComponents =
          _selectedCourse!.components.map((comp) {
            if (comp?.componentId == componentId) {
              return updatedComponent;
            }
            return comp;
          }).toList();
      print(
        '✅ Components list updated (${updatedComponents.length} components)',
      );

      // Calculate new grade manually with error handling
      print('🧮 Step 6: Calculating total grade...');
      double totalGrade = 0.0;
      try {
        for (int i = 0; i < updatedComponents.length; i++) {
          final comp = updatedComponents[i];
          if (comp == null) {
            print('  - Component $i: null, skipping');
            continue;
          }
          print(
            '  - Component $i: ${comp.componentName} (ID: ${comp.componentId})',
          );
          if (comp.componentId == componentId) {
            // Use local calculation for updated component
            print('    → Using local calculation for updated component');
            final score = _calculateComponentScoreFromData(
              recordsData: recordsData,
              weight: weight,
            );
            print('    → Score: $score');
            totalGrade += score;
          } else {
            // Use API for other components
            print('    → Fetching score from API...');
            final score = await _calculateComponentScore(comp);
            print('    → Score: $score');
            totalGrade += score;
          }
        }
        print('📊 Total grade calculated: $totalGrade');
      } catch (e) {
        print('⚠️ Error calculating grade: $e. Will retry later.');
        // Even if grade calculation fails, still update UI with component changes
        _selectedCourse = _createUpdatedCourse(
          _selectedCourse!,
          updatedComponents.cast<Component>(),
        );
        if (_selectedCourse != null) {
          await _localStorage.saveCourse(_selectedCourse!);
        }
        print('🔔 Notifying listeners (partial update)...');
        notifyListeners();
        print('⚠️ Returning early due to grade calculation error');
        return;
      }

      print('🎯 Step 7: Converting grade to numerical...');
      final newPercentageGrade = double.parse(totalGrade.toStringAsFixed(2));
      final (numericalGrade, wasRounded) = calculateNumericalGradeWithRounding(
        newPercentageGrade,
        _selectedCourse!.gradingSystem.gradeRanges,
      );
      print(
        '📊 New grade: $newPercentageGrade% (numerical: $numericalGrade, wasRounded: $wasRounded)',
      );

      // Update course grades
      print('💾 Step 8: Updating course grades in Firestore...');
      try {
        await _courseApi.updateCourseGrades(
          courseId: _selectedCourse!.courseId,
          grade: newPercentageGrade,
          numericalGrade: numericalGrade,
          wasRounded: wasRounded,
        );
        print('✅ Course grades updated successfully');
      } catch (e) {
        print('⚠️ Error updating course grades: $e. Will retry later.');
      }

      // Update local state
      print('📝 Step 9: Updating local course state...');
      _selectedCourse = _createUpdatedCourse(
        _selectedCourse!,
        updatedComponents.cast<Component>(),
        newGrade: newPercentageGrade,
        newNumericalGrade: numericalGrade,
        wasRounded: wasRounded,
      );
      if (_selectedCourse != null) {
        await _localStorage.saveCourse(_selectedCourse!);
      }
      print('✅ Local state updated and persisted');

      print('🔔 Step 10: Notifying listeners...');
      notifyListeners();
      print('✅ Listeners notified');
      print('🎉 Component update complete!');
    } catch (e) {
      print("❌ Error updating component: $e");
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
    // Get course before deleting to know the userId for stream update
    final courseToDelete = _localStorage.getCourse(courseId);
    final result = await _courseApi.deleteCourse(courseId);

    // Notify stream listeners immediately after deletion
    if (result == null && courseToDelete != null) {
      final courses =
          _localStorage
              .getAllCourses()
              .where((c) => c.userId == courseToDelete.userId)
              .toList();
      _coursesStreamController.add(courses);
    }

    return result;
  }

  @override
  void dispose() {
    _firebaseSubscription?.cancel();
    _coursesStreamController.close();
    super.dispose();
  }
}
