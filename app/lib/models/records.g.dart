// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'records.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecordsAdapter extends TypeAdapter<Records> {
  @override
  final int typeId = 2;

  @override
  Records read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Records(
      name: fields[2] as String,
      score: fields[3] as double,
      total: fields[4] as double,
      recordId: fields[0] as String,
      componentId: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Records obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.recordId)
      ..writeByte(1)
      ..write(obj.componentId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.score)
      ..writeByte(4)
      ..write(obj.total);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecordsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
