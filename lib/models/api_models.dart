import 'dart:developer' as dev;

import 'vehicle.dart';

double jsonDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int jsonInt(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool jsonBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

DateTime? jsonDateTime(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

String? jsonString(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

class AuthResult {
  final String token;
  final UserProfile? user;
  final bool requiresVehicle;

  const AuthResult({
    required this.token,
    this.user,
    this.requiresVehicle = false,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];

    return AuthResult(
      token:
          jsonString(json['token']) ??
          jsonString(json['accessToken']) ??
          jsonString(json['access_token']) ??
          jsonString(json['authToken']) ??
          jsonString(json['jwt']) ??
          '',
      user: userJson is Map<String, dynamic>
          ? UserProfile.fromJson(userJson)
          : null,
      requiresVehicle: jsonBool(json['requiresVehicle']),
    );
  }
}

class UserProfile {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String? email;
  final String? idNumber;
  final String? county;
  final String role;
  final bool phoneVerified;

  const UserProfile({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.email,
    this.idNumber,
    this.county,
    this.role = 'USER',
    this.phoneVerified = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: jsonString(json['id']) ?? '',
      phoneNumber: jsonString(json['phoneNumber']) ?? '',
      fullName: jsonString(json['fullName']) ?? '',
      email: jsonString(json['email']),
      idNumber: jsonString(json['idNumber']),
      county: jsonString(json['county']),
      role: jsonString(json['role']) ?? 'USER',
      phoneVerified: jsonBool(json['phoneVerified']),
    );
  }
}

class WalletTransaction {
  final String id;
  final double amount;
  final String type;
  final String status;
  final String? reference;
  final String? description;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.status,
    this.reference,
    this.description,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: jsonString(json['id']) ?? '',
      amount: jsonDouble(json['amount']),
      type: jsonString(json['type']) ?? 'PAYMENT',
      status: jsonString(json['status']) ?? 'PENDING',
      reference: jsonString(json['reference']),
      description: jsonString(json['description']),
      createdAt: jsonDateTime(json['createdAt']),
    );
  }
}

class ParkingLocation {
  final String id;
  final String name;
  final String? address;
  final double ratePerHour;
  final int maxCapacity;
  final int currentOccupancy;
  final bool active;

  const ParkingLocation({
    required this.id,
    required this.name,
    this.address,
    this.ratePerHour = 0,
    this.maxCapacity = 0,
    this.currentOccupancy = 0,
    this.active = true,
  });

  factory ParkingLocation.fromJson(Map<String, dynamic> json) {
    return ParkingLocation(
      id: jsonString(json['id']) ?? '',
      name: jsonString(json['name']) ?? 'Parking Location',
      address: jsonString(json['address']),
      ratePerHour: jsonDouble(json['ratePerHour']),
      maxCapacity: jsonInt(json['maxCapacity']),
      currentOccupancy: jsonInt(json['currentOccupancy']),
      active: jsonBool(json['active'], true),
    );
  }

  double get occupancyRatio {
    if (maxCapacity <= 0) return 0;
    return (currentOccupancy / maxCapacity).clamp(0, 1);
  }
}

class PricingTier {
  final int fromMinute;
  final int? toMinute;
  final String pricingType;
  final double price;

  const PricingTier({
    required this.fromMinute,
    this.toMinute,
    required this.pricingType,
    required this.price,
  });

  factory PricingTier.fromJson(Map<String, dynamic> json) {
    return PricingTier(
      fromMinute: jsonInt(json['fromMinute']),
      toMinute: json['toMinute'] == null ? null : jsonInt(json['toMinute']),
      pricingType: jsonString(json['pricingType']) ?? 'PER_HOUR',
      price: jsonDouble(json['price']),
    );
  }

  bool get isFlat => pricingType == 'FLAT';

  String get fromLabel {
    if (fromMinute < 60) return '${fromMinute}m';
    final h = fromMinute ~/ 60;
    final m = fromMinute % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String get toLabel {
    if (toMinute == null) return '∞';
    if (toMinute! < 60) return '${toMinute}m';
    final h = toMinute! ~/ 60;
    final m = toMinute! % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class NearestParkingLocation {
  final String id;
  final String name;
  final String? address;
  final String? displayImage;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;
  final double ratePerHour;
  final double? maxDailyCharge;
  final int gracePeriodMinutes;
  final int currentOccupancy;
  final int maxCapacity;
  final bool active;
  final List<PricingTier> pricingTiers;

  const NearestParkingLocation({
    required this.id,
    required this.name,
    this.address,
    this.displayImage,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.ratePerHour = 0,
    this.maxDailyCharge,
    this.gracePeriodMinutes = 0,
    this.currentOccupancy = 0,
    this.maxCapacity = 0,
    this.active = true,
    this.pricingTiers = const [],
  });

  factory NearestParkingLocation.fromJson(Map<String, dynamic> json) {
    final rawLat = jsonDouble(json['latitude'] ?? json['lat'], double.nan);
    final rawLng = jsonDouble(json['longitude'] ?? json['lng'] ?? json['lon'], double.nan);
    final double? lat = rawLat.isNaN ? null : rawLat;
    final double? lng = rawLng.isNaN ? null : rawLng;

    final rawDist = jsonDouble(json['distance'] ?? json['distanceKm'] ?? json['distance_km'], double.nan);
    final double? dist = rawDist.isNaN ? null : rawDist;

    final rawDaily = jsonDouble(json['maxDailyCharge'] ?? json['max_daily_charge'], double.nan);
    final double? maxDaily = rawDaily.isNaN || rawDaily == 0 ? null : rawDaily;

    final capacity = jsonInt(json['maxCapacity'] ?? json['capacity']);
    final occupancy = jsonInt(json['currentOccupancy'] ?? json['occupancy']);

    final tiersRaw = json['pricingTiers'];
    final tiers = tiersRaw is List
        ? tiersRaw
            .whereType<Map<String, dynamic>>()
            .map(PricingTier.fromJson)
            .where((t) => t.price > 0)
            .toList()
        : <PricingTier>[];

    return NearestParkingLocation(
      id: jsonString(json['id']) ?? '',
      name: jsonString(json['name']) ?? 'Parking Location',
      address: jsonString(json['address']),
      displayImage: jsonString(json['displayImage'] ?? json['image'] ?? json['imageUrl']),
      latitude: lat,
      longitude: lng,
      distanceKm: dist,
      ratePerHour: jsonDouble(json['ratePerHour'] ?? json['rate_per_hour']),
      maxDailyCharge: maxDaily,
      gracePeriodMinutes: jsonInt(json['gracePeriodMinutes'] ?? json['grace_period_minutes']),
      currentOccupancy: occupancy,
      maxCapacity: capacity,
      active: jsonBool(json['active'], true),
      pricingTiers: tiers,
    );
  }

  bool get hasCoordinates => latitude != null && longitude != null;

  int get availableSpots => maxCapacity > 0
      ? (maxCapacity - currentOccupancy).clamp(0, maxCapacity)
      : 0;

  double get occupancyRatio => maxCapacity > 0
      ? (currentOccupancy / maxCapacity).clamp(0.0, 1.0)
      : 0.0;
}

class MpesaResponse {
  final String? paymentId;
  final String? merchantRequestId;
  final String? checkoutRequestId;
  final String? responseCode;
  final String? responseDescription;
  final String? customerMessage;
  final String? status;

  const MpesaResponse({
    this.paymentId,
    this.merchantRequestId,
    this.checkoutRequestId,
    this.responseCode,
    this.responseDescription,
    this.customerMessage,
    this.status,
  });

  factory MpesaResponse.fromJson(Map<String, dynamic> json) {
    dev.log(
      'MpesaResponse.fromJson: keys=${json.keys.toList()} values=${json.values.toList()}',
      name: 'ApiModels',
    );
    final result = MpesaResponse(
      paymentId: jsonString(json['paymentId']) ?? jsonString(json['id']),
      merchantRequestId:
          jsonString(json['merchantRequestId']) ??
          jsonString(json['MerchantRequestID']),
      checkoutRequestId:
          jsonString(json['checkoutRequestId']) ??
          jsonString(json['CheckoutRequestID']),
      responseCode:
          jsonString(json['responseCode']) ?? jsonString(json['ResponseCode']),
      responseDescription:
          jsonString(json['responseDescription']) ??
          jsonString(json['ResponseDescription']),
      customerMessage:
          jsonString(json['customerMessage']) ??
          jsonString(json['CustomerMessage']),
      status: jsonString(json['status']),
    );
    dev.log(
      'MpesaResponse.fromJson: parsed — checkoutRequestId=${result.checkoutRequestId} '
      'responseCode=${result.responseCode} customerMessage=${result.customerMessage}',
      name: 'ApiModels',
    );
    return result;
  }
}

class PaymentStatusSnapshot {
  final String? paymentId;
  final String? checkoutRequestId;
  final String? sessionId;
  final String status;
  final String? message;

  const PaymentStatusSnapshot({
    this.paymentId,
    this.checkoutRequestId,
    this.sessionId,
    required this.status,
    this.message,
  });

  factory PaymentStatusSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentStatusSnapshot(
      paymentId: jsonString(json['paymentId']) ?? jsonString(json['id']),
      checkoutRequestId:
          jsonString(json['checkoutRequestId']) ??
          jsonString(json['CheckoutRequestID']),
      sessionId:
          jsonString(json['sessionId']) ?? jsonString(json['parkingSessionId']),
      status:
          (jsonString(json['status']) ??
                  jsonString(json['paymentStatus']) ??
                  jsonString(json['ResultDesc']) ??
                  'PENDING')
              .toUpperCase(),
      message:
          jsonString(json['message']) ??
          jsonString(json['resultDesc']) ??
          jsonString(json['ResultDesc']) ??
          jsonString(json['customerMessage']),
    );
  }

  bool get isSuccess => status == 'SUCCESS' || status == 'COMPLETED';

  bool get isTerminal => const {
    'SUCCESS',
    'COMPLETED',
    'FAILED',
    'CANCELLED',
    'CANCELED',
    'TIMEOUT',
    'TIMED_OUT',
  }.contains(status);

  bool get isFailure => isTerminal && !isSuccess;
}

class DiscountRedemption {
  final String id;
  final String discountRuleId;
  final String tenantId;
  final String tenantName;
  final String sessionId;
  final double discountAmount;
  final bool used;
  final DateTime? appliedAt;
  final double originalAmount;
  final double finalAmount;
  final String reimbursementStatus;

  const DiscountRedemption({
    required this.id,
    required this.discountRuleId,
    required this.tenantId,
    required this.tenantName,
    required this.sessionId,
    required this.discountAmount,
    required this.used,
    this.appliedAt,
    required this.originalAmount,
    required this.finalAmount,
    required this.reimbursementStatus,
  });

  factory DiscountRedemption.fromJson(Map<String, dynamic> json) {
    return DiscountRedemption(
      id: jsonString(json['id']) ?? '',
      discountRuleId: jsonString(json['discountRuleId']) ?? '',
      tenantId: jsonString(json['tenantId']) ?? '',
      tenantName: jsonString(json['tenantName']) ?? '',
      sessionId: jsonString(json['sessionId']) ?? '',
      discountAmount: jsonDouble(json['discountAmount']),
      used: jsonBool(json['used']),
      appliedAt: jsonDateTime(json['appliedAt']),
      originalAmount: jsonDouble(json['originalAmount']),
      finalAmount: jsonDouble(json['finalAmount']),
      reimbursementStatus:
          (jsonString(json['reimbursementStatus']) ?? 'NOT_REQUIRED')
              .toUpperCase(),
    );
  }
}

class QrCodeResponse {
  final String? id;
  final String? locationId;
  final String? locationName;
  final String? gateId;
  final String? gateName;
  final String? content;
  final String? imageBase64;
  final String? mimeType;
  final DateTime? expiresAt;
  final bool active;
  final DateTime? createdAt;

  const QrCodeResponse({
    this.id,
    this.locationId,
    this.locationName,
    this.gateId,
    this.gateName,
    this.content,
    this.imageBase64,
    this.mimeType,
    this.expiresAt,
    this.active = true,
    this.createdAt,
  });

  factory QrCodeResponse.fromJson(Map<String, dynamic> json) {
    return QrCodeResponse(
      id: jsonString(json['id']),
      locationId: jsonString(json['locationId']),
      locationName: jsonString(json['locationName']),
      gateId: jsonString(json['gateId']),
      gateName: jsonString(json['gateName']),
      content: jsonString(json['content']),
      imageBase64: jsonString(json['imageBase64']),
      mimeType: jsonString(json['mimeType']),
      expiresAt: jsonDateTime(json['expiresAt']),
      active: jsonBool(json['active'], true),
      createdAt: jsonDateTime(json['createdAt']),
    );
  }
}

class DashboardStats {
  final int users;
  final int vehicles;
  final int activeSessions;
  final double revenueToday;
  final List<ParkingLocation> locations;

  const DashboardStats({
    this.users = 0,
    this.vehicles = 0,
    this.activeSessions = 0,
    this.revenueToday = 0,
    this.locations = const [],
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'];

    return DashboardStats(
      users: jsonInt(json['users']),
      vehicles: jsonInt(json['vehicles']),
      activeSessions: jsonInt(json['activeSessions']),
      revenueToday: jsonDouble(json['revenueToday']),
      locations: locationsJson is List
          ? locationsJson
                .whereType<Map<String, dynamic>>()
                .map(ParkingLocation.fromJson)
                .toList()
          : const [],
    );
  }
}

class RevenueReport {
  final DateTime? startDate;
  final DateTime? endDate;
  final double totalRevenue;
  final int payments;
  final double averagePayment;

  const RevenueReport({
    this.startDate,
    this.endDate,
    this.totalRevenue = 0,
    this.payments = 0,
    this.averagePayment = 0,
  });

  factory RevenueReport.fromJson(Map<String, dynamic> json) {
    return RevenueReport(
      startDate: jsonDateTime(json['startDate']),
      endDate: jsonDateTime(json['endDate']),
      totalRevenue: jsonDouble(json['totalRevenue']),
      payments: jsonInt(json['payments']),
      averagePayment: jsonDouble(json['averagePayment']),
    );
  }
}

class OccupancyReport {
  final List<ParkingLocation> locations;

  const OccupancyReport({this.locations = const []});

  factory OccupancyReport.fromJson(Map<String, dynamic> json) {
    final locationsJson = json['locations'];

    return OccupancyReport(
      locations: locationsJson is List
          ? locationsJson
                .whereType<Map<String, dynamic>>()
                .map(ParkingLocation.fromJson)
                .toList()
          : const [],
    );
  }
}

class TenancyPolicy {
  final String id;
  final String locationId;
  final String locationName;
  final String name;
  final int allocatedSlots;
  final double subscriptionFee;
  final String pricingPlanName;
  final String slotEnforcement;
  final int subscriptionDurationDays;
  final int gracePeriodDays;
  final bool active;

  const TenancyPolicy({
    required this.id,
    required this.locationId,
    required this.locationName,
    required this.name,
    required this.allocatedSlots,
    required this.subscriptionFee,
    required this.pricingPlanName,
    required this.slotEnforcement,
    required this.subscriptionDurationDays,
    required this.gracePeriodDays,
    required this.active,
  });

  factory TenancyPolicy.fromJson(Map<String, dynamic> json) {
    return TenancyPolicy(
      id: jsonString(json['id']) ?? '',
      locationId: jsonString(json['locationId']) ?? '',
      locationName: jsonString(json['locationName']) ?? '',
      name: jsonString(json['name']) ?? 'Tenant Parking',
      allocatedSlots: jsonInt(json['allocatedSlots']),
      subscriptionFee: jsonDouble(json['subscriptionFee']),
      pricingPlanName:
          jsonString(json['pricingPlanName']) ?? 'Tenant Parking',
      slotEnforcement:
          jsonString(json['slotEnforcement']) ?? 'ALLOCATED_SLOTS',
      subscriptionDurationDays: jsonInt(json['subscriptionDurationDays']),
      gracePeriodDays: jsonInt(json['gracePeriodDays']),
      active: jsonBool(json['active'], true),
    );
  }
}

class TenantProfile {
  final String id;
  final String name;
  final String clientId;
  final String clientName;
  final String locationId;
  final String locationName;
  final int allocatedSlots;
  final String status;
  final String paymentStatus;
  final String slotEnforcement;
  final double subscriptionFee;
  final String pricingPlanName;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final List<String> plateNumbers;
  final String ownerId;
  final String ownerName;
  final String ownerPhoneNumber;

  const TenantProfile({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
    required this.locationId,
    required this.locationName,
    required this.allocatedSlots,
    required this.status,
    required this.paymentStatus,
    required this.slotEnforcement,
    required this.subscriptionFee,
    required this.pricingPlanName,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.plateNumbers = const [],
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoneNumber,
  });

  factory TenantProfile.fromJson(Map<String, dynamic> json) {
    final plates = json['plateNumbers'];

    return TenantProfile(
      id: jsonString(json['id']) ?? '',
      name: jsonString(json['name']) ??
          jsonString(json['tenantName']) ??
          'Tenant profile',
      clientId: jsonString(json['clientId']) ?? '',
      clientName: jsonString(json['clientName']) ?? '',
      locationId: jsonString(json['locationId']) ?? '',
      locationName: jsonString(json['locationName']) ?? '',
      allocatedSlots: jsonInt(json['allocatedSlots']),
      status: (jsonString(json['status']) ?? 'PENDING').toUpperCase(),
      paymentStatus:
          (jsonString(json['paymentStatus']) ?? 'PENDING').toUpperCase(),
      slotEnforcement:
          jsonString(json['slotEnforcement']) ?? 'ALLOCATED_SLOTS',
      subscriptionFee: jsonDouble(json['subscriptionFee']),
      pricingPlanName:
          jsonString(json['pricingPlanName']) ?? 'Tenant Parking',
      subscriptionStartDate: jsonDateTime(json['subscriptionStartDate']),
      subscriptionEndDate: jsonDateTime(json['subscriptionEndDate']),
      plateNumbers: plates is List
          ? plates.map((item) => item.toString()).where((v) => v.isNotEmpty).toList()
          : const [],
      ownerId: jsonString(json['ownerId']) ?? '',
      ownerName: jsonString(json['ownerName']) ?? '',
      ownerPhoneNumber: jsonString(json['ownerPhoneNumber']) ?? '',
    );
  }

  bool get isActivePaid => status == 'ACTIVE' && paymentStatus == 'PAID';

  bool get canPay {
    if (status == 'SUSPENDED') return false;
    if (isActivePaid) return false;
    return const {
      'PENDING',
      'OVERDUE',
      'EXPIRED',
      'UNPAID',
    }.contains(status) ||
        const {
          'PENDING',
          'OVERDUE',
          'UNPAID',
          'FAILED',
        }.contains(paymentStatus);
  }
}

class TenantSubscription {
  final String id;
  final String tenantId;
  final String tenantName;
  final String pricingType;
  final double amount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String paymentStatus;
  final int gracePeriodDays;
  final DateTime? createdAt;

  const TenantSubscription({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.pricingType,
    required this.amount,
    this.startDate,
    this.endDate,
    required this.status,
    required this.paymentStatus,
    required this.gracePeriodDays,
    this.createdAt,
  });

  factory TenantSubscription.fromJson(Map<String, dynamic> json) {
    return TenantSubscription(
      id: jsonString(json['id']) ?? '',
      tenantId: jsonString(json['tenantId']) ?? '',
      tenantName: jsonString(json['tenantName']) ?? '',
      pricingType: jsonString(json['pricingType']) ?? 'FIXED_FEE',
      amount: jsonDouble(json['amount']),
      startDate: jsonDateTime(json['startDate']),
      endDate: jsonDateTime(json['endDate']),
      status: (jsonString(json['status']) ?? 'PENDING').toUpperCase(),
      paymentStatus:
          (jsonString(json['paymentStatus']) ?? 'PENDING').toUpperCase(),
      gracePeriodDays: jsonInt(json['gracePeriodDays']),
      createdAt: jsonDateTime(json['createdAt']),
    );
  }

  bool get isActivePaid => status == 'ACTIVE' && paymentStatus == 'PAID';
}

class TenantPaymentStatus {
  final String? paymentId;
  final String? checkoutRequestId;
  final String? accountReference;
  final String type;
  final String paymentStatus;
  final String? mpesaReceiptNumber;
  final String? tenantId;
  final String? tenantName;
  final String? subscriptionId;
  final String tenantPaymentStatus;
  final String subscriptionStatus;
  final String? customerMessage;

  const TenantPaymentStatus({
    this.paymentId,
    this.checkoutRequestId,
    this.accountReference,
    this.type = 'TENANT_SUBSCRIPTION',
    required this.paymentStatus,
    this.mpesaReceiptNumber,
    this.tenantId,
    this.tenantName,
    this.subscriptionId,
    this.tenantPaymentStatus = 'PENDING',
    this.subscriptionStatus = 'PENDING',
    this.customerMessage,
  });

  factory TenantPaymentStatus.fromJson(Map<String, dynamic> json) {
    return TenantPaymentStatus(
      paymentId: jsonString(json['paymentId']) ?? jsonString(json['id']),
      checkoutRequestId:
          jsonString(json['checkoutRequestId']) ??
          jsonString(json['CheckoutRequestID']),
      accountReference: jsonString(json['accountReference']),
      type: jsonString(json['type']) ?? 'TENANT_SUBSCRIPTION',
      paymentStatus:
          (jsonString(json['paymentStatus']) ??
                  jsonString(json['status']) ??
                  'PENDING')
              .toUpperCase(),
      mpesaReceiptNumber: jsonString(json['mpesaReceiptNumber']),
      tenantId: jsonString(json['tenantId']),
      tenantName: jsonString(json['tenantName']),
      subscriptionId: jsonString(json['subscriptionId']),
      tenantPaymentStatus:
          (jsonString(json['tenantPaymentStatus']) ?? 'PENDING')
              .toUpperCase(),
      subscriptionStatus:
          (jsonString(json['subscriptionStatus']) ?? 'PENDING').toUpperCase(),
      customerMessage:
          jsonString(json['customerMessage']) ?? jsonString(json['message']),
    );
  }

  bool get isSuccess =>
      paymentStatus == 'SUCCESS' ||
      paymentStatus == 'COMPLETED' ||
      (tenantPaymentStatus == 'PAID' && subscriptionStatus == 'ACTIVE');

  bool get isTerminal => const {
        'SUCCESS',
        'COMPLETED',
        'FAILED',
        'CANCELLED',
        'CANCELED',
        'TIMEOUT',
        'TIMED_OUT',
      }.contains(paymentStatus) ||
      isSuccess;

  bool get isFailure => isTerminal && !isSuccess;
}

class TenancyRequest {
  final String id;
  final String requesterId;
  final String requesterName;
  final String locationId;
  final String locationName;
  final String tenantName;
  final String plateNumber;
  final String message;
  final String status;
  final String? reviewedById;
  final String? reviewComment;
  final int allocatedSlots;
  final double subscriptionFee;
  final String? pricingPlanName;
  final String? slotEnforcement;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const TenancyRequest({
    required this.id,
    required this.requesterId,
    required this.requesterName,
    required this.locationId,
    required this.locationName,
    required this.tenantName,
    required this.plateNumber,
    required this.message,
    required this.status,
    this.reviewedById,
    this.reviewComment,
    this.allocatedSlots = 0,
    this.subscriptionFee = 0,
    this.pricingPlanName,
    this.slotEnforcement,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.createdAt,
    this.reviewedAt,
  });

  factory TenancyRequest.fromJson(Map<String, dynamic> json) {
    return TenancyRequest(
      id: jsonString(json['id']) ?? '',
      requesterId: jsonString(json['requesterId']) ?? '',
      requesterName: jsonString(json['requesterName']) ?? '',
      locationId: jsonString(json['locationId']) ?? '',
      locationName: jsonString(json['locationName']) ?? '',
      tenantName: jsonString(json['tenantName']) ?? '',
      plateNumber: jsonString(json['plateNumber']) ?? '',
      message: jsonString(json['message']) ?? '',
      status: jsonString(json['status']) ?? 'PENDING',
      reviewedById: jsonString(json['reviewedById']),
      reviewComment: jsonString(json['reviewComment']),
      allocatedSlots: jsonInt(json['allocatedSlots']),
      subscriptionFee: jsonDouble(json['subscriptionFee']),
      pricingPlanName: jsonString(json['pricingPlanName']),
      slotEnforcement: jsonString(json['slotEnforcement']),
      subscriptionStartDate: jsonDateTime(json['subscriptionStartDate']),
      subscriptionEndDate: jsonDateTime(json['subscriptionEndDate']),
      createdAt: jsonDateTime(json['createdAt']),
      reviewedAt: jsonDateTime(json['reviewedAt']),
    );
  }
}

Map<String, dynamic> locationRequestBody({
  required String name,
  String? address,
  double? ratePerHour,
  int? maxCapacity,
  int? gracePeriodMinutes,
  double? maxDailyCharge,
}) {
  return {
    'name': name,
    'address': ?address,
    'ratePerHour': ?ratePerHour,
    'maxCapacity': ?maxCapacity,
    'gracePeriodMinutes': ?gracePeriodMinutes,
    'maxDailyCharge': ?maxDailyCharge,
  };
}

Vehicle vehicleFromParkingSessionJson(Map<String, dynamic> json) {
  final vehicleJson = json['vehicle'];
  if (vehicleJson is Map<String, dynamic>) {
    final vehicle = Vehicle.fromJson({
      ...vehicleJson,
      'plateNumber':
          _firstMapValue(vehicleJson, const [
            'plateNumber',
            'plate',
            'registrationNumber',
          ]) ??
          _firstMapValue(json, const [
            'plateNumber',
            'vehiclePlateNumber',
            'registrationNumber',
          ]),
    });
    return vehicle.copyWith(
      autoPayEnabled: jsonBool(
        _firstMapValue(json, const ['autoPayEnabled', 'autoPay']),
        vehicle.autoPayEnabled,
      ),
    );
  }

  return Vehicle(
    id: jsonString(_firstMapValue(json, const ['vehicleId', 'vehicleID'])),
    plateNumber:
        jsonString(
          _firstMapValue(json, const [
            'plateNumber',
            'vehiclePlateNumber',
            'registrationNumber',
          ]),
        ) ??
        '',
    type: Vehicle.vehicleTypeLabel(
      jsonString(_firstMapValue(json, const ['vehicleType', 'type'])),
    ),
    make: jsonString(json['make']) ?? '',
    model: jsonString(json['model']) ?? '',
    autoPayEnabled: jsonBool(
      _firstMapValue(json, const ['autoPayEnabled', 'autoPay']),
    ),
  );
}

Object? _firstMapValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}
