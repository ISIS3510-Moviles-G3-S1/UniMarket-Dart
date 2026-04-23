// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fyp_fav_relation.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FypFavRelationAdapter extends TypeAdapter<FypFavRelation> {
  @override
  final int typeId = 1;

  @override
  FypFavRelation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FypFavRelation(
      favId: fields[0] as String,
      fypItemId: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FypFavRelation obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.favId)
      ..writeByte(1)
      ..write(obj.fypItemId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FypFavRelationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
