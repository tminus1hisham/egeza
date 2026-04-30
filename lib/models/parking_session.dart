import 'vehicle.dart';
import 'api_models.dart';

class ParkingSession {
  final String id;
  final String locationName;
  final DateTime startTime;
  final DateTime? endTime;
  final double cost;
  final double amountPaid;
  final int? durationMinutes;
  final String status;
  final bool autoPayEnabled;
  final double? walletBalance;
  final bool willAutoDeduct;
  final Vehicle vehicle;
  final bool isActive;

  const ParkingSession({
    required this.id,
    required this.locationName,
    required this.startTime,
    this.endTime,
    required this.cost,
    this.amountPaid = 0,
    this.durationMinutes,
    this.status = 'ACTIVE',
    this.autoPayEnabled = false,
    this.walletBalance,
    this.willAutoDeduct = false,
    required this.vehicle,
    required this.isActive,
  });

  factory ParkingSession.fromJson(Map<String, dynamic> json) {
    final status = jsonString(json['status']) ?? 'ACTIVE';
    final amountDue = jsonDouble(json['amountDue']);
    final amountPaid = jsonDouble(json['amountPaid']);

    return ParkingSession(
      id: jsonString(json['sessionId']) ?? jsonString(json['id']) ?? '',
      locationName: jsonString(json['location']) ?? 'Parking Location',
      startTime: jsonDateTime(json['entryTime']) ?? DateTime.now(),
      endTime: jsonDateTime(json['exitTime']),
      cost: amountDue > 0 ? amountDue : amountPaid,
      amountPaid: amountPaid,
      durationMinutes: json['durationMinutes'] == null
          ? null
          : jsonInt(json['durationMinutes']),
      status: status,
      autoPayEnabled: jsonBool(json['autoPayEnabled']),
      walletBalance: json['walletBalance'] == null
          ? null
          : jsonDouble(json['walletBalance']),
      willAutoDeduct: jsonBool(json['willAutoDeduct']),
      vehicle: vehicleFromParkingSessionJson(json),
      isActive: status == 'ACTIVE' || status == 'PAYMENT_PENDING',
    );
  }

  ParkingSession copyWith({
    String? id,
    String? locationName,
    DateTime? startTime,
    DateTime? endTime,
    double? cost,
    double? amountPaid,
    int? durationMinutes,
    String? status,
    bool? autoPayEnabled,
    double? walletBalance,
    bool? willAutoDeduct,
    Vehicle? vehicle,
    bool? isActive,
  }) {
    return ParkingSession(
      id: id ?? this.id,
      locationName: locationName ?? this.locationName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      cost: cost ?? this.cost,
      amountPaid: amountPaid ?? this.amountPaid,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
      walletBalance: walletBalance ?? this.walletBalance,
      willAutoDeduct: willAutoDeduct ?? this.willAutoDeduct,
      vehicle: vehicle ?? this.vehicle,
      isActive: isActive ?? this.isActive,
    );
  }
}
