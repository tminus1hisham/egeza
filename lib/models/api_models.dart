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
      token: jsonString(json['token']) ??
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
      fullName: jsonString(json['fullName']) ?? 'ParkIQ User',
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
    dev.log('MpesaResponse.fromJson: keys=${json.keys.toList()} values=${json.values.toList()}', name: 'ApiModels');
    final result = MpesaResponse(
      paymentId: jsonString(json['paymentId']) ?? jsonString(json['id']),
      merchantRequestId: jsonString(json['merchantRequestId']) ??
          jsonString(json['MerchantRequestID']),
      checkoutRequestId: jsonString(json['checkoutRequestId']) ??
          jsonString(json['CheckoutRequestID']),
      responseCode: jsonString(json['responseCode']) ??
          jsonString(json['ResponseCode']),
      responseDescription: jsonString(json['responseDescription']) ??
          jsonString(json['ResponseDescription']),
      customerMessage: jsonString(json['customerMessage']) ??
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
      checkoutRequestId: jsonString(json['checkoutRequestId']) ??
          jsonString(json['CheckoutRequestID']),
      sessionId: jsonString(json['sessionId']) ??
          jsonString(json['parkingSessionId']),
      status: (jsonString(json['status']) ??
              jsonString(json['paymentStatus']) ??
              jsonString(json['ResultDesc']) ??
              'PENDING')
          .toUpperCase(),
      message: jsonString(json['message']) ??
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

class QrCodeResponse {
  final String? locationId;
  final String? rateId;
  final String? content;
  final String? imageBase64;
  final String? mimeType;
  final DateTime? expiresAt;

  const QrCodeResponse({
    this.locationId,
    this.rateId,
    this.content,
    this.imageBase64,
    this.mimeType,
    this.expiresAt,
  });

  factory QrCodeResponse.fromJson(Map<String, dynamic> json) {
    return QrCodeResponse(
      locationId: jsonString(json['locationId']),
      rateId: jsonString(json['rateId']),
      content: jsonString(json['content']),
      imageBase64: jsonString(json['imageBase64']),
      mimeType: jsonString(json['mimeType']),
      expiresAt: jsonDateTime(json['expiresAt']),
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
    if (address != null) 'address': address,
    if (ratePerHour != null) 'ratePerHour': ratePerHour,
    if (maxCapacity != null) 'maxCapacity': maxCapacity,
    if (gracePeriodMinutes != null) 'gracePeriodMinutes': gracePeriodMinutes,
    if (maxDailyCharge != null) 'maxDailyCharge': maxDailyCharge,
  };
}

Vehicle vehicleFromParkingSessionJson(Map<String, dynamic> json) {
  final vehicleJson = json['vehicle'];
  if (vehicleJson is Map<String, dynamic>) {
    final vehicle = Vehicle.fromJson({
      ...vehicleJson,
      'plateNumber': _firstMapValue(vehicleJson, const [
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
    plateNumber: jsonString(_firstMapValue(json, const [
          'plateNumber',
          'vehiclePlateNumber',
          'registrationNumber',
        ])) ??
        '',
    type: Vehicle.vehicleTypeLabel(jsonString(_firstMapValue(json, const [
      'vehicleType',
      'type',
    ]))),
    make: jsonString(json['make']) ?? '',
    model: jsonString(json['model']) ?? '',
    autoPayEnabled:
        jsonBool(_firstMapValue(json, const ['autoPayEnabled', 'autoPay'])),
  );
}

Object? _firstMapValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}
