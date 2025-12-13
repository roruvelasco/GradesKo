import 'package:hive/hive.dart';
import 'package:gradecalculator/models/components.dart';
import 'package:gradecalculator/models/grading_system.dart';

part 'course.g.dart';

@HiveType(typeId: 0)
class Course {
  @HiveField(0)
  final String courseId;

  @HiveField(1)
  final String userId;

  @HiveField(2)
  final String courseName;

  @HiveField(3)
  final String courseCode;

  @HiveField(4)
  final String units;

  @HiveField(5)
  final String? instructor;

  @HiveField(6)
  final String academicYear;

  @HiveField(7)
  final String semester;

  @HiveField(8)
  final GradingSystem gradingSystem;

  @HiveField(9)
  final List<Component?> components;

  @HiveField(10)
  final double? grade;

  @HiveField(11)
  final double? numericalGrade;

  @HiveField(12)
  final bool? wasRounded;

  Course({
    required this.courseId,
    required this.userId,
    required this.courseName,
    required this.courseCode,
    required this.units,
    this.instructor,
    required this.academicYear,
    required this.semester,
    required this.gradingSystem,
    this.components = const [],
    this.grade = 0.0,
    this.numericalGrade,
    this.wasRounded,
  });

  factory Course.fromMap(Map<String, dynamic> map) => Course(
    courseId: map['courseId'] ?? '',
    userId: map['userId'] ?? '',
    courseName: map['courseName'] ?? '',
    courseCode: map['courseCode'] ?? '',
    units: map['units'] ?? '',
    instructor: map['instructor'],
    academicYear: map['academicYear'] ?? '',
    semester: map['semester'] ?? '',
    gradingSystem:
        map['gradingSystem'] != null
            ? GradingSystem.fromMap(
              Map<String, dynamic>.from(map['gradingSystem']),
            )
            : GradingSystem(
              gradingSystemId: '',
              courseId: map['courseId'] ?? '',
              gradeRanges: [],
            ),
    components:
        map['components'] != null
            ? List<Component?>.from(
              (map['components'] as List).map(
                (e) =>
                    e == null
                        ? null
                        : Component.fromMap(Map<String, dynamic>.from(e)),
              ),
            )
            : [],
    grade:
        map['grade'] != null
            ? (map['grade'] is int
                ? (map['grade'] as int).toDouble()
                : map['grade'] as double)
            : null, // <-- Add this line
    numericalGrade:
        map['numericalGrade'] != null
            ? (map['numericalGrade'] is int
                ? (map['numericalGrade'] as int).toDouble()
                : map['numericalGrade'] as double)
            : null,
    wasRounded: map['wasRounded'] as bool?,
  );

  Map<String, dynamic> toMap() => {
    'courseId': courseId,
    'userId': userId,
    'courseName': courseName,
    'courseCode': courseCode,
    'units': units,
    'instructor': instructor,
    'academicYear': academicYear,
    'semester': semester,
    'gradingSystem': gradingSystem.toMap(),
    'components': components.map((e) => e?.toMap()).toList(),
    'grade': grade,
    'numericalGrade': numericalGrade,
    'wasRounded': wasRounded,
  };
}
