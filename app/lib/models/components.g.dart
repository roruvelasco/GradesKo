// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'components.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComponentAdapter extends TypeAdapter<Component> {
  @override
  final int typeId = 1;

  @override
  Component read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Component(
      componentId: fields[0] as String,
      componentName: fields[1] as String,
      weight: fields[2] as double,
      courseId: fields[3] as String,
      records: (fields[4] as List?)?.cast<Records>(),
    );
  }

  @override
  void write(BinaryWriter writer, Component obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.componentId)
      ..writeByte(1)
      ..write(obj.componentName)
      ..writeByte(2)
      ..write(obj.weight)
      ..writeByte(3)
      ..write(obj.courseId)
      ..writeByte(4)
      ..write(obj.records);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComponentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
