import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api/parking_iq_api.dart';
import '../core/user_prefs.dart';
import '../models/api_models.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';
import 'app_event.dart';
import 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final ParkingIqApi _api;

  AppBloc({
    ParkingIqApi? api,
    String? initialUserName,
    String? initialPhoneNumber,
    String? initialAuthToken,
  })  : _api = api ?? ParkingIqApi(),
        super(AppState(
          userName: initialUserName ?? 'James Mwangi',
          phoneNumber: initialPhoneNumber,
          authToken: initialAuthToken,
        )) {
    if (initialAuthToken != null && initialAuthToken.isNotEmpty) {
      _api.setToken(initialAuthToken);
    }
    on<RequestLoginOtp>(_onRequestLoginOtp);
    on<SignInWithOtp>(_onSignInWithOtp);
    on<RegisterAccount>(_onRegisterAccount);
    on<LoadDashboardData>(_onLoadDashboardData);
    on<AddVehicle>(_onAddVehicle);
    on<TopUpWallet>(_onTopUpWallet);
    on<EndParkingSession>(_onEndParkingSession);
    on<FindParkingSession>(_onFindParkingSession);
    on<PayParkingSession>(_onPayParkingSession);
    on<SetVehicleAutoPay>(_onSetVehicleAutoPay);
    on<RemoveVehicle>(_onRemoveVehicle);
    on<ClearAppMessages>(_onClearAppMessages);
    on<ClearParkingSelection>(_onClearParkingSelection);
    on<SignOut>(_onSignOut);
  }

  void _log(String msg) {
    if (kDebugMode) dev.log(msg, name: 'AppBloc');
  }

  void _logSuccess(String handler, String detail) {
    if (kDebugMode) dev.log('✓ $handler — $detail', name: 'AppBloc');
  }

  void _logError(String handler, Object error, StackTrace st) {
    dev.log('✗ $handler — $error', name: 'AppBloc', error: error, stackTrace: st);
  }

  Future<void> _onRequestLoginOtp(
    RequestLoginOtp event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('RequestLoginOtp: phone=${event.phoneNumber}');

    try {
      final auth = await _api.requestLoginOtp(event.phoneNumber);
      if (auth != null && auth.token.isNotEmpty) {
        _logSuccess('RequestLoginOtp', 'auto-signed in, token received');
        await UserPrefs.saveToken(auth.token);
        emit(
          _authenticatedState(
            auth,
            fallbackPhoneNumber: event.phoneNumber,
            statusMessage: 'Signed in to Parking IQ',
          ),
        );
        return;
      }

      _logSuccess('RequestLoginOtp', 'OTP sent, awaiting verification');
      emit(
        state.copyWith(
          phoneNumber: event.phoneNumber,
          isLoading: false,
          statusMessage: 'Verification code sent',
        ),
      );
    } catch (error, st) {
      _logError('RequestLoginOtp', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onSignInWithOtp(
    SignInWithOtp event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('SignInWithOtp: phone=${event.phoneNumber}');

    try {
      final auth = await _api.signInWithOtp(
        phoneNumber: event.phoneNumber,
        otp: event.otp,
      );

      _logSuccess('SignInWithOtp', 'authenticated, token received');
      await UserPrefs.saveToken(auth.token);
      emit(
        _authenticatedState(
          auth,
          fallbackPhoneNumber: event.phoneNumber,
          statusMessage: 'Welcome back to Parking IQ',
        ),
      );
    } catch (error, st) {
      _logError('SignInWithOtp', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onRegisterAccount(
    RegisterAccount event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('RegisterAccount: phone=${event.phoneNumber} name=${event.fullName}');

    try {
      final auth = await _api.register(
        phoneNumber: event.phoneNumber,
        otp: event.otp,
        fullName: event.fullName,
        idNumber: event.idNumber,
        county: event.county,
        email: event.email,
      );

      final user = auth.user;
      _logSuccess('RegisterAccount', 'registered user=${user?.fullName ?? event.fullName}');
      await Future.wait([
        UserPrefs.save(
          name: user?.fullName ?? event.fullName,
          phone: user?.phoneNumber ?? event.phoneNumber,
        ),
        UserPrefs.saveToken(auth.token),
      ]);
      emit(
        _authenticatedState(
          auth,
          fallbackName: user?.fullName ?? event.fullName,
          fallbackPhoneNumber: user?.phoneNumber ?? event.phoneNumber,
          fallbackEmail: user?.email ?? event.email,
          requiresVehicleSetup: true,
          statusMessage: 'Account connected to Parking IQ',
        ),
      );
    } catch (error, st) {
      _logError('RegisterAccount', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('LoadDashboardData: hasToken=${_api.hasToken}');

    if (!_api.hasToken) {
      _log('LoadDashboardData: no token, using mock data');
      emit(
        state.copyWith(
          vehicles: state.vehicles.isEmpty ? _mockVehicles : state.vehicles,
          recentSessions:
              state.recentSessions.isEmpty ? _mockSessions : state.recentSessions,
          isLoading: false,
        ),
      );
      return;
    }

    try {
      final profileFuture = _api.me().then<Object?>((value) => value).catchError(
            (e, st) {
              _logError('LoadDashboardData/me', e, st);
              return null;
            },
          );
      final balanceFuture = _api
          .walletBalance()
          .then<Object?>((value) => value)
          .catchError((e, st) {
            _logError('LoadDashboardData/walletBalance', e, st);
            return null;
          });
      final vehiclesFuture = _api
          .listVehicles()
          .then<Object?>((value) => value)
          .catchError((e, st) {
            _logError('LoadDashboardData/listVehicles', e, st);
            return null;
          });
      final transactionsFuture = _api
          .walletTransactions()
          .then<Object?>((value) => value)
          .catchError((e, st) {
            _logError('LoadDashboardData/walletTransactions', e, st);
            return null;
          });
      final locationsFuture = _api
          .listLocations()
          .then<Object?>((value) => value)
          .catchError((e, st) {
            _logError('LoadDashboardData/listLocations', e, st);
            return null;
          });

      final results = await Future.wait([
        profileFuture,
        balanceFuture,
        vehiclesFuture,
        transactionsFuture,
        locationsFuture,
      ]);

      final profile = results[0] is UserProfile ? results[0] as UserProfile : null;
      final balance = results[1] is double ? results[1] as double : null;
      final vehicles =
          results[2] is List<Vehicle> ? results[2] as List<Vehicle> : null;
      final transactions = results[3] is List<WalletTransaction>
          ? results[3] as List<WalletTransaction>
          : null;
      final locations = results[4] is List<ParkingLocation>
          ? results[4] as List<ParkingLocation>
          : null;

      _logSuccess(
        'LoadDashboardData',
        'profile=${profile?.fullName} balance=$balance '
        'vehicles=${vehicles?.length} transactions=${transactions?.length} '
        'locations=${locations?.length}',
      );
      emit(
        state.copyWith(
          userName: profile?.fullName ?? state.userName,
          phoneNumber: profile?.phoneNumber ?? state.phoneNumber,
          email: profile?.email ?? state.email,
          requiresVehicleSetup:
              vehicles == null ? state.requiresVehicleSetup : vehicles.isEmpty,
          walletBalance: balance ?? state.walletBalance,
          vehicles: vehicles ?? state.vehicles,
          walletTransactions: transactions ?? state.walletTransactions,
          locations: locations ?? state.locations,
          isLoading: false,
        ),
      );
    } catch (error, st) {
      _logError('LoadDashboardData', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onAddVehicle(
    AddVehicle event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('AddVehicle: plate=${event.plateNumber} type=${event.type} make=${event.make} model=${event.model} autoPay=${event.autoPayEnabled}');

    try {
      Vehicle vehicle;
      if (_api.hasToken) {
        vehicle = await _api.addVehicle(
          plateNumber: event.plateNumber,
          vehicleType: event.type,
          make: event.make,
          model: event.model,
        );
        _logSuccess('AddVehicle/addVehicle', 'id=${vehicle.id} plate=${vehicle.plateNumber}');
        if (event.autoPayEnabled && vehicle.id != null) {
          vehicle = await _api.setVehicleAutoPay(
            vehicleId: vehicle.id!,
            enabled: true,
          );
          _logSuccess('AddVehicle/setVehicleAutoPay', 'autoPay=${vehicle.autoPayEnabled}');
        }
      } else {
        _log('AddVehicle: no token, creating local vehicle');
        vehicle = Vehicle(
          plateNumber: event.plateNumber,
          type: event.type,
          make: event.make,
          model: event.model,
          autoPayEnabled: event.autoPayEnabled,
        );
      }

      final existing = state.vehicles
          .where((item) => item.plateNumber != vehicle.plateNumber)
          .toList();

      emit(
        state.copyWith(
          vehicles: [...existing, vehicle],
          requiresVehicleSetup: false,
          isLoading: false,
          statusMessage: '${vehicle.plateNumber} added',
        ),
      );
    } catch (error, st) {
      _logError('AddVehicle', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onTopUpWallet(
    TopUpWallet event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('TopUpWallet: amount=${event.amount} phone=${event.phoneNumber}');

    try {
      if (_api.hasToken) {
        final normalizedPhone = _normalizePhone(event.phoneNumber ?? state.phoneNumber);
        _log('TopUpWallet/stkPush: phone=$normalizedPhone amount=${event.amount}');
        final response = await _api.topUpWallet(
          amount: event.amount,
          phoneNumber: normalizedPhone,
        );
        _logSuccess('TopUpWallet/topUpWallet', 'checkoutRequestId=${response.checkoutRequestId}');
        final balance = await _api.walletBalance().catchError((e, st) {
          _logError('TopUpWallet/walletBalance', e, st);
          return state.walletBalance;
        });
        _logSuccess('TopUpWallet/walletBalance', 'balance=$balance');

        emit(
          state.copyWith(
            walletBalance: balance,
            isLoading: false,
            statusMessage:
                response.customerMessage ?? 'M-Pesa top-up request sent',
          ),
        );
      } else {
        _log('TopUpWallet: no token, updating locally');
        emit(
          state.copyWith(
            walletBalance: state.walletBalance + event.amount,
            isLoading: false,
            statusMessage: 'Wallet topped up locally',
          ),
        );
      }
    } catch (error, st) {
      _logError('TopUpWallet', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onEndParkingSession(
    EndParkingSession event,
    Emitter<AppState> emit,
  ) async {
    add(PayParkingSession(sessionId: event.sessionId));
  }

  Future<void> _onFindParkingSession(
    FindParkingSession event,
    Emitter<AppState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        clearMessages: true,
        clearSelectedSession: true,
      ),
    );

    _log('FindParkingSession: plate=${event.plateNumber} locationId=${event.locationId}');

    try {
      if (!_api.hasToken) {
        throw const ApiException('Please create an account before paying');
      }

      final locationId = event.locationId ??
          (state.locations.isNotEmpty ? state.locations.first.id : null);
      final session = await _api.findActiveParkingSession(
        plateNumber: event.plateNumber,
        locationId: locationId,
      );
      _logSuccess('FindParkingSession/findActiveParkingSession', 'sessionId=${session.id} status=${session.status}');

      final calculated = session.id.isEmpty
          ? session
          : await _api.calculateParkingSession(session.id).catchError((e, st) {
              _logError('FindParkingSession/calculateParkingSession', e, st);
              return session;
            });
      if (session.id.isNotEmpty) {
        _logSuccess('FindParkingSession/calculateParkingSession', 'cost=${calculated.cost} duration=${calculated.durationMinutes}min');
      }

      emit(
        state.copyWith(
          selectedSession: _hydrateSessionVehicle(calculated),
          isLoading: false,
        ),
      );
    } catch (error, st) {
      _logError('FindParkingSession', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onPayParkingSession(
    PayParkingSession event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('PayParkingSession: sessionId=${event.sessionId} useWallet=${event.useWallet} phone=${event.phoneNumber}');

    try {
      ParkingSession paid;
      if (_api.hasToken) {
        // Step 1: mark the session as being paid via wallet
        paid = await _api.payParkingSession(
          sessionId: event.sessionId,
          useWallet: event.useWallet,
          phoneNumber: event.phoneNumber,
        );
        _logSuccess('PayParkingSession/payParkingSession', 'status=${paid.status} cost=${paid.cost}');

        // Step 2: send an M-Pesa STK push to the user's phone for the amount due
        final rawPhone = event.phoneNumber ?? state.phoneNumber;
        final phone = _normalizePhone(rawPhone);
        if (phone != null && phone.isNotEmpty) {
          // Use amountDue from response; fall back to amountPaid, then event.amount
          final amountDue = paid.cost > 0
              ? paid.cost
              : (paid.amountPaid > 0 ? paid.amountPaid : (event.amount ?? 1.0));
          _log('PayParkingSession/stkPush: phone=$phone amount=$amountDue ref=${paid.id.isNotEmpty ? paid.id : event.sessionId}');
          try {
            final stkResp = await _api.stkPush(
              phoneNumber: phone,
              amount: amountDue,
              accountReference: paid.id.isNotEmpty ? paid.id : event.sessionId,
              transactionDesc: 'Parking – ${paid.vehicle.plateNumber.isNotEmpty ? paid.vehicle.plateNumber : event.sessionId}',
            );
            _logSuccess('PayParkingSession/stkPush', 'checkoutRequestId=${stkResp.checkoutRequestId} msg=${stkResp.customerMessage}');
          } catch (stkErr, stkSt) {
            _logError('PayParkingSession/stkPush', stkErr, stkSt);
            // Non-fatal: session is already recorded as paid
          }
        } else {
          _log('PayParkingSession: no phone number available, skipping STK push (rawPhone=$rawPhone)');
        }
      } else {
        _log('PayParkingSession: no token, completing locally');
        final local = state.recentSessions.firstWhere(
          (session) => session.id == event.sessionId,
          orElse: () => state.selectedSession!,
        );
        paid = local.copyWith(
          status: 'COMPLETED',
          isActive: false,
          endTime: DateTime.now(),
          amountPaid: local.cost,
        );
      }

      final updatedSession = _hydrateSessionVehicle(
        paid.copyWith(
          isActive: false,
          endTime: paid.endTime ?? DateTime.now(),
        ),
      );
      final sessions = [
        updatedSession,
        ...state.recentSessions
            .where((session) => session.id != updatedSession.id),
      ];
      final balance = _api.hasToken
          ? await _api.walletBalance().catchError((e, st) {
              _logError('PayParkingSession/walletBalance', e, st);
              return state.walletBalance;
            })
          : state.walletBalance - updatedSession.cost;
      if (_api.hasToken) {
        _logSuccess('PayParkingSession/walletBalance', 'balance=$balance');
      }

      final stkStatusMessage = _api.hasToken
          ? (event.phoneNumber != null && event.phoneNumber!.isNotEmpty
              ? 'STK push sent to ${event.phoneNumber} — check your phone'
              : (state.phoneNumber != null && state.phoneNumber!.isNotEmpty
                  ? 'STK push sent to ${state.phoneNumber} — check your phone'
                  : 'Parking payment recorded'))
          : 'Parking payment completed';

      emit(
        state.copyWith(
          recentSessions: sessions,
          walletBalance: balance,
          selectedSession: updatedSession,
          isLoading: false,
          statusMessage: stkStatusMessage,
        ),
      );
    } catch (error, st) {
      _logError('PayParkingSession', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<void> _onSetVehicleAutoPay(
    SetVehicleAutoPay event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(clearMessages: true));
    _log('SetVehicleAutoPay: plate=${event.plateNumber} vehicleId=${event.vehicleId} enabled=${event.enabled}');

    try {
      Vehicle? updated;
      if (_api.hasToken && event.vehicleId != null) {
        updated = await _api.setVehicleAutoPay(
          vehicleId: event.vehicleId!,
          enabled: event.enabled,
        );
        _logSuccess('SetVehicleAutoPay', 'autoPay=${updated.autoPayEnabled}');
      } else {
        _log('SetVehicleAutoPay: no token or no vehicleId, updating locally');
      }

      final vehicles = state.vehicles.map((vehicle) {
        if (vehicle.plateNumber != event.plateNumber) return vehicle;
        return updated ?? vehicle.copyWith(autoPayEnabled: event.enabled);
      }).toList();

      emit(
        state.copyWith(
          vehicles: vehicles,
          statusMessage:
              event.enabled ? 'AutoPay enabled' : 'AutoPay disabled',
        ),
      );
    } catch (error, st) {
      _logError('SetVehicleAutoPay', error, st);
      emit(state.copyWith(errorMessage: _friendlyError(error)));
    }
  }

  Future<void> _onRemoveVehicle(
    RemoveVehicle event,
    Emitter<AppState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    _log('RemoveVehicle: plate=${event.plateNumber} vehicleId=${event.vehicleId}');

    try {
      if (_api.hasToken && event.vehicleId != null) {
        await _api.deleteVehicle(event.vehicleId!);
        _logSuccess('RemoveVehicle/deleteVehicle', 'deleted vehicleId=${event.vehicleId}');
      } else {
        _log('RemoveVehicle: no token or no vehicleId, removing locally');
      }

      emit(
        state.copyWith(
          vehicles: state.vehicles
              .where((vehicle) => vehicle.plateNumber != event.plateNumber)
              .toList(),
          isLoading: false,
          statusMessage: '${event.plateNumber} removed',
        ),
      );
    } catch (error, st) {
      _logError('RemoveVehicle', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  void _onClearAppMessages(
    ClearAppMessages event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(clearMessages: true));
  }

  void _onClearParkingSelection(
    ClearParkingSelection event,
    Emitter<AppState> emit,
  ) {
    emit(state.copyWith(clearSelectedSession: true, clearMessages: true));
  }

  Future<void> _onSignOut(
    SignOut event,
    Emitter<AppState> emit,
  ) async {
    _api.setToken(null);
    await UserPrefs.clearToken();
    emit(const AppState());
  }

  ParkingSession _hydrateSessionVehicle(ParkingSession session) {
    final vehicle = state.vehicles.firstWhere(
      (item) => item.plateNumber == session.vehicle.plateNumber,
      orElse: () => session.vehicle,
    );
    return session.copyWith(vehicle: vehicle);
  }

  String _friendlyError(Object error) {
    if (error is ApiException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  /// Normalizes a Kenyan phone number to M-Pesa format (254XXXXXXXXX).
  /// Accepts: 07xx, 01xx, +254xx, 254xx
  String? _normalizePhone(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 12 && digits.startsWith('254')) return digits;   // 254712345678
    if (digits.length == 10 && digits.startsWith('0')) return '254${digits.substring(1)}'; // 0712345678
    if (digits.length == 9) return '254$digits';  // 712345678
    // Already a reasonable E.164 string or unknown — return as-is stripped of leading +
    return digits.isEmpty ? null : digits;
  }

  AppState _authenticatedState(
    AuthResult auth, {
    String? fallbackName,
    String? fallbackPhoneNumber,
    String? fallbackEmail,
    bool? requiresVehicleSetup,
    required String statusMessage,
  }) {
    final user = auth.user;
    return state.copyWith(
      authToken: auth.token,
      userName: user?.fullName ?? fallbackName ?? state.userName,
      phoneNumber: user?.phoneNumber ?? fallbackPhoneNumber ?? state.phoneNumber,
      email: user?.email ?? fallbackEmail ?? state.email,
      requiresVehicleSetup: requiresVehicleSetup ?? auth.requiresVehicle,
      isLoading: false,
      statusMessage: statusMessage,
    );
  }

  List<Vehicle> get _mockVehicles => const [
        Vehicle(
          plateNumber: 'KBZ 123A',
          type: 'SUV / 4x4',
          make: 'Toyota',
          model: 'Prado',
          autoPayEnabled: true,
        ),
        Vehicle(
          plateNumber: 'KBC 456B',
          type: 'SUV',
          make: 'Honda',
          model: 'CR-V',
        ),
      ];

  List<ParkingSession> get _mockSessions {
    final vehicle1 = _mockVehicles[0];
    final vehicle2 = _mockVehicles[1];

    return [
      ParkingSession(
        id: '1',
        locationName: 'Garden City Mall',
        startTime: DateTime.now().subtract(
          const Duration(hours: 1, minutes: 43),
        ),
        endTime: DateTime.now().subtract(const Duration(minutes: 2)),
        cost: 180,
        vehicle: vehicle1,
        isActive: false,
        status: 'COMPLETED',
      ),
      ParkingSession(
        id: '2',
        locationName: 'Two Rivers Mall',
        startTime: DateTime.now().subtract(
          const Duration(days: 1, hours: 2, minutes: 35),
        ),
        endTime: DateTime.now().subtract(const Duration(days: 1)),
        cost: 290,
        vehicle: vehicle2,
        isActive: false,
        status: 'COMPLETED',
      ),
      ParkingSession(
        id: '3',
        locationName: 'Westgate Shopping Centre',
        startTime: DateTime.now().subtract(
          const Duration(days: 2, hours: 1, minutes: 30),
        ),
        endTime: DateTime.now().subtract(const Duration(days: 2)),
        cost: 150,
        vehicle: vehicle1,
        isActive: false,
        status: 'COMPLETED',
      ),
    ];
  }
}
