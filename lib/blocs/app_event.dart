import 'package:equatable/equatable.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends AppEvent {}

class AddVehicle extends AppEvent {
  final String plateNumber;
  final String type;
  final String make;
  final String model;

  const AddVehicle({
    required this.plateNumber,
    required this.type,
    required this.make,
    required this.model,
  });

  @override
  List<Object?> get props => [plateNumber, type, make, model];
}

class TopUpWallet extends AppEvent {
  final double amount;

  const TopUpWallet(this.amount);

  @override
  List<Object?> get props => [amount];
}

class EndParkingSession extends AppEvent {
  final String sessionId;

  const EndParkingSession(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}
