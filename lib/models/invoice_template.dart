class InvoiceTemplateModel {
  final String businessName;
  final String businessPhone;
  final String businessAddress;
  final String invoiceTitle;
  final String footerNote;
  final String terms;
  final String logoUrl;
  final String colorHex;
  final bool showLogo;
  final bool showSignature;

  const InvoiceTemplateModel({
    required this.businessName,
    required this.businessPhone,
    required this.businessAddress,
    required this.invoiceTitle,
    required this.footerNote,
    required this.terms,
    required this.logoUrl,
    required this.colorHex,
    required this.showLogo,
    required this.showSignature,
  });

  factory InvoiceTemplateModel.fromJson(Map<String, dynamic> json) {
    return InvoiceTemplateModel(
      businessName: (json["businessName"] ?? "daftr").toString(),
      businessPhone: (json["businessPhone"] ?? "").toString(),
      businessAddress: (json["businessAddress"] ?? "").toString(),
      invoiceTitle: (json["invoiceTitle"] ?? "Sales Invoice").toString(),
      footerNote: (json["footerNote"] ?? "Thank you for your business.").toString(),
      terms: (json["terms"] ?? "").toString(),
      logoUrl: (json["logoUrl"] ?? "").toString(),
      colorHex: (json["colorHex"] ?? "#4F46E5").toString(),
      showLogo: json["showLogo"] != false,
      showSignature: json["showSignature"] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    "businessName": businessName,
    "businessPhone": businessPhone,
    "businessAddress": businessAddress,
    "invoiceTitle": invoiceTitle,
    "footerNote": footerNote,
    "terms": terms,
    "logoUrl": logoUrl,
    "colorHex": colorHex,
    "showLogo": showLogo,
    "showSignature": showSignature,
  };
}
