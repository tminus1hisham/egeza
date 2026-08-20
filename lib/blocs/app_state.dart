import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import '../models/api_models.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';
import '../models/session_promo_hold.dart';

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

  /// Promo codes applied to sessions, keyed by session id. A hold only counts
  /// while it is unexpired — see [livePromoHold].
  final Map<String, SessionPromoHold> promoHolds;

  /// A promo code is being redeemed right now.
  final bool isApplyingPromo;
  final PaymentStatusSnapshot? activePayment;
  final bool isLoading;
  final bool sessionExpired;
  final String? errorMessage;
  final String? statusMessage;
  final ThemeMode themeMode;

  /// Debug-only override of the driver/manager view mode. Null follows the
  /// account's real role; true or false forces that side of the app.
  final bool? debugManagerMode;

  /// Debug-only: fill the manager view with generated figures instead of
  /// calling the API. Affects that screen alone — no driver-facing screen ever
  /// shows invented data.
  final bool debugSampleData;

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
    this.promoHolds = const {},
    this.isApplyingPromo = false,
    this.activePayment,
    this.isLoading = false,
    this.sessionExpired = false,
    this.errorMessage,
    this.statusMessage,
    this.themeMode = ThemeMode.system,
    this.debugManagerMode,
    this.debugSampleData = false,
  });

  bool get isAuthenticated => authToken != null && authToken!.isNotEmpty;

  String get normalizedUserRole => userRole.trim().toUpperCase();

  /// Whether the signed-in account's own role puts it on the manager side.
  bool get hasManagerRole => const {
        'MANAGER',
        'ADMIN',
        'CLIENT',
      }.contains(normalizedUserRole);

  /// Whether to offer the manager view. Only a gate on the entry point — the
  /// `/manager/*` endpoints are the real authority on which sites, if any, this
  /// account may see, and the screen says so itself when there are none.
  ///
  /// [debugManagerMode] wins when set, so a debug build can preview either side
  /// without changing the account's role in the backend.
  bool get isManager => debugManagerMode ?? hasManagerRole;

  /// True when the mode on screen is not the one the account's role implies.
  bool get isDebugModeOverridden =>
      debugManagerMode != null && debugManagerMode != hasManagerRole;

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

  /// The unexpired promo held against [sessionId], if any.
  ///
  /// A promo that covered the bill outright is spent on application, so it is
  /// never returned here.
  SessionPromoHold? livePromoHold(String sessionId, {DateTime? now}) {
    final hold = promoHolds[sessionId];
    if (hold == null) return null;
    return hold.isLiveAt(now ?? DateTime.now()) ? hold : null;
  }

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
    Map<String, SessionPromoHold>? promoHolds,
    bool? isApplyingPromo,
    PaymentStatusSnapshot? activePayment,
    bool? isLoading,
    bool? sessionExpired,
    String? errorMessage,
    String? statusMessage,
    ThemeMode? themeMode,
    bool? debugManagerMode,
    bool? debugSampleData,
    // Null is a meaningful value for the override — "follow the account role" —
    // so clearing it needs its own flag rather than passing null.
    bool clearDebugManagerMode = false,
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
      promoHolds: promoHolds ?? this.promoHolds,
      isApplyingPromo: isApplyingPromo ?? this.isApplyingPromo,
      activePayment:
          clearActivePayment ? null : activePayment ?? this.activePayment,
      isLoading: isLoading ?? this.isLoading,
      sessionExpired: sessionExpired ?? this.sessionExpired,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
      statusMessage: clearMessages ? null : statusMessage ?? this.statusMessage,
      themeMode: themeMode ?? this.themeMode,
      debugManagerMode: clearDebugManagerMode
          ? null
          : debugManagerMode ?? this.debugManagerMode,
      debugSampleData: debugSampleData ?? this.debugSampleData,
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
        promoHolds,
        isApplyingPromo,
        activePayment,
        isLoading,
        sessionExpired,
        errorMessage,
        statusMessage,
        themeMode,
        debugManagerMode,
        debugSampleData,
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
