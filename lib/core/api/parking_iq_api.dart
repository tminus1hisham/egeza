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
  static const defaultBaseUrl = 'https://parking-api.transfa.org/api/v1';

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

    // Check if OTP was rejected (no verified indicator in data)
    final data = _dataMap(response);
    final verified = data != null && data.values.any((value) => value == true);
    if (!verified) {
      throw const ApiException('Invalid verification code');
    }

    throw const ApiException(
      'OTP verified but no session token was returned. Please try again.',
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
      '/payments/mpesa/stkpush',
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

  Future<ParkingSession> findActiveParkingSession({
    required String plateNumber,
    String? location,
    String? locationId,
  }) async {
    final response = await _request(
      'POST',
      '/parking/initiate',
      body: {
        'plateNumber': plateNumber,
        if (location != null && location.isNotEmpty) 'location': location,
        if (locationId != null && locationId.isNotEmpty)
          'locationId': locationId,
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
    final resolvedLocation = location ?? locationId;
    if (resolvedLocation == null || resolvedLocation.trim().isEmpty) {
      throw const ApiException('Parking location is required');
    }

    final response = await _request(
      'POST',
      '/parking/entry',
      body: {
        'plateNumber': plateNumber,
        'location': resolvedLocation,
        if (locationId != null && locationId.isNotEmpty)
          'locationId': locationId,
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
      'status': data['status'] ?? 'ACTIVE',
    });
  }

  Future<ParkingSession> parkingSession(String sessionId) async {
    final response = await _request('GET', '/parking/session/$sessionId');
    return ParkingSession.fromJson(_requiredObjectPayload(response));
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
        'location': location,
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

  Future<QrCodeResponse> generateQrCode(String locationId) async {
    final response = await _request(
      'POST',
      '/qrcode/generate',
      query: {'locationId': locationId},
    );
    return QrCodeResponse.fromJson(_requiredDataMap(response));
  }

  Future<List<ParkingLocation>> listLocations() async {
    final response = await _request('GET', '/admin/locations');
    return _dataList(response).map(ParkingLocation.fromJson).toList();
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

  Future<Map<String, dynamic>> barrierCommand({
    required String locationId,
    required String command,
  }) async {
    final response = await _request(
      'POST',
      '/admin/locations/$locationId/barrier',
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
        response = await _client.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _client.post(uri, headers: headers, body: encodedBody);
        break;
      case 'PUT':
        response = await _client.put(uri, headers: headers, body: encodedBody);
        break;
      case 'PATCH':
        response = await _client.patch(
          uri,
          headers: headers,
          body: encodedBody,
        );
        break;
      case 'DELETE':
        response = await _client.delete(uri, headers: headers);
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

    if (decoded is Map<String, dynamic>) return decoded;
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
        'locations',
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
