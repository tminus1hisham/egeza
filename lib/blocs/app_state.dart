import 'package:equatable/equatable.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';

class AppState extends Equatable {
  final String userName;
  final double walletBalance;
  final List<Vehicle> vehicles;
  final List<ParkingSession> recentSessions;
  final bool isLoading;

  const AppState({
    this.userName = 'James Mwangi',
    this.walletBalance = 2450.0,
    this.vehicles = const [],
    this.recentSessions = const [],
    this.isLoading = false,
  });

  AppState copyWith({
    String? userName,
    double? walletBalance,
    List<Vehicle>? vehicles,
    List<ParkingSession>? recentSessions,
    bool? isLoading,
  }) {
    return AppState(
      userName: userName ?? this.userName,
      walletBalance: walletBalance ?? this.walletBalance,
      vehicles: vehicles ?? this.vehicles,
      recentSessions: recentSessions ?? this.recentSessions,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [userName, walletBalance, vehicles, recentSessions, isLoading];
}
