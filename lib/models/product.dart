class ProductVariant {
  final String id;
  final String name;
  final String sku;
  final String imageUrl;
  final double purchasePrice;
  final String purchaseCurrency;
  final double sellingPrice;
  final double quantity;
  final double weight;
  final double minStock;
  final String currency;
  final String unit;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.sku,
    required this.imageUrl,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.sellingPrice,
    required this.quantity,
    required this.weight,
    required this.minStock,
    required this.currency,
    required this.unit,
  });

  bool get isLowStock => quantity <= minStock;

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      sku: (json["sku"] ?? "").toString(),
      imageUrl: (json["imageUrl"] ?? "").toString(),
      purchasePrice: _num(json["purchasePrice"]),
      purchaseCurrency: (json["purchaseCurrency"] ?? json["currency"] ?? "LBP").toString(),
      sellingPrice: _num(json["sellingPrice"]),
      quantity: _num(json["quantity"]),
      weight: _num(json["weight"]),
      minStock: _num(json["minStock"]),
      currency: (json["currency"] ?? "LBP").toString(),
      unit: (json["unit"] ?? "Piece").toString(),
    );
  }
}

class Product {
  final String id;
  final String category;
  final String subcategory;
  final String name;
  final String sku;
  final String imageUrl;
  final bool hasVariants;
  final double purchasePrice;
  final String purchaseCurrency;
  final double sellingPrice;
  final double quantity;
  final double weight;
  final double minStock;
  final String currency;
  final String unit;
  final List<ProductVariant> variants;

  const Product({
    required this.id,
    required this.category,
    required this.subcategory,
    required this.name,
    required this.sku,
    required this.imageUrl,
    required this.hasVariants,
    required this.purchasePrice,
    required this.purchaseCurrency,
    required this.sellingPrice,
    required this.quantity,
    required this.weight,
    required this.minStock,
    required this.currency,
    required this.unit,
    required this.variants,
  });

  bool get isLowStock => !hasVariants && quantity <= minStock;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawVariants = json["variants"];
    return Product(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      category: (json["category"] ?? "General").toString(),
      subcategory: (json["subcategory"] ?? "General").toString(),
      name: (json["name"] ?? "").toString(),
      sku: (json["sku"] ?? "").toString(),
      imageUrl: (json["imageUrl"] ?? "").toString(),
      hasVariants: json["hasVariants"] == true,
      purchasePrice: _num(json["purchasePrice"]),
      purchaseCurrency: (json["purchaseCurrency"] ?? json["currency"] ?? "LBP").toString(),
      sellingPrice: _num(json["sellingPrice"]),
      quantity: _num(json["quantity"]),
      weight: _num(json["weight"]),
      minStock: _num(json["minStock"]),
      currency: (json["currency"] ?? "LBP").toString(),
      unit: (json["unit"] ?? "Piece").toString(),
      variants: rawVariants is List
          ? rawVariants.map((e) => ProductVariant.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : [],
    );
  }
}

double _num(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
