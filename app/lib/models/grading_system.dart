import 'package:hive/hive.dart';
import 'package:gradecalculator/models/grade_range.dart';

part 'grading_system.g.dart';

@HiveType(typeId: 3)
class GradingSystem {
  @HiveField(0)
  final String gradingSystemId;

  @HiveField(1)
  final String courseId;

  @HiveField(2)
  final List<GradeRange> gradeRanges;

  GradingSystem({
    required this.gradingSystemId,
    required this.courseId,
    required this.gradeRanges,
  });

  factory GradingSystem.fromMap(Map<String, dynamic> map) => GradingSystem(
    gradingSystemId: map['gradingSystemId'] ?? '',
    courseId: map['courseId'] ?? '',
    gradeRanges:
        map['gradeRanges'] != null
            ? List<GradeRange>.from(
              (map['gradeRanges'] as List)
                  .where((e) => e != null)
                  .map((e) => GradeRange.fromMap(Map<String, dynamic>.from(e))),
            )
            : [],
  );

  Map<String, dynamic> toMap() => {
    'gradingSystemId': gradingSystemId,
    'courseId': courseId,
    'gradeRanges': gradeRanges.map((e) => e.toMap()).toList(),
  };
}
