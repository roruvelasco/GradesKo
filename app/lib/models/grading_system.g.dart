// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grading_system.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GradingSystemAdapter extends TypeAdapter<GradingSystem> {
  @override
  final int typeId = 3;

  @override
  GradingSystem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GradingSystem(
      gradingSystemId: fields[0] as String,
      courseId: fields[1] as String,
      gradeRanges: (fields[2] as List).cast<GradeRange>(),
    );
  }

  @override
  void write(BinaryWriter writer, GradingSystem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.gradingSystemId)
      ..writeByte(1)
      ..write(obj.courseId)
      ..writeByte(2)
      ..write(obj.gradeRanges);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradingSystemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
