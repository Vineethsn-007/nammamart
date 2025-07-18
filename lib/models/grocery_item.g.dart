// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grocery_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GroceryItemAdapter extends TypeAdapter<GroceryItem> {
  @override
  final int typeId = 0;

  @override
  GroceryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GroceryItem(
      id: fields[0] as String,
      name: fields[1] as String,
      price: fields[2] as double,
      originalPrice: fields[3] as double,
      discountPercentage: fields[4] as double,
      unit: fields[5] as String,
      imageUrl: fields[6] as String?,
      categoryId: fields[7] as String,
      isPopular: fields[8] as bool,
      isSpecialOffer: fields[9] as bool,
      deliveryFee: fields[10] as double?,
      gst: fields[11] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, GroceryItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.originalPrice)
      ..writeByte(4)
      ..write(obj.discountPercentage)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.imageUrl)
      ..writeByte(7)
      ..write(obj.categoryId)
      ..writeByte(8)
      ..write(obj.isPopular)
      ..writeByte(9)
      ..write(obj.isSpecialOffer)
      ..writeByte(10)
      ..write(obj.deliveryFee)
      ..writeByte(11)
      ..write(obj.gst);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroceryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
