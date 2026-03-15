// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProductModel _$ProductModelFromJson(Map<String, dynamic> json) => ProductModel(
  id: json['id'] as String? ?? '',
  name: json['name'] as String? ?? '',
  category:
      $enumDecodeNullable(
        _$ProductCategoryEnumMap,
        json['category'],
        unknownValue: ProductCategory.others,
      ) ??
      ProductCategory.others,
  productionDate: ProductModel._decodeProdDate(json['production_date']),
  shelfLife: ProductModel._decodeInt(json['shelf_life']),
  quantityAvailable: ProductModel._decodeDouble(json['quantity_available']),
  price: ProductModel._decodeDouble(json['price']),
  shelf: ProductModel._decodeDouble(json['shelf']),
  unit:
      $enumDecodeNullable(
        _$ProductUnitEnumMap,
        json['unit'],
        unknownValue: ProductUnit.pcs,
      ) ??
      ProductUnit.pcs,
  currency: json['currency'] as String? ?? 'NGN',
  lowStockThreshold: ProductModel._decodeNullableDouble(
    json['low_stock_threshold'],
  ),
  isActive: json['is_active'] as bool? ?? true,
);

Map<String, dynamic> _$ProductModelToJson(ProductModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'category': _$ProductCategoryEnumMap[instance.category]!,
      'production_date': instance.productionDate.toIso8601String(),
      'shelf_life': instance.shelfLife,
      'quantity_available': instance.quantityAvailable,
      'price': instance.price,
      'shelf': instance.shelf,
      'unit': _$ProductUnitEnumMap[instance.unit]!,
      'currency': instance.currency,
      'low_stock_threshold': instance.lowStockThreshold,
      'is_active': instance.isActive,
    };

const _$ProductCategoryEnumMap = {
  ProductCategory.beverages: 'Beverages',
  ProductCategory.dairy: 'Dairy',
  ProductCategory.snacks: 'Snacks',
  ProductCategory.produce: 'Produce',
  ProductCategory.bakery: 'Bakery',
  ProductCategory.meat: 'Meat',
  ProductCategory.spices: 'Spices',
  ProductCategory.frozen: 'Frozen',
  ProductCategory.others: 'Others',
};

const _$ProductUnitEnumMap = {
  ProductUnit.kg: 'kg',
  ProductUnit.g: 'g',
  ProductUnit.litre: 'L',
  ProductUnit.ml: 'ml',
  ProductUnit.pcs: 'pcs',
  ProductUnit.dozen: 'dozen',
};
