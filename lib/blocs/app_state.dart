import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../models/api_models.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';

class AppState extends Equatable {
  final String userName;
  final String? phoneNumber;
  final String? email;
  final String userRole;
  final String? authToken;
  final bool requiresVehicleSetup;
  final double walletBalance;
  final List<Vehicle> vehicles;
  final List<ParkingSession> recentSessions;
  final List<WalletTransaction> walletTransactions;
  final List<ParkingLocation> locations;
  final List<TenantProfile> tenantProfiles;
  final List<TenancyRequest> tenancyRequests;
  final ParkingSession? selectedSession;
  final bool isWaitingForPayment;
  final PaymentStatusSnapshot? activePayment;
  final bool isLoading;
  final bool sessionExpired;
  final String? errorMessage;
  final String? statusMessage;
  final ThemeMode themeMode;

  const AppState({
    this.userName = '',
    this.phoneNumber,
    this.email,
    this.userRole = 'USER',
    this.authToken,
    this.requiresVehicleSetup = false,
    this.walletBalance = 0.0,
    this.vehicles = const [],
    this.recentSessions = const [],
    this.walletTransactions = const [],
    this.locations = const [],
    this.tenantProfiles = const [],
    this.tenancyRequests = const [],
    this.selectedSession,
    this.isWaitingForPayment = false,
    this.activePayment,
    this.isLoading = false,
    this.sessionExpired = false,
    this.errorMessage,
    this.statusMessage,
    this.themeMode = ThemeMode.system,
  });

  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  String get normalizedUserRole => userRole.trim().toUpperCase();

  List<TenantProfile> get visibleTenantProfiles => tenantProfiles
      .where(_tenantProfileGrantsAccess)
      .toList(growable: false);

  bool get hasTenantProfiles => visibleTenantProfiles.isNotEmpty;

  bool get isTenant =>
      normalizedUserRole == 'TENANT' || visibleTenantProfiles.isNotEmpty;

  bool get hasActiveTenancy =>
      visibleTenantProfiles.any((profile) => profile.isActivePaid);

  bool get hasPayableTenancy =>
      visibleTenantProfiles.any((profile) => profile.canPay);

  bool get hasTenancyRequests => tenancyRequests.isNotEmpty;

  bool get shouldShowTenancy => isTenant || hasTenancyRequests;

  int get activeTenantProfileCount =>
      visibleTenantProfiles.where((profile) => profile.isActivePaid).length;

  int get payableTenantProfileCount =>
      visibleTenantProfiles.where((profile) => profile.canPay).length;

  AppState copyWith({
    String? userName,
    String? phoneNumber,
    String? email,
    String? userRole,
    String? authToken,
    bool? requiresVehicleSetup,
    double? walletBalance,
    List<Vehicle>? vehicles,
    List<ParkingSession>? recentSessions,
    List<WalletTransaction>? walletTransactions,
    List<ParkingLocation>? locations,
    List<TenantProfile>? tenantProfiles,
    List<TenancyRequest>? tenancyRequests,
    ParkingSession? selectedSession,
    bool? isWaitingForPayment,
    PaymentStatusSnapshot? activePayment,
    bool? isLoading,
    bool? sessionExpired,
    String? errorMessage,
    String? statusMessage,
    ThemeMode? themeMode,
    bool clearAuthToken = false,
    bool clearSelectedSession = false,
    bool clearActivePayment = false,
    bool clearMessages = false,
  }) {
    return AppState(
      userName: userName ?? this.userName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      userRole: userRole ?? this.userRole,
      authToken: clearAuthToken ? null : (authToken ?? this.authToken),
      requiresVehicleSetup:
          requiresVehicleSetup ?? this.requiresVehicleSetup,
      walletBalance: walletBalance ?? this.walletBalance,
      vehicles: vehicles ?? this.vehicles,
      recentSessions: recentSessions ?? this.recentSessions,
      walletTransactions: walletTransactions ?? this.walletTransactions,
      locations: locations ?? this.locations,
      tenantProfiles: tenantProfiles ?? this.tenantProfiles,
      tenancyRequests: tenancyRequests ?? this.tenancyRequests,
      selectedSession:
          clearSelectedSession ? null : selectedSession ?? this.selectedSession,
      isWaitingForPayment: isWaitingForPayment ?? this.isWaitingForPayment,
      activePayment:
          clearActivePayment ? null : activePayment ?? this.activePayment,
      isLoading: isLoading ?? this.isLoading,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      statusMessage: clearMessages ? null : statusMessage ?? this.statusMessage,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  @override
  List<Object?> get props => [
        userName,
        phoneNumber,
        email,
        userRole,
        authToken,
        requiresVehicleSetup,
        walletBalance,
        vehicles,
        recentSessions,
        walletTransactions,
        locations,
        tenantProfiles,
        tenancyRequests,
        selectedSession,
        isWaitingForPayment,
        activePayment,
        isLoading,
        sessionExpired,
        errorMessage,
        statusMessage,
        themeMode,
      ];
}

bool _tenantProfileGrantsAccess(TenantProfile profile) {
  const blockedStatuses = {
    'REJECTED',
    'DECLINED',
    'CANCELLED',
    'CANCELED',
  };

  return profile.id.isNotEmpty && !blockedStatuses.contains(profile.status);
}
