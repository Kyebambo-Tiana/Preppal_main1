// Represents a single sales record for a day.
// Each sale entry links a product to how many units were sold and revenue made.
import 'package:json_annotation/json_annotation.dart';

part 'sale_model.g.dart';

@JsonSerializable()
class SaleItemModel {
  @JsonKey(name: 'product_id')
  final String productId;

  @JsonKey(name: 'product_name')
  final String productName;

  @JsonKey(name: 'quantity_sold')
  final double quantitySold;

  @JsonKey(name: 'unit_price')
  final double unitPrice;

  // Revenue = quantity sold × unit price (computed, not stored)
  double get revenue => quantitySold * unitPrice;

  const SaleItemModel({
    required this.productId,
    required this.productName,
    required this.quantitySold,
    required this.unitPrice,
  });

  factory SaleItemModel.fromJson(Map<String, dynamic> json) =>
      _$SaleItemModelFromJson(json);

  Map<String, dynamic> toJson() => _$SaleItemModelToJson(this);
}

@JsonSerializable()
class SaleModel {
  final String id;

  // The date this sale record belongs to (stored as ISO string in JSON)
  final DateTime date;

  // List of products sold on this day
  final List<SaleItemModel> items;

  // Notes (optional — e.g. "Market day, high traffic")
  final String? notes;

  const SaleModel({
    required this.id,
    required this.date,
    required this.items,
    this.notes,
  });

  // Total revenue for this day — sum of all item revenues
  double get totalRevenue =>
      items.fold(0.0, (sum, item) => sum + item.revenue);

  // Total units sold across all products for this day
  double get totalUnitsSold =>
      items.fold(0.0, (sum, item) => sum + item.quantitySold);

  factory SaleModel.fromJson(Map<String, dynamic> json) =>
      _$SaleModelFromJson(json);

  Map<String, dynamic> toJson() => _$SaleModelToJson(this);
}
