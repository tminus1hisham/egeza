class Vehicle {
  final String plateNumber;
  final String type;
  final String make;
  final String model;
  final bool autoPayEnabled;

  const Vehicle({
    required this.plateNumber,
    required this.type,
    required this.make,
    required this.model,
    this.autoPayEnabled = false,
  });

  Vehicle copyWith({
    String? plateNumber,
    String? type,
    String? make,
    String? model,
    bool? autoPayEnabled,
  }) {
    return Vehicle(
      plateNumber: plateNumber ?? this.plateNumber,
      type: type ?? this.type,
      make: make ?? this.make,
      model: model ?? this.model,
      autoPayEnabled: autoPayEnabled ?? this.autoPayEnabled,
    );
  }
}
