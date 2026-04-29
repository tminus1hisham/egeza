import 'vehicle.dart';

class ParkingSession {
  final String id;
  final String locationName;
  final DateTime startTime;
  final DateTime? endTime;
  final double cost;
  final Vehicle vehicle;
  final bool isActive;

  const ParkingSession({
    required this.id,
    required this.locationName,
    required this.startTime,
    this.endTime,
    required this.cost,
    required this.vehicle,
    required this.isActive,
  });
}
