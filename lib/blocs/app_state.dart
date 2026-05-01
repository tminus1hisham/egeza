import 'package:equatable/equatable.dart';
import '../models/api_models.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';

class AppState extends Equatable {
  final String userName;
  final String? phoneNumber;
  final String? email;
  final String? authToken;
  final bool requiresVehicleSetup;
  final double walletBalance;
  final List<Vehicle> vehicles;
  final List<ParkingSession> recentSessions;
  final List<WalletTransaction> walletTransactions;
  final List<ParkingLocation> locations;
  final ParkingSession? selectedSession;
  final bool isWaitingForPayment;
  final PaymentStatusSnapshot? activePayment;
  final bool isLoading;
  final String? errorMessage;
  final String? statusMessage;

  const AppState({
    this.userName = 'James Mwangi',
    this.phoneNumber,
    this.email,
    this.authToken,
    this.requiresVehicleSetup = false,
    this.walletBalance = 2450.0,
    this.vehicles = const [],
    this.recentSessions = const [],
    this.walletTransactions = const [],
    this.locations = const [],
    this.selectedSession,
    this.isWaitingForPayment = false,
    this.activePayment,
    this.isLoading = false,
    this.errorMessage,
    this.statusMessage,
  });

  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  AppState copyWith({
    String? userName,
    String? phoneNumber,
    String? email,
    String? authToken,
    bool? requiresVehicleSetup,
    double? walletBalance,
    List<Vehicle>? vehicles,
    List<ParkingSession>? recentSessions,
    List<WalletTransaction>? walletTransactions,
    List<ParkingLocation>? locations,
    ParkingSession? selectedSession,
    bool? isWaitingForPayment,
    PaymentStatusSnapshot? activePayment,
    bool? isLoading,
    String? errorMessage,
    String? statusMessage,
    bool clearSelectedSession = false,
    bool clearActivePayment = false,
    bool clearMessages = false,
  }) {
    return AppState(
      userName: userName ?? this.userName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      authToken: authToken ?? this.authToken,
      requiresVehicleSetup:
          requiresVehicleSetup ?? this.requiresVehicleSetup,
      walletBalance: walletBalance ?? this.walletBalance,
      vehicles: vehicles ?? this.vehicles,
      recentSessions: recentSessions ?? this.recentSessions,
      walletTransactions: walletTransactions ?? this.walletTransactions,
      locations: locations ?? this.locations,
      selectedSession:
          clearSelectedSession ? null : selectedSession ?? this.selectedSession,
      isWaitingForPayment: isWaitingForPayment ?? this.isWaitingForPayment,
      activePayment:
          clearActivePayment ? null : activePayment ?? this.activePayment,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      statusMessage: clearMessages ? null : statusMessage ?? this.statusMessage,
    );
  }

  @override
  List<Object?> get props => [
        userName,
        phoneNumber,
        email,
        authToken,
        requiresVehicleSetup,
        walletBalance,
        vehicles,
        recentSessions,
        walletTransactions,
        locations,
        selectedSession,
        isWaitingForPayment,
        activePayment,
        isLoading,
        errorMessage,
        statusMessage,
      ];
}
