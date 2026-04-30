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
    final endTime = jsonDateTime(_firstJsonValue(json, const [
      'exitTime',
      'endTime',
      'endedAt',
      'exitedAt',
    ]));
    final rawStatus = jsonString(_firstJsonValue(json, const [
      'status',
      'sessionStatus',
      'state',
    ]));
    final status = (rawStatus ?? (endTime == null ? 'ACTIVE' : 'COMPLETED'))
        .toUpperCase();
    final amountDue = jsonDouble(_firstJsonValue(json, const [
      'amountDue',
      'cost',
      'amount',
      'fee',
      'total',
      'totalAmount',
    ]));
    final amountPaid = jsonDouble(_firstJsonValue(json, const [
      'amountPaid',
      'paidAmount',
    ]));
    final vehicle = vehicleFromParkingSessionJson(json);

    return ParkingSession(
      id: jsonString(_firstJsonValue(json, const [
            'sessionId',
            'id',
            'parkingSessionId',
          ])) ??
          '',
      locationName: _locationName(json),
      startTime: jsonDateTime(_firstJsonValue(json, const [
            'entryTime',
            'startTime',
            'startedAt',
            'createdAt',
          ])) ??
          DateTime.now(),
      endTime: endTime,
      cost: amountDue > 0 ? amountDue : amountPaid,
      amountPaid: amountPaid,
      durationMinutes: _optionalInt(_firstJsonValue(json, const [
        'durationMinutes',
        'durationInMinutes',
      ])),
      status: status,
      autoPayEnabled: jsonBool(
        _firstJsonValue(json, const ['autoPayEnabled', 'autoPay']),
        vehicle.autoPayEnabled,
      ),
      walletBalance: json['walletBalance'] == null
          ? null
          : jsonDouble(json['walletBalance']),
      willAutoDeduct: jsonBool(json['willAutoDeduct']),
      vehicle: vehicle,
      isActive: _isActiveSession(json, status),
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

Object? _firstJsonValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

int? _optionalInt(Object? value) {
  if (value == null) return null;
  return jsonInt(value);
}

String _locationName(Map<String, dynamic> json) {
  final direct = jsonString(_firstJsonValue(json, const [
    'locationName',
    'parkingLocationName',
    'siteName',
  ]));
  if (direct != null) return direct;

  final location = _firstJsonValue(json, const [
    'location',
    'parkingLocation',
  ]);
  if (location is Map<String, dynamic>) {
    return jsonString(_firstJsonValue(location, const [
          'name',
          'locationName',
          'address',
        ])) ??
        'Parking Location';
  }

  return jsonString(location) ?? 'Parking Location';
}

bool _isActiveSession(Map<String, dynamic> json, String status) {
  final explicit = _firstJsonValue(json, const ['isActive', 'active']);
  if (explicit != null) return jsonBool(explicit);

  const activeStatuses = {
    'ACTIVE',
    'PAYMENT_PENDING',
    'UNPAID',
    'OPEN',
    'IN_PROGRESS',
  };
  return activeStatuses.contains(status);
}
