// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grade_range.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GradeRangeAdapter extends TypeAdapter<GradeRange> {
  @override
  final int typeId = 4;

  @override
  GradeRange read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GradeRange(
      rangeId: fields[0] as String,
      gradingSystemId: fields[1] as String,
      min: fields[2] as double,
      max: fields[3] as double,
      grade: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, GradeRange obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.rangeId)
      ..writeByte(1)
      ..write(obj.gradingSystemId)
      ..writeByte(2)
      ..write(obj.min)
      ..writeByte(3)
      ..write(obj.max)
      ..writeByte(4)
      ..write(obj.grade);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GradeRangeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
