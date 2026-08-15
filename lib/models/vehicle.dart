class Vehicle {
  final String? id;
  final String plateNumber;
  final String type;
  final String make;
  final String model;
  final bool autoPayEnabled;

  const Vehicle({
    this.id,
    required this.plateNumber,
    required this.type,
    required this.make,
    required this.model,
    this.autoPayEnabled = false,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final apiType = json['vehicleType']?.toString();

    return Vehicle(
      id: json['id']?.toString(),
      plateNumber: json['plateNumber']?.toString() ?? '',
      type: vehicleTypeLabel(apiType),
      make: json['make']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      autoPayEnabled: json['autoPayEnabled'] == true,
    );
  }

  Vehicle copyWith({
    String? id,
    String? plateNumber,
    String? type,
    String? make,
    String? model,
    bool? autoPayEnabled,
  }) {
    return Vehicle(
      id: id ?? this.id,
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      make: make ?? this.make,
      model: model ?? this.model,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'plateNumber': plateNumber,
      'vehicleType': apiVehicleType,
      'make': make,
      'model': model,
    };
  }

  String get apiVehicleType => vehicleTypeCode(type);

  /// Canonical form used to compare plates coming from different sources
  /// (registered vehicles, ANPR sessions, manual entry). Case- and
  /// punctuation-insensitive: 'kda-123a', 'KDA 123A' and 'KDA123A' all match.
  static String plateKey(String plateNumber) =>
      plateNumber.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toUpperCase();

  static String vehicleTypeCode(String value) {
    final normalized = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '_');

    if (normalized.contains('SUV') || normalized.contains('4X4')) {
      return 'SUV_4X4';
    }
    if (normalized.contains('HATCH')) return 'HATCHBACK';
    if (normalized.contains('PICKUP')) return 'PICKUP_TRUCK';
    if (normalized.contains('VAN') || normalized.contains('MINIBUS')) {
      return 'VAN_MINIBUS';
    }
    if (normalized.contains('MOTOR')) return 'MOTORCYCLE';
    return 'SALOON';
  }

  static String vehicleTypeLabel(String? value) {
    switch (value) {
      case 'SUV_4X4':
        return 'SUV / 4x4';
      case 'HATCHBACK':
        return 'Hatchback';
      case 'PICKUP_TRUCK':
        return 'Pickup Truck';
      case 'VAN_MINIBUS':
        return 'Van / Minibus';
      case 'MOTORCYCLE':
        return 'Motorcycle';
      case 'SALOON':
        return 'Saloon';
      default:
        return value ?? 'Saloon';
    }
  }
}
