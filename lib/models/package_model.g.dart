// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'package_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PackageAdapter extends TypeAdapter<Package> {
  @override
  final int typeId = 3;

  @override
  Package read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Package(
      id: fields[0] as String,
      trackingNumber: fields[1] as String,
      courier: fields[2] as CourierType,
      pickupCode: fields[3] as String,
      location: fields[4] as String,
      description: fields[5] as String,
      urgency: fields[6] as UrgencyLevel,
      status: fields[7] as PackageStatus,
      addedAt: fields[8] as DateTime,
      pickedUpAt: fields[9] as DateTime?,
      notifiedArrived: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Package obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.trackingNumber)
      ..writeByte(2)
      ..write(obj.courier)
      ..writeByte(3)
      ..write(obj.pickupCode)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.urgency)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.addedAt)
      ..writeByte(9)
      ..write(obj.pickedUpAt)
      ..writeByte(10)
      ..write(obj.notifiedArrived);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PackageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
