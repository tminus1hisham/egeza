import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import '../../models/api_models.dart';
import '../../models/parking_session.dart';
import '../../models/vehicle.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Object? details;

  const ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    if (statusCode == null) return message;
    return 'HTTP $statusCode: $message';
  }
}

class ParkingIqApi {
  // static const defaultBaseUrl = 'https://api.egesha.net/api/v1';
  static const defaultBaseUrl = 'https://parking-api.transfa.org/api/v1';

  /// Without this a request on a weak signal hangs until the OS gives up
  /// (60s+). ErrorHandler already maps TimeoutException to a friendly message.
  static const _timeout = Duration(seconds: 25);

  final http.Client _client;
  final Uri _baseUri;
  final bool _debug;
  String? _token;

  ParkingIqApi({
    http.Client? client,
    String baseUrl = defaultBaseUrl,
    String? token,
    bool? debug,
  })  : _client = client ?? http.Client(),
        _baseUri = Uri.parse(baseUrl),
        _token = token,
        _debug = debug ?? kDebugMode;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  String? get token => _token;

  void setToken(String? token) {
    _token = token == null || token.isEmpty ? null : token;
  }

  Future<Map<String, dynamic>> sendOtp(String phoneNumber) {
    return _request(
      'POST',
      '/auth/send-otp',
      authenticated: false,
      body: {'phoneNumber': phoneNumber},
    );
  }

  Future<AuthResult?> requestLoginOtp(String phoneNumber) async {
    final response = await _request(
      'POST',
      '/auth/login',
      authenticated: false,
      body: {'phoneNumber': phoneNumber},
    );

    final auth = _authResultOrNull(response);
    if (auth != null && auth.token.isNotEmpty) {
      setToken(auth.token);
      return auth;
    }

    return null;
  }

  Future<AuthResult> signInWithOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final response = await _request(
      'POST',
      '/auth/login/verify',
      authenticated: false,
      body: {
        'phoneNumber': phoneNumber,
        'otp': otp,
      },
    );

    final verifiedAuth = _authResultOrNull(response);
    if (verifiedAuth != null && verifiedAuth.token.isNotEmpty) {
      setToken(verifiedAuth.token);
      return verifiedAuth;
    }

    // Try to pull any token-like string from the response (handles non-standard field names)
    final rawToken = _findAnyToken(response);
    if (rawToken != null && rawToken.isNotEmpty) {
      setToken(rawToken);
      return AuthResult(token: rawToken);
    }

