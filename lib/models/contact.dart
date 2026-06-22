class ContactModel {
  final String id;
  final String name;
  final String phone;
  final String countryCode;
  final String imageUrl;
  final String address;
  final String type;
  final String note;

  const ContactModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.countryCode,
    required this.imageUrl,
    required this.address,
    required this.type,
    required this.note,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      countryCode: (json["countryCode"] ?? "+961").toString(),
      imageUrl: (json["imageUrl"] ?? "").toString(),
      address: (json["address"] ?? "").toString(),
      type: (json["type"] ?? "customer").toString(),
      note: (json["note"] ?? "").toString(),
    );
  }

  String get fullPhone => "$countryCode$phone";
}
