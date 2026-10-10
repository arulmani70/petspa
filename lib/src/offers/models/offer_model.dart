class OfferModel {
  final String id;
  final String promoCode;
  final String title;
  final String description;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double? minOrderAmount;
  final double? maxDiscountAmount;
  final String? validUntil;
  final List<int>? applicableServices;
  final bool isActive;
  final String? imageUrl;

  OfferModel({
    required this.id,
    required this.promoCode,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount,
    this.maxDiscountAmount,
    this.validUntil,
    this.applicableServices,
    this.isActive = true,
    this.imageUrl,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['offerId'] ?? json['OfferId'] ?? json['_id'] ?? '';
    final code = json['promoCode'] ?? json['code'] ?? json['promo_code'] ?? json['PromoCode'] ?? '';
    final title = json['title'] ?? json['name'] ?? json['offerName'] ?? json['offer_name'] ?? code;
    final desc = json['description'] ?? json['desc'] ?? json['offer_description'] ?? '';
    final type = (json['discountType'] ?? json['discount_type'] ?? json['type'] ?? 'percentage')
        .toString()
        .toLowerCase();

    final rawVal = json['discountValue'] ?? json['discount'] ?? json['discountAmount'] ?? json['discount_value'] ?? json['value'] ?? 0;
    final double discountVal = rawVal is num ? rawVal.toDouble() : (double.tryParse(rawVal.toString()) ?? 0.0);

    final rawMin = json['minOrderAmount'] ?? json['minOrderValue'] ?? json['min_order_amount'] ?? json['minAmount'];
    final double? minOrder = rawMin is num ? rawMin.toDouble() : (rawMin != null ? double.tryParse(rawMin.toString()) : null);

    final rawMax = json['maxDiscountAmount'] ?? json['max_discount_amount'] ?? json['maxDiscount'] ?? json['maxAmount'];
    final double? maxDisc = rawMax is num ? rawMax.toDouble() : (rawMax != null ? double.tryParse(rawMax.toString()) : null);

    final validUntilStr = (json['validUntil'] ?? json['expiryDate'] ?? json['valid_until'] ?? json['expiry_date'] ?? json['validTo'])?.toString();
    final imgUrl = (json['imageUrl'] ?? json['image'] ?? json['bannerUrl'] ?? json['image_url'])?.toString();

    List<int>? services;
    final rawServices = json['applicableServices'] ?? json['services'] ?? json['applicable_services'];
    if (rawServices is List) {
      services = rawServices
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }

    final active = json['isActive'] != false && json['is_active'] != false;

    return OfferModel(
      id: rawId.toString(),
      promoCode: code.toString(),
      title: title.toString(),
      description: desc.toString(),
      discountType: type,
      discountValue: discountVal,
      minOrderAmount: minOrder,
      maxDiscountAmount: maxDisc,
      validUntil: validUntilStr,
      applicableServices: services,
      isActive: active,
      imageUrl: imgUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'promoCode': promoCode,
      'title': title,
      'description': description,
      'discountType': discountType,
      'discountValue': discountValue,
      if (minOrderAmount != null) 'minOrderAmount': minOrderAmount,
      if (maxDiscountAmount != null) 'maxDiscountAmount': maxDiscountAmount,
      if (validUntil != null) 'validUntil': validUntil,
      if (applicableServices != null) 'applicableServices': applicableServices,
      'isActive': isActive,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  String get discountBadge {
    if (discountType == 'percentage' || discountType == 'percent') {
      return '${discountValue.toInt()}% OFF';
    }
    return '\$${discountValue.toInt()} OFF';
  }

  DateTime? get expiryDate => validUntil != null ? DateTime.tryParse(validUntil!) : null;

  String get formattedExpiry {
    if (validUntil == null || validUntil!.isEmpty) return 'No expiry';
    final dt = DateTime.tryParse(validUntil!);
    if (dt == null) return 'Ends $validUntil';
    final diff = dt.difference(DateTime.now());
    if (diff.inDays <= 0) return 'Ends today';
    if (diff.inDays == 1) return 'Ends in 1 day';
    if (diff.inDays <= 7) return 'Ends in ${diff.inDays} days';
    return 'Ends ${dt.month}/${dt.day}';
  }

  /// Helper to calculate the discount given an order amount.
  double calculateDiscount(double orderAmount) {
    if (minOrderAmount != null && orderAmount < minOrderAmount!) {
      return 0.0;
    }
    double discount = 0.0;
    if (discountType == 'percentage' || discountType == 'percent') {
      discount = (orderAmount * discountValue) / 100.0;
    } else {
      discount = discountValue;
    }
    if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
      discount = maxDiscountAmount!;
    }
    if (discount > orderAmount) {
      discount = orderAmount;
    }
    return discount;
  }
}

class PromoValidationResult {
  final bool success;
  final String message;
  final String? promoCode;
  final double discountAmount;
  final String? discountType;
  final double? discountValue;
  final double? finalAmount;
  final String? description;
  final Map<String, dynamic>? rawData;

  PromoValidationResult({
    required this.success,
    required this.message,
    this.promoCode,
    this.discountAmount = 0.0,
    this.discountType,
    this.discountValue,
    this.finalAmount,
    this.description,
    this.rawData,
  });

  factory PromoValidationResult.fromJson(Map<String, dynamic> json, {String? defaultPromoCode, double? originalAmount}) {
    final success = json['success'] == true;
    final message = json['message']?.toString() ?? (success ? 'Promo code applied successfully' : 'Invalid promo code');
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;

    if (!success) {
      return PromoValidationResult(
        success: false,
        message: message,
        promoCode: defaultPromoCode,
        rawData: json,
      );
    }

    final code = (data['promoCode'] ?? data['code'] ?? data['promo_code'] ?? defaultPromoCode ?? '').toString();
    final rawDiscount = data['discountAmount'] ?? data['discount'] ?? data['discount_amount'] ?? data['discountValue'];
    double discAmount = 0.0;
    if (rawDiscount is num) {
      discAmount = rawDiscount.toDouble();
    } else if (rawDiscount != null) {
      discAmount = double.tryParse(rawDiscount.toString()) ?? 0.0;
    }

    final type = (data['discountType'] ?? data['discount_type'] ?? data['type'])?.toString();
    final rawVal = data['discountValue'] ?? data['discount_value'] ?? data['discount'] ?? data['value'];
    final double? discVal = rawVal is num ? rawVal.toDouble() : (rawVal != null ? double.tryParse(rawVal.toString()) : null);

    final rawFinal = data['finalAmount'] ?? data['final_amount'] ?? data['totalAmount'] ?? data['finalPrice'];
    double? finalAmt = rawFinal is num ? rawFinal.toDouble() : (rawFinal != null ? double.tryParse(rawFinal.toString()) : null);

    if (finalAmt == null && originalAmount != null) {
      finalAmt = (originalAmount - discAmount).clamp(0.0, double.infinity);
    }

    final desc = (data['description'] ?? data['offerDescription'] ?? data['offer_description'] ?? data['title'])?.toString();

    return PromoValidationResult(
      success: true,
      message: message,
      promoCode: code,
      discountAmount: discAmount,
      discountType: type,
      discountValue: discVal,
      finalAmount: finalAmt,
      description: desc,
      rawData: data,
    );
  }
}