    // API returned 200 but no token — surface the API's own message if present
    throw ApiException(
      _messageFrom(response) ?? 'Invalid or expired verification code',
    );
  }

  Future<bool> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final response = await _request(
      'POST',
      '/auth/verify-otp',
      authenticated: false,
      body: {
        'phoneNumber': phoneNumber,
        'otp': otp,
      },
    );
    final data = _dataMap(response);
    if (data == null) return false;
    return data.values.any((value) => value == true);
  }

  Future<AuthResult> register({
    required String phoneNumber,
    required String otp,
    required String fullName,
    required String idNumber,
    required String county,
    String? email,
  }) async {
    final response = await _request(
      'POST',
      '/auth/register',
      authenticated: false,
      body: {
        'phoneNumber': phoneNumber,
        'otp': otp,
        'fullName': fullName,
        'idNumber': idNumber,
        'county': county,
        if (email != null && email.isNotEmpty) 'email': email,
      },
    );
    final auth = _authResultOrNull(response);
    if (auth == null || auth.token.isEmpty) {
      throw const ApiException('Registration response did not include a token');
    }
    setToken(auth.token);
    return auth;
  }

  Future<String?> latestOtp(String phoneNumber) async {
    final response = await _request(
      'GET',
      '/auth/dev/latest-otp',
      authenticated: false,
      query: {'phoneNumber': phoneNumber},
    );
    final data = _dataMap(response);
    if (data == null || data.values.isEmpty) return null;
    return data.values.first.toString();
  }

  Future<UserProfile> me() async {
    final response = await _request('GET', '/users/me');
    return UserProfile.fromJson(_requiredDataMap(response));
  }

  Future<List<Vehicle>> listVehicles() async {
    final response = await _request('GET', '/vehicles');
    return _dataList(response).map(Vehicle.fromJson).toList();
  }

  Future<Vehicle> addVehicle({
    required String plateNumber,
    required String vehicleType,
    required String make,
    required String model,
  }) async {
    final response = await _request(
      'POST',
      '/vehicles',
      body: {
        'plateNumber': plateNumber,
        'vehicleType': Vehicle.vehicleTypeCode(vehicleType),
        'make': make,
        'model': model,
      },
    );
    return Vehicle.fromJson(_requiredDataMap(response));
  }

  Future<Vehicle> setVehicleAutoPay({
    required String vehicleId,
    required bool enabled,
  }) async {
    final response = await _request(
      'PATCH',
      '/vehicles/$vehicleId/auto-pay',
      body: {'enabled': enabled},
    );
    return Vehicle.fromJson(_requiredDataMap(response));
  }

  Future<void> deleteVehicle(String vehicleId) async {
    await _request('DELETE', '/vehicles/$vehicleId');
  }

  Future<double> walletBalance() async {
    final response = await _request('GET', '/wallet/balance');
    return jsonDouble(_requiredDataMap(response)['balance']);
  }

  Future<List<WalletTransaction>> walletTransactions() async {
    final response = await _request('GET', '/wallet/transactions');
    return _dataList(response).map(WalletTransaction.fromJson).toList();
  }

  Future<MpesaResponse> topUpWallet({
    required double amount,
    String? phoneNumber,
  }) async {
    dev.log(
      'topUpWallet: amount=${amount.toInt()} phone=$phoneNumber hasToken=$hasToken',
      name: 'ParkingIQ',
    );
    final response = await _request(
      'POST',
      '/wallet/topup',
      body: {
        'amount': amount.toInt(),
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
    dev.log('topUpWallet: raw response=$response', name: 'ParkingIQ');
    final data = _dataMap(response);
    dev.log(
      'topUpWallet: data=${data != null ? "found (data key)" : "null — falling back to top-level response"}',
      name: 'ParkingIQ',
    );
    return MpesaResponse.fromJson(data ?? response);
  }

  Future<MpesaResponse> stkPush({
    required String phoneNumber,
    required double amount,
    required String accountReference,
    String? transactionDesc,
  }) async {
    final response = await _request(
      'POST',
      '/payments/mpesa/stkpush/legacy',
      body: {
        'phoneNumber': phoneNumber,
        'amount': amount,
        'accountReference': accountReference,
        'transactionDesc': ?transactionDesc,
      },
    );
    return MpesaResponse.fromJson(_requiredObjectPayload(response));
  }

  Future<List<ParkingSession>> recentParkingSessions() async {
    final response = await _request('GET', '/parking/sessions/recent');
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  Future<List<ParkingSession>> activeParkingSessions() async {
    final response = await _request('GET', '/parking/sessions/active');
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  Future<List<ParkingSession>> parkingSessionsForPlate(
    String plateNumber,
  ) async {
    final response = await _request(
      'GET',
      '/parking/sessions/by-plate',
      query: {'plateNumber': plateNumber},
    );
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  Future<List<ParkingSession>> activeParkingSessionsForPlate(
    String plateNumber,
  ) async {
    final response = await _request(
      'GET',
      '/parking/sessions/by-plate/active',
      query: {'plateNumber': plateNumber},
    );
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  /// Instant Pay: looks up the active parking session for [plateNumber] via the
  /// public `/parking/instant-pay/session` endpoint. Returns `null` when there
  /// is no active session for the plate.
  Future<ParkingSession?> instantPaySession(String plateNumber) async {
    final response = await _request(
      'GET',
      '/parking/instant-pay/session',
      authenticated: false,
      query: {'plateNumber': plateNumber},
    );
    final data = _dataMap(response);
    if (data == null || data.isEmpty) return null;

    // The DTO exposes `amountPayable` as the net outstanding balance; surface it
    // as the session cost so the screen's `cost - amountPaid` reflects it.
    final amountPaid = jsonDouble(data['amountPaid']);
    final amountPayable = jsonDouble(data['amountPayable']);
    return ParkingSession.fromJson({
      ...data,
      'amountDue': amountPayable + amountPaid,
    });
  }

  /// Instant Pay: pays the active parking session for [plateNumber] via the
  /// public `/parking/instant-pay/pay` endpoint using an M-Pesa STK push.
  Future<MpesaResponse> instantPay({
    required String plateNumber,
    required String phoneNumber,
    String paymentMethod = 'MPESA',
  }) async {
    final response = await _request(
      'POST',
      '/parking/instant-pay/pay',
      authenticated: false,
      body: {
        'plateNumber': plateNumber,
        'phoneNumber': phoneNumber,
        'paymentMethod': paymentMethod,
      },
    );
    final payload = _requiredObjectPayload(response);
    final result = MpesaResponse.fromJson(payload);
    // The endpoint may carry the human-readable status as the API-level
    // `message` rather than `customerMessage` on the payload.
    if (result.customerMessage == null) {
      final message = _messageFrom(response);
      if (message != null && message.isNotEmpty) {
        return MpesaResponse(
          paymentId: result.paymentId,
          merchantRequestId: result.merchantRequestId,
          checkoutRequestId: result.checkoutRequestId,
          responseCode: result.responseCode,
          responseDescription: result.responseDescription,
          customerMessage: message,
          status: result.status,
        );
      }
    }
    return result;
  }

  Future<ParkingSession> findActiveParkingSession({
    required String plateNumber,
    String? location,
    String? locationId,
  }) async {
    final resolvedLocation = locationId ?? location;
    if (resolvedLocation == null || resolvedLocation.trim().isEmpty) {
      throw const ApiException('Parking location is required');
    }

    final response = await _request(
      'POST',
      '/parking/initiate',
      body: {
        'plateNumber': plateNumber,
        'locationId': resolvedLocation.trim(),
      },
    );
    return ParkingSession.fromJson(_requiredObjectPayload(response));
  }

  Future<ParkingSession> createParkingEntry({
    required String plateNumber,
    String? location,
    String? locationId,
    bool qrCodeScanned = false,
  }) async {
    final resolvedLocation = locationId ?? location;
    if (resolvedLocation == null || resolvedLocation.trim().isEmpty) {
      throw const ApiException('Parking location is required');
    }

    final response = await _request(
      'POST',
      '/parking/entry',
      body: {
        'plateNumber': plateNumber,
        'locationId': resolvedLocation.trim(),
        'qrCodeScanned': qrCodeScanned,
      },
    );
    return ParkingSession.fromJson(_requiredObjectPayload(response));
  }

  Future<ParkingSession> exitParking(String plateNumber) async {
    final response = await _request(
      'POST',
      '/parking/exit',
      query: {'plateNumber': plateNumber},
    );
    return ParkingSession.fromJson(_requiredDataMap(response));
  }

  Future<ParkingSession> payParkingSession({
    required String sessionId,
    bool useWallet = true,
    String? phoneNumber,
  }) async {
    final response = await _request(
      'POST',
      '/parking/session/$sessionId/pay',
      body: {
        'useWallet': useWallet,
        if (phoneNumber != null && phoneNumber.isNotEmpty)
          'phoneNumber': phoneNumber,
      },
    );
    return ParkingSession.fromJson(_requiredDataMap(response));
  }

  Future<ParkingSession> calculateParkingSession(String sessionId) async {
    final response = await _request(
      'GET',
      '/parking/session/$sessionId/calculate',
    );
    final data = _requiredObjectPayload(response);
    return ParkingSession.fromJson({
      ...data,
      'sessionId': data['sessionId'] ?? sessionId,
    });
  }

  Future<ParkingSession> parkingSession(String sessionId) async {
    final response = await _request('GET', '/parking/session/$sessionId');
    return ParkingSession.fromJson(_requiredObjectPayload(response));
  }

  Future<DiscountRedemption> applyDiscount({
    required String sessionId,
    required String code,
  }) async {
    final response = await _request(
      'POST',
      '/tenancy/discounts/apply',
      body: {
        'sessionId': sessionId,
        'code': code.trim(),
      },
    );
    return DiscountRedemption.fromJson(_requiredObjectPayload(response));
  }

  Future<MpesaResponse> startSessionStkPush({
    required String phoneNumber,
    required double amount,
    required String sessionId,
    required String plateNumber,
    required String location,
    String transactionDesc = 'Parking session payment',
  }) async {
    final response = await _request(
      'POST',
      '/payments/mpesa/stkpush',
      body: {
        'type': 'SESSION',
        'phoneNumber': phoneNumber,
        'amount': amount.toInt(),
        'sessionId': sessionId,
        'plateNumber': plateNumber,
        'transactionDesc': transactionDesc,
      },
    );
    return MpesaResponse.fromJson(_requiredObjectPayload(response));
  }

  Future<PaymentStatusSnapshot> paymentStatus(String paymentId) async {
    final response = await _request('GET', '/payments/$paymentId/status');
    return PaymentStatusSnapshot.fromJson(_requiredObjectPayload(response));
  }

  Future<PaymentStatusSnapshot> paymentStatusByCheckout(
    String checkoutRequestId,
  ) async {
    final response = await _request(
      'GET',
      '/payments/status/checkout/$checkoutRequestId',
    );
    return PaymentStatusSnapshot.fromJson(_requiredObjectPayload(response));
  }

  Future<PaymentStatusSnapshot> paymentStatusBySession(String sessionId) async {
    final response = await _request(
      'GET',
      '/payments/status/session/$sessionId',
    );
    return PaymentStatusSnapshot.fromJson(_requiredObjectPayload(response));
  }

  Future<QrCodeResponse> generateQrCode(
    String locationId, {
    String? gateId,
  }) async {
    final response = await _request(
      'POST',
      '/qrcode/generate',
      query: {
        'locationId': locationId,
        if (gateId != null && gateId.isNotEmpty) 'gateId': gateId,
      },
    );
    return QrCodeResponse.fromJson(_requiredDataMap(response));
  }

  Future<List<ParkingLocation>> listLocations() async {
    final response = await _request('GET', '/admin/locations');
    return _dataList(response).map(ParkingLocation.fromJson).toList();
  }

  Future<List<NearestParkingLocation>> fetchNearestLocations({
    required double latitude,
    required double longitude,
    double radius = 10,
    int limit = 20,
  }) async {
    const endpoint = '/parking/locations/nearest';
    if (_debug) {
      dev.log(
        'fetchNearestLocations: GET $endpoint '
        'lat=$latitude lng=$longitude radius=${radius}km limit=$limit',
        name: 'ParkingIQ',
      );
    }
    try {
      final response = await _request(
        'GET',
        endpoint,
        authenticated: false,
        query: {
          'latitude': latitude,
          'longitude': longitude,
          'radius': radius,
          'limit': limit,
        },
      );
      if (_debug) {
        dev.log(
          'fetchNearestLocations: raw response keys=${response.keys.toList()}',
          name: 'ParkingIQ',
        );
      }
      final locations = _dataList(response)
          .map(NearestParkingLocation.fromJson)
          .toList();
      if (_debug) {
        dev.log(
          'fetchNearestLocations: loaded ${locations.length} locations: '
          '${locations.map((l) => '${l.name} (lat=${l.latitude}, lng=${l.longitude})').join(', ')}',
          name: 'ParkingIQ',
        );
      }
      return locations;
    } catch (error, stackTrace) {
      if (_debug) {
        dev.log(
          'fetchNearestLocations: failed',
          name: 'ParkingIQ',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<List<ParkingLocation>> fetchParkingLocations() async {
    const endpoint = '/parking/locations';
    if (_debug) {
      dev.log(
        'fetchParkingLocations: loading request tenancy locations from '
        'GET $endpoint',
        name: 'ParkingIQ',
      );
    }

    try {
      final response = await _request('GET', endpoint);
      final locations = _dataList(response)
          .map(ParkingLocation.fromJson)
          .toList();

      if (_debug) {
        dev.log(
          'fetchParkingLocations: loaded ${locations.length} locations '
          'for request tenancy: '
          '${locations.map((location) => location.name).join(', ')}',
          name: 'ParkingIQ',
        );
      }

      return locations;
    } catch (error, stackTrace) {
      if (_debug) {
        dev.log(
          'fetchParkingLocations: failed to load request tenancy locations '
          'from GET $endpoint',
          name: 'ParkingIQ',
          error: error,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<TenancyPolicy> fetchTenancyPolicy(String locationId) async {
    final response = await _request(
      'GET',
      '/parking/locations/$locationId/tenancy-policy',
      authenticated: false,
    );
    return TenancyPolicy.fromJson(_requiredDataMap(response));
  }

  Future<ParkingLocation> createLocation(Map<String, dynamic> body) async {
    final response = await _request('POST', '/admin/rates', body: body);
    return ParkingLocation.fromJson(_requiredDataMap(response));
  }

  Future<ParkingLocation> updateLocation({
    required String locationId,
    required Map<String, dynamic> body,
  }) async {
    final response = await _request(
      'PUT',
      '/admin/locations/$locationId/rates',
      body: body,
    );
    return ParkingLocation.fromJson(_requiredDataMap(response));
  }

  Future<List<ParkingSession>> activeSessions() {
    return activeParkingSessions();
  }

  Future<List<ParkingSession>> adminActiveSessions() async {
    final response = await _request('GET', '/admin/sessions/active');
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  // ── Manager (location-scoped) ────────────────────────────────────────────
  //
  // A location manager sees one site, not the whole estate, so these are the
  // `/manager/*` endpoints rather than `/admin/*`. Every one of them 403s for a
  // location the signed-in user is not assigned to — which is exactly how the
  // manager view discovers which sites it may show.

  /// Every session the location has ever recorded. There is no date filter on
  /// the endpoint, so "today" is applied client-side.
  Future<List<ParkingSession>> managerLocationSessions(String locationId) async {
    final response = await _request(
      'GET',
      '/manager/locations/$locationId/sessions',
    );
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  /// Cars on the ground right now. This is the authoritative "still parked"
  /// list — do not re-derive it by filtering [managerLocationSessions].
  Future<List<ParkingSession>> managerActiveLocationSessions(
    String locationId,
  ) async {
    final response = await _request(
      'GET',
      '/manager/locations/$locationId/sessions/active',
    );
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  Future<List<PaymentTransaction>> managerLocationPayments(
    String locationId,
  ) async {
    final response = await _request(
      'GET',
      '/manager/locations/$locationId/transactions/payments',
    );
    return _dataList(response).map(PaymentTransaction.fromJson).toList();
  }

  // ── Client (owner-scoped) ────────────────────────────────────────────────
  //
  // A site OWNER is a `CLIENT`, and a client is not a location manager: every
  // `/manager/*` route 403s for them even on their own property. Their sites and
  // figures come from `/client/*` instead, which is estate-wide — one call
  // covers every location the client owns, so the site filter is applied here in
  // the app rather than by the endpoint.

  /// The locations this client owns. Unlike the manager side there is a real
  /// "list mine" endpoint here, so no probing is needed.
  Future<List<ParkingLocation>> clientLocations() async {
    final response = await _request('GET', '/client/locations');
    return _dataList(response).map(ParkingLocation.fromJson).toList();
  }

  /// Every session across the client's locations, past and present.
  Future<List<ParkingSession>> clientSessions() async {
    final response = await _request('GET', '/client/sessions');
    return _dataList(response).map(ParkingSession.fromJson).toList();
  }

  /// Every payment taken across the client's locations.
  Future<List<PaymentTransaction>> clientPayments() async {
    final response = await _request('GET', '/client/transactions/payments');
    return _dataList(response).map(PaymentTransaction.fromJson).toList();
  }

  /// The sessions that STARTED inside the window, with the report's own totals
  /// dropped: every figure on screen is recomputed locally anyway, and two
  /// sources for one number is how they end up disagreeing.
  ///
  /// Filtered on entry time, so this is the wrong call for "cars on the ground
  /// now" — one that drove in last week is still parked but starts outside any
  /// recent window. [clientSessions] stays the source for that.
  Future<List<ParkingSession>> clientSessionReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _request(
      'GET',
      '/client/reports/sessions',
      query: _reportRange(start, end),
    );
    return _nestedList(response, 'sessions')
        .map(ParkingSession.fromJson)
        .toList();
  }

  /// The payments RECEIVED inside the window, dated by when the money landed —
  /// which is the right question for a day's takings, and not the same as the
  /// sessions that started in it.
  Future<List<PaymentTransaction>> clientPaymentReport({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _request(
      'GET',
      '/client/reports/payments',
      query: _reportRange(start, end),
    );
    return _nestedList(response, 'payments')
        .map(PaymentTransaction.fromJson)
        .toList();
  }

  /// Per-site totals for the window — the only server-side split by location
  /// the client API offers; every other `/client/*` call is estate-wide.
  Future<List<LocationPerformance>> clientLocationPerformance({
    required DateTime start,
    required DateTime end,
  }) async {
    final response = await _request(
      'GET',
      '/client/reports/locations/performance',
      query: _reportRange(start, end),
    );
    return _dataList(response).map(LocationPerformance.fromJson).toList();
  }

  /// Estate-wide live counters. Not split by site beyond each location's own
  /// occupancy, so it cannot answer a per-site question on its own.
  Future<DashboardStats> clientDashboardStats() async {
    final response = await _request('GET', '/client/dashboard/stats');
    return DashboardStats.fromJson(_requiredDataMap(response));
  }

  /// The window as the reports endpoints want it: naive local timestamps, both
  /// ends inclusive. [end] is exclusive everywhere in this app, so it is pulled
  /// back a second here rather than at every call site.
  Map<String, dynamic> _reportRange(DateTime start, DateTime end) {
    return {
      'startDate': _reportStamp(start),
      'endDate': _reportStamp(end.subtract(const Duration(seconds: 1))),
    };
  }

  static String _reportStamp(DateTime moment) {
    final local = moment.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}'
        'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// A list nested one level inside `data`, as the report DTOs wrap theirs.
  List<Map<String, dynamic>> _nestedList(
    Map<String, dynamic> response,
    String key,
  ) {
    final rows = _requiredDataMap(response)[key];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map<String, dynamic>) row,
    ];
  }

  Future<DashboardStats> dashboardStats() async {
    final response = await _request('GET', '/admin/dashboard/stats');
    return DashboardStats.fromJson(_requiredDataMap(response));
  }

  Future<RevenueReport> revenueReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _request(
      'GET',
      '/admin/reports/revenue',
      query: {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      },
    );
    return RevenueReport.fromJson(_requiredDataMap(response));
  }

  Future<OccupancyReport> occupancyReport() async {
    final response = await _request('GET', '/admin/reports/occupancy');
    return OccupancyReport.fromJson(_requiredDataMap(response));
  }

  Future<TenancyRequest> submitTenancyRequest({
    required String locationId,
    required String tenantName,
    required String plateNumber,
    required String message,
  }) async {
    final response = await _request(
      'POST',
      '/tenancy/requests',
      body: {
        'locationId': locationId,
        'tenantName': tenantName,
        'plateNumber': plateNumber,
        'message': message,
      },
    );
    return TenancyRequest.fromJson(_requiredDataMap(response));
  }

  Future<List<TenancyRequest>> fetchTenancyRequests() async {
    final response = await _request('GET', '/tenancy/requests');
    return _dataList(response).map(TenancyRequest.fromJson).toList();
  }

  Future<List<TenantProfile>> fetchMyTenantProfiles() async {
    final response = await _request('GET', '/tenancy/my-profiles');
    final items = _dataList(response);
    if (_debug) {
      // The generic response log truncates at 200 chars, which cuts off the
      // vehicle fields. Print the shape of each tenant so a profile that shows
      // no plates can be traced to the payload rather than the parser.
      for (final item in items) {
        dev.log(
          'my-profiles tenant=${item['id']} keys=${item.keys.toList()} '
          'plateNumbers=${jsonEncode(item['plateNumbers'])} '
          'vehicles=${jsonEncode(item['vehicles'])}',
          name: 'ParkingIQ',
        );
      }
    }
    return items.map(TenantProfile.fromJson).toList();
  }

  Future<List<TenantSubscription>> fetchTenantSubscriptions(
    String tenantId,
  ) async {
    final response = await _request(
      'GET',
      '/tenancy/tenants/$tenantId/subscriptions',
    );
    return _dataList(response).map(TenantSubscription.fromJson).toList();
  }

  Future<MpesaResponse> payTenantSubscription({
    required String tenantId,
    required String phoneNumber,
  }) async {
    final response = await _request(
      'POST',
      '/tenancy/tenants/$tenantId/subscriptions/pay',
      body: {'phoneNumber': phoneNumber},
    );
    return MpesaResponse.fromJson(_requiredObjectPayload(response));
  }

  Future<TenantPaymentStatus> tenantPaymentStatus(String tenantId) async {
    final response = await _request(
      'GET',
      '/tenancy/tenants/$tenantId/payment-status',
    );
    return TenantPaymentStatus.fromJson(_requiredObjectPayload(response));
  }

  Future<Map<String, dynamic>> barrierCommand({
    required String gateId,
    required String command,
  }) async {
    final response = await _request(
      'POST',
      '/admin/gates/$gateId/barrier',
      query: {'command': command},
    );
    return _requiredDataMap(response);
  }

  Future<Map<String, dynamic>> cameraEntryWebhook({
    required String plateNumber,
    required String locationId,
    bool qrCodeScanned = false,
  }) {
    return _request(
      'POST',
      '/webhooks/camera/entry',
      authenticated: false,
      body: {
        'plateNumber': plateNumber,
        'locationId': locationId,
        'qrCodeScanned': qrCodeScanned,
      },
    );
  }

  Future<Map<String, dynamic>> cameraExitWebhook(String plateNumber) {
    return _request(
      'POST',
      '/webhooks/camera/exit',
      authenticated: false,
      query: {'plateNumber': plateNumber},
    );
  }

  Future<Map<String, dynamic>> barrierStatusWebhook(
    Map<String, dynamic> payload,
  ) {
    return _request(
      'POST',
      '/webhooks/barrier/status',
      authenticated: false,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && hasToken) 'Authorization': 'Bearer $_token',
    };
    final encodedBody = body == null ? null : jsonEncode(body);

    if (_debug) {
      final q = query?.isNotEmpty == true ? ' ?${query!.keys.join(',')}' : '';
      final b = body != null ? ' ${jsonEncode(_sanitize(body))}' : '';
      dev.log('→ $method $path$q$b', name: 'ParkingIQ');
    }

    final sw = _debug ? (Stopwatch()..start()) : null;

    late final http.Response response;
    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(_timeout);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody).timeout(_timeout);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody).timeout(_timeout);
        break;
      case 'PATCH':
        response = await _client
            .patch(uri, headers: headers, body: encodedBody)
            .timeout(_timeout);
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers).timeout(_timeout);
        break;
      default:
        throw ApiException('Unsupported HTTP method: $method');
    }

    final decoded = _decode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_debug) {
        dev.log(
          '✗ ${response.statusCode} $path (${sw!.elapsedMilliseconds}ms)'
          ' — ${_messageFrom(decoded) ?? response.reasonPhrase}',
          name: 'ParkingIQ',
          error: decoded,
        );
      }
      throw ApiException(
        _messageFrom(decoded) ?? response.reasonPhrase ?? 'Request failed',
        statusCode: response.statusCode,
        details: decoded,
      );
    }

    if (_debug) {
      dev.log(
        '← ${response.statusCode} $path (${sw!.elapsedMilliseconds}ms)'
        '${_responsePreview(decoded)}',
        name: 'ParkingIQ',
      );
    }

    // A 2xx that isn't JSON means we're not talking to the API at all — most
    // often a base URL pointing at a web host whose SPA fallback serves
    // index.html for every path. Fail here rather than letting each caller
    // report its own confusing "payload was missing X".
    if (decoded is String) {
      if (_debug) {
        dev.log(
          '✗ ${response.statusCode} $path — non-JSON body '
          '(content-type: ${response.headers['content-type']})',
          name: 'ParkingIQ',
        );
      }
      throw ApiException(
        'Server returned a non-JSON response. Check the API base URL '
        '($_baseUri).',
        statusCode: response.statusCode,
        details: decoded,
      );
    }

    if (decoded is Map<String, dynamic>) {
      // The API wraps everything in {status, data, message} and reports some
      // failures as 200 + status:"error" — surface those as errors too.
      final status = jsonString(decoded['status'])?.toLowerCase();
      final isEnvelope =
          decoded.containsKey('data') || decoded.containsKey('message');
      if (isEnvelope && (status == 'error' || status == 'fail')) {
        final message = jsonString(decoded['message']) ??
            jsonString(_dataMap(decoded)?['error']) ??
            'Request failed';
        if (_debug) {
          dev.log(
            '✗ ${response.statusCode} $path — status=$status — $message',
            name: 'ParkingIQ',
            error: decoded,
          );
        }
        throw ApiException(
          message,
          statusCode: response.statusCode,
          details: decoded,
        );
      }
      return decoded;
    }
    return {'data': decoded};
  }

  String _responsePreview(Object? decoded) {
    if (decoded == null) return '';
    try {
      final raw = jsonEncode(decoded);
      if (raw.length <= 200) return ' — $raw';
      return ' — ${raw.substring(0, 200)}…';
    } catch (_) {
      return '';
    }
  }

  static const _sensitiveKeys = {'otp', 'password', 'token', 'accessToken', 'secret'};

  Map<String, dynamic> _sanitize(Map<String, dynamic> body) => {
        for (final e in body.entries)
          e.key: _sensitiveKeys.contains(e.key) ? '***' : e.value,
      };

  Uri _uri(String path, Map<String, dynamic>? query) {
    final basePath = _baseUri.path.endsWith('/')
        ? _baseUri.path.substring(0, _baseUri.path.length - 1)
        : _baseUri.path;
    final requestPath = path.startsWith('/') ? path : '/$path';
    final queryParameters = query?.map((key, value) => MapEntry(key, value.toString()));

    return _baseUri.replace(
      path: '$basePath$requestPath',
      queryParameters: queryParameters,
    );
  }

  Object? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return body;
    }
  }

  String? _messageFrom(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      return jsonString(decoded['message']) ??
          jsonString(decoded['error']) ??
          jsonString(decoded['status']);
    }
    return decoded?.toString();
  }

  Map<String, dynamic>? _dataMap(Map<String, dynamic> response) {
    final data = response['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  Map<String, dynamic> _requiredDataMap(Map<String, dynamic> response) {
    final data = _dataMap(response);
    if (data == null) {
      throw ApiException('API response did not include an object payload');
    }
    return data;
  }

  Map<String, dynamic> _requiredObjectPayload(Map<String, dynamic> response) {
    return _dataMap(response) ?? response;
  }

  List<Map<String, dynamic>> _dataList(Map<String, dynamic> response) {
    final data = _listPayload(response['data']) ?? _listPayload(response);
    if (data == null) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  List<dynamic>? _listPayload(Object? value) {
    if (value is List) return value;
    if (value is Map<String, dynamic>) {
      const listKeys = {
        'items',
        'sessions',
        'parkingSessions',
        'content',
        'results',
        'vehicles',
        'transactions',
        'payments',
        'locations',
        'profiles',
        'tenants',
        'requests',
        'subscriptions',
      };

      for (final key in listKeys) {
        final nested = value[key];
        if (nested is List) return nested;
      }
      for (final nested in value.values) {
        if (nested is List) return nested;
      }
    }
    return null;
  }

  AuthResult? _authResultOrNull(Map<String, dynamic> response) {
    final data = _dataMap(response);
    final payload = _firstAuthPayload([
      data,
      data?['auth'],
      data?['authentication'],
      data?['session'],
      response,
      response['auth'],
      response['authentication'],
      response['session'],
    ]);
    if (payload == null) return null;
    return AuthResult.fromJson(payload);
  }

  Map<String, dynamic>? _firstAuthPayload(List<Object?> candidates) {
    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic> && _hasToken(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  bool _hasToken(Map<String, dynamic> payload) {
    return jsonString(payload['token']) != null ||
        jsonString(payload['accessToken']) != null ||
        jsonString(payload['access_token']) != null ||
        jsonString(payload['authToken']) != null ||
        jsonString(payload['jwt']) != null;
  }

  String? _findAnyToken(Map<String, dynamic> response) {
    const tokenKeys = {
      'token', 'accessToken', 'access_token', 'authToken', 'jwt',
      'bearerToken', 'bearer', 'idToken',
    };
    // Search top-level and inside 'data'
    for (final map in [response, _dataMap(response)]) {
      if (map == null) continue;
      for (final key in tokenKeys) {
        final val = jsonString(map[key]);
        if (val != null && val.isNotEmpty) return val;
      }
      // Fallback: any string value that looks like a JWT
      for (final val in map.values) {
        final s = val is String ? val : null;
        if (s != null && s.startsWith('eyJ') && s.length > 20) return s;
      }
    }
    return null;
  }
}
