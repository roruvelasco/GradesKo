// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CourseAdapter extends TypeAdapter<Course> {
  @override
  final int typeId = 0;

  @override
  Course read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Course(
      courseId: fields[0] as String,
      userId: fields[1] as String,
      courseName: fields[2] as String,
      courseCode: fields[3] as String,
      units: fields[4] as String,
      instructor: fields[5] as String?,
      academicYear: fields[6] as String,
      semester: fields[7] as String,
      gradingSystem: fields[8] as GradingSystem,
      components: (fields[9] as List).cast<Component?>(),
      grade: fields[10] as double?,
      numericalGrade: fields[11] as double?,
      wasRounded: fields[12] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, Course obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.courseId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.courseName)
      ..writeByte(3)
      ..write(obj.courseCode)
      ..writeByte(4)
      ..write(obj.units)
      ..writeByte(5)
      ..write(obj.instructor)
      ..writeByte(6)
      ..write(obj.academicYear)
      ..writeByte(7)
      ..write(obj.semester)
      ..writeByte(8)
      ..write(obj.gradingSystem)
      ..writeByte(9)
      ..write(obj.components)
      ..writeByte(10)
      ..write(obj.grade)
      ..writeByte(11)
      ..write(obj.numericalGrade)
      ..writeByte(12)
      ..write(obj.wasRounded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
