import 'vehicle.dart';
import 'api_models.dart';

class ParkingSession {
  final String id;
  final String locationName;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? currentTime;
  final double cost;
  final double amountPaid;
  final int? durationMinutes;
  final int gracePeriodMinutes;
  final int ratePerHour;
  final int billableHours;
  final String status;
  final bool autoPayEnabled;
  final double? walletBalance;
  final bool willAutoDeduct;
  final double discountAmount;
  final Vehicle vehicle;
  final bool isActive;

  const ParkingSession({
    required this.id,
    required this.locationName,
    required this.startTime,
    this.endTime,
    this.currentTime,
    required this.cost,
    this.amountPaid = 0,
    this.durationMinutes,
    this.gracePeriodMinutes = 3,
    this.ratePerHour = 5,
    this.billableHours = 0,
    this.status = 'ACTIVE',
    this.autoPayEnabled = false,
    this.walletBalance,
    this.willAutoDeduct = false,
    this.discountAmount = 0,
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
    final startTime = jsonDateTime(_firstJsonValue(json, const [
          'entryTime',
          'startTime',
          'startedAt',
          'createdAt',
        ])) ??
        DateTime.now();
    final currentTime = jsonDateTime(_firstJsonValue(json, const [
      'currentTime',
      'calculatedAt',
      'serverTime',
    ]));
    final durationMinutes = _optionalInt(_firstJsonValue(json, const [
          'durationMinutes',
          'durationInMinutes',
        ])) ??
        (currentTime?.difference(startTime).inMinutes);

    // A session with amountPaid > 0 has been settled — treat it as completed
    // regardless of what status the API returns (handles stale PAYMENT_PENDING).
    final effectiveStatus = amountPaid > 0 && status != 'COMPLETED'
        ? 'COMPLETED'
        : status;
    final isActive = amountPaid > 0 ? false : _isActiveSession(json, effectiveStatus);

    return ParkingSession(
      id: jsonString(_firstJsonValue(json, const [
            'sessionId',
            'id',
            'parkingSessionId',
          ])) ??
          '',
      locationName: _locationName(json),
      startTime: startTime,
      endTime: endTime,
      currentTime: currentTime,
      cost: amountDue > 0 ? amountDue : amountPaid,
      amountPaid: amountPaid,
      durationMinutes: durationMinutes,
      gracePeriodMinutes: jsonInt(json['gracePeriodMinutes'], 3),
      ratePerHour: jsonInt(json['ratePerHour'], 5),
      billableHours: jsonInt(json['billableHours']),
      status: effectiveStatus,
      autoPayEnabled: jsonBool(
        _firstJsonValue(json, const ['autoPayEnabled', 'autoPay']),
        vehicle.autoPayEnabled,
      ),
      walletBalance: json['walletBalance'] == null
          ? null
          : jsonDouble(json['walletBalance']),
      willAutoDeduct: jsonBool(json['willAutoDeduct']),
      discountAmount: jsonDouble(json['discountAmount']),
      vehicle: vehicle,
      isActive: isActive,
    );
  }

  /// Nothing is owed on this session any more — the fee was collected, or the
  /// session closed with nothing to collect.
  ///
  /// This is the question every "Paid" label wants answered, and it is *not*
  /// `!isActive`: the gate leaves an exited-but-unpaid session as
  /// `EXIT_PENDING_PAYMENT` with a null `amountPaid`, which is neither active
  /// nor settled.
  bool get isSettled =>
      amountPaid > 0 || _settledStatuses.contains(status.toUpperCase());

  /// The car has left but the fee is still outstanding.
  bool get isAwaitingPayment => !isActive && !isSettled;

  static const _settledStatuses = {'COMPLETED', 'CANCELLED', 'CANCELED'};

  ParkingSession copyWith({
    String? id,
    String? locationName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? currentTime,
    double? cost,
    double? amountPaid,
    int? durationMinutes,
    int? gracePeriodMinutes,
    int? ratePerHour,
    int? billableHours,
    String? status,
    bool? autoPayEnabled,
    double? walletBalance,
    bool? willAutoDeduct,
    double? discountAmount,
    Vehicle? vehicle,
    bool? isActive,
  }) {
    return ParkingSession(
      id: id ?? this.id,
      locationName: locationName ?? this.locationName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      currentTime: currentTime ?? this.currentTime,
      cost: cost ?? this.cost,
      amountPaid: amountPaid ?? this.amountPaid,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      gracePeriodMinutes: gracePeriodMinutes ?? this.gracePeriodMinutes,
      ratePerHour: ratePerHour ?? this.ratePerHour,
      billableHours: billableHours ?? this.billableHours,
      status: status ?? this.status,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
      walletBalance: walletBalance ?? this.walletBalance,
      willAutoDeduct: willAutoDeduct ?? this.willAutoDeduct,
      discountAmount: discountAmount ?? this.discountAmount,
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
