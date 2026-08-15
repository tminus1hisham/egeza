import 'dart:developer' as dev;

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api/parking_iq_api.dart';
import '../core/error_handler.dart';
import '../core/payment/payment_validation.dart';
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
    ThemeMode initialThemeMode = ThemeMode.system,
  })  : _api = api ?? ParkingIqApi(),
        super(AppState(
          userName: initialUserName ?? '',
          phoneNumber: initialPhoneNumber,
          authToken: initialAuthToken,
          themeMode: initialThemeMode,
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
    on<ChangeThemeMode>(_onChangeThemeMode);
    on<ClearAppMessages>(_onClearAppMessages);
    on<ClearParkingSelection>(_onClearParkingSelection);
    on<SignOut>(_onSignOut);
  }

  Future<void> _onChangeThemeMode(
    ChangeThemeMode event,
    Emitter<AppState> emit,
  ) async {
    _log('ChangeThemeMode: ${event.themeMode}');
    emit(state.copyWith(themeMode: event.themeMode));
    
    String themeString = 'system';
    if (event.themeMode == ThemeMode.light) themeString = 'light';
    if (event.themeMode == ThemeMode.dark) themeString = 'dark';
    
    await UserPrefs.saveTheme(themeString);
  }

  void _log(String msg) {
    if (kDebugMode) {
      dev.log(msg, name: 'AppBloc');
      debugPrint('[AppBloc] $msg');
    }
  }

  void _logSuccess(String handler, String detail) {
    if (kDebugMode) {
      dev.log('✓ $handler — $detail', name: 'AppBloc');
      debugPrint('[AppBloc] ✓ $handler — $detail');
    }
  }

  void _logError(String handler, Object error, StackTrace st) {
    dev.log('✗ $handler — $error', name: 'AppBloc', error: error, stackTrace: st);
    debugPrint('[AppBloc] ✗ $handler — $error\n$st');
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
        _log('Token saved [RequestLoginOtp]: length=${auth.token.length} prefix=${auth.token.substring(0, auth.token.length.clamp(0, 8))}…');
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
      _log('Token saved [SignInWithOtp]: length=${auth.token.length} prefix=${auth.token.substring(0, auth.token.length.clamp(0, 8))}…');
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
      _log('Token saved [RegisterAccount]: length=${auth.token.length} prefix=${auth.token.substring(0, auth.token.length.clamp(0, 8))}…');
      emit(
        _authenticatedState(
          auth,
          fallbackName: user?.fullName ?? event.fullName,
          fallbackPhoneNumber: user?.phoneNumber ?? event.phoneNumber,
          fallbackEmail: user?.email ?? event.email,
          requiresVehicleSetup: false,
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
    final showInitialLoader = state.vehicles.isEmpty &&
        state.recentSessions.isEmpty &&
        state.locations.isEmpty;
    emit(state.copyWith(isLoading: showInitialLoader, clearMessages: true));
    _log('LoadDashboardData: hasToken=${_api.hasToken}');

    if (!_api.hasToken) {
      // Reaching the dashboard without an auth token is an auth fault, never a
      // normal state. Don't render mock data — clear any stale token and route
      // the user to sign in via the session-expired guard.
      _log('LoadDashboardData: no auth token — routing to sign-in');
      _api.setToken(null);
      await UserPrefs.clearToken();
      emit(
        state.copyWith(
          isLoading: false,
          sessionExpired: true,
          clearAuthToken: true,
        ),
      );
      return;
    }

    try {
      bool unauthorized = false;

      void trackUnauthorized(Object e, StackTrace st, String tag) {
        if (_isUnauthorized(e)) unauthorized = true;
        _logError('LoadDashboardData/$tag', e, st);
      }

      final profileFuture = _api.me().then<Object?>((v) => v).catchError(
            (Object e, StackTrace st) {
              trackUnauthorized(e, st, 'me');
              return null;
            },
          );
      final balanceFuture = _api
          .walletBalance()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'walletBalance');
        return null;
      });
      final vehiclesFuture = _api
          .listVehicles()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'listVehicles');
        return null;
      });
      final locationsFuture = _api
          .fetchParkingLocations()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'listLocations');
        return null;
      });
      final recentSessionsFuture = _api
          .recentParkingSessions()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'recentParkingSessions');
        return null;
      });
      final activeSessionsFuture = _activeParkingSessionsWithAmounts()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'activeParkingSessions');
        return null;
      });
      // Chained off the vehicles call because it needs the registered plates.
      final plateSessionsFuture = vehiclesFuture.then<Object?>((result) {
        return _sessionsForRegisteredPlates(
          result is List<Vehicle> ? result : state.vehicles,
        );
      }).catchError((Object e, StackTrace st) {
        _logError('LoadDashboardData/plateSessions', e, st);
        return null;
      });

      final coreResults = await Future.wait([
        profileFuture,
        balanceFuture,
        vehiclesFuture,
        locationsFuture,
        recentSessionsFuture,
        activeSessionsFuture,
        plateSessionsFuture,
      ]);

      if (unauthorized) {
        _log('LoadDashboardData: token rejected (403), session expired');
        _api.setToken(null);
        await UserPrefs.clearToken();
        emit(state.copyWith(isLoading: false, sessionExpired: true, clearAuthToken: true));
        return;
      }

      final profile = coreResults[0] is UserProfile ? coreResults[0] as UserProfile : null;
      final balance = coreResults[1] is double ? coreResults[1] as double : null;
      final vehicles =
          coreResults[2] is List<Vehicle> ? coreResults[2] as List<Vehicle> : null;
      final locations = coreResults[3] is List<ParkingLocation>
          ? coreResults[3] as List<ParkingLocation>
          : null;
      final recentSessions = coreResults[4] is List<ParkingSession>
          ? coreResults[4] as List<ParkingSession>
          : null;
      final activeSessions = coreResults[5] is List<ParkingSession>
          ? coreResults[5] as List<ParkingSession>
          : null;
      final plateSessions = coreResults[6] is List<ParkingSession>
          ? coreResults[6] as List<ParkingSession>
          : null;
      final sessions = _mergeFetchedSessions(
        recentSessions: recentSessions,
        activeSessions: activeSessions,
        plateSessions: plateSessions,
        vehicles: vehicles ?? state.vehicles,
      );

      _logSuccess(
        'LoadDashboardData',
        'profile=${profile?.fullName} balance=$balance '
        'vehicles=${vehicles?.length} '
        'locations=${locations?.length} recent=${recentSessions?.length} '
        'active=${activeSessions?.length} byPlate=${plateSessions?.length} '
        'merged=${sessions?.length}',
      );
      emit(
        state.copyWith(
          userName: profile?.fullName ?? state.userName,
          phoneNumber: profile?.phoneNumber ?? state.phoneNumber,
          email: profile?.email ?? state.email,
          userRole: profile?.role ?? state.userRole,
          requiresVehicleSetup:
              vehicles == null ? state.requiresVehicleSetup : vehicles.isEmpty,
          walletBalance: balance ?? state.walletBalance,
          vehicles: vehicles ?? state.vehicles,
          recentSessions: sessions,
          locations: locations ?? state.locations,
          isLoading: false,
        ),
      );

      unauthorized = false;
      final transactionsFuture = _api
          .walletTransactions()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        trackUnauthorized(e, st, 'walletTransactions');
        return null;
      });
      final tenantProfilesFuture = _api
          .fetchMyTenantProfiles()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        if (_isEmptyTenancyData(e)) return const <TenantProfile>[];
        _logError('LoadDashboardData/fetchMyTenantProfiles', e, st);
        return null;
      });
      final tenancyRequestsFuture = _api
          .fetchTenancyRequests()
          .then<Object?>((v) => v)
          .catchError((Object e, StackTrace st) {
        if (_isEmptyTenancyData(e)) return const <TenancyRequest>[];
        _logError('LoadDashboardData/fetchTenancyRequests', e, st);
        return null;
      });

      final secondaryResults = await Future.wait([
        transactionsFuture,
        tenantProfilesFuture,
        tenancyRequestsFuture,
      ]);

      if (unauthorized) {
        _log('LoadDashboardData: token rejected by secondary data request');
        _api.setToken(null);
        await UserPrefs.clearToken();
        emit(state.copyWith(isLoading: false, sessionExpired: true, clearAuthToken: true));
        return;
      }

      final transactions = secondaryResults[0] is List<WalletTransaction>
          ? secondaryResults[0] as List<WalletTransaction>
          : null;
      final tenantProfiles = secondaryResults[1] is List<TenantProfile>
          ? secondaryResults[1] as List<TenantProfile>
          : null;
      final tenancyRequests = secondaryResults[2] is List<TenancyRequest>
          ? secondaryResults[2] as List<TenancyRequest>
          : null;

      _logSuccess(
        'LoadDashboardData/secondary',
        'transactions=${transactions?.length} tenants=${tenantProfiles?.length} '
        'requests=${tenancyRequests?.length}',
      );
      emit(
        state.copyWith(
          walletTransactions: transactions ?? state.walletTransactions,
          tenantProfiles: tenantProfiles ?? state.tenantProfiles,
          tenancyRequests: tenancyRequests ?? state.tenancyRequests,
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
    // Register the plate in the same canonical form the gate cameras write
    // ('KBR 656 Z' -> 'KBR656Z'). The backend links sessions to a user by the
    // stored plate string, so a spaced plate here never matches ANPR sessions.
    final plateNumber = Vehicle.plateKey(event.plateNumber);
    _log('AddVehicle: plate=$plateNumber type=${event.type} make=${event.make} model=${event.model} autoPay=${event.autoPayEnabled}');

    try {
      Vehicle vehicle;
      if (_api.hasToken) {
        vehicle = await _api.addVehicle(
          plateNumber: plateNumber,
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
          plateNumber: plateNumber,
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
    _log('TopUpWallet: amount=${event.amount} phone=${event.phoneNumber} hasToken=${_api.hasToken}');

    try {
      if (_api.hasToken) {
        final rawPhone = event.phoneNumber ?? state.phoneNumber;
        final normalizedPhone = _normalizePhone(rawPhone);
        _log('TopUpWallet: rawPhone=$rawPhone normalizedPhone=$normalizedPhone');

        if (normalizedPhone == null || normalizedPhone.isEmpty) {
          _log('TopUpWallet: ⚠ phone is null/empty after normalization — STK push will be sent without phone');
        }

        _log('TopUpWallet: calling /wallet/topup ...');
        final response = await _api.topUpWallet(
          amount: event.amount,
          phoneNumber: normalizedPhone,
        );
        _logSuccess(
          'TopUpWallet/topUpWallet',
          'checkoutRequestId=${response.checkoutRequestId} '
          'responseCode=${response.responseCode} '
          'responseDescription=${response.responseDescription} '
          'customerMessage=${response.customerMessage}',
        );

        emit(
          state.copyWith(
            isLoading: false,
            statusMessage: response.customerMessage ?? 'M-Pesa prompt sent — check your phone',
          ),
        );

        // STK push is async: wait for the user to complete the M-Pesa prompt
        // before polling the updated balance.
        await Future.delayed(const Duration(seconds: 15));
        if (!isClosed) {
          _log('TopUpWallet: polling balance after STK delay ...');
          final balance = await _api.walletBalance().catchError((e, st) {
            _logError('TopUpWallet/walletBalance', e, st);
            return state.walletBalance;
          });
          _logSuccess('TopUpWallet/walletBalance', 'balance=$balance');
          emit(state.copyWith(walletBalance: balance));
        }
      } else {
        _log('TopUpWallet: ⚠ no auth token — skipping real STK push, bumping balance locally');
        emit(
          state.copyWith(
            walletBalance: state.walletBalance + event.amount,
            isLoading: false,
            statusMessage: 'Wallet topped up locally (no auth)',
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

    _log('FindParkingSession: plate=${event.plateNumber}');

    try {
      if (!_api.hasToken) {
        throw const ApiException('Please create an account before paying');
      }

      PaymentValidation.validatePlateNumber(event.plateNumber);

      // Look up an EXISTING active session by plate alone via the public
      // /parking/sessions/by-plate/active endpoint. No location is required —
      // the backend resolves the session (and its location) from the plate.
      final sessions = await _api.activeParkingSessionsForPlate(
        _plateKey(event.plateNumber),
      );
      _logSuccess(
        'FindParkingSession/activeParkingSessionsForPlate',
        'count=${sessions.length}',
      );

      ParkingSession? session;
      for (final candidate in sessions) {
        if (candidate.isActive) {
          session = candidate;
          break;
        }
      }

      if (session == null || !session.isActive) {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage: 'No active parking session found for this plate. If you just paid, your session is complete.',
          ),
        );
        return;
      }

      final activeSession = session;
      final calculated = activeSession.id.isEmpty
          ? activeSession
          : await _api
              .calculateParkingSession(activeSession.id)
              .catchError((e, st) {
              _logError('FindParkingSession/calculateParkingSession', e, st);
              return activeSession;
            });
      if (activeSession.id.isNotEmpty) {
        _logSuccess('FindParkingSession/calculateParkingSession', 'cost=${calculated.cost} duration=${calculated.durationMinutes}min');
      }

      // Merge billing data from calculate with lifecycle data from the
      // by-plate lookup. The calculate endpoint (ParkingDetailsDto) doesn't
      // carry reliable status/isActive — always preserve them from the lookup.
      final merged = calculated.copyWith(
        status: activeSession.status,
        isActive: activeSession.isActive,
        endTime: activeSession.endTime,
      );

      emit(
        state.copyWith(
          selectedSession: _hydrateSessionVehicle(merged),
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
    if (state.isWaitingForPayment) {
      _log('PayParkingSession: ignored — already waiting for payment');
      return;
    }

    emit(
      state.copyWith(
        isLoading: true,
        isWaitingForPayment: false,
        clearActivePayment: true,
        clearMessages: true,
      ),
    );
    _log(
      'PayParkingSession: sessionId=${event.sessionId} '
      'phone=${event.phoneNumber} amount=${event.amount}',
    );

    try {
      if (!_api.hasToken) {
        throw const ApiException('Please sign in before paying for parking');
      }

      PaymentValidation.validateSessionId(event.sessionId);

      final existingSession = _sessionFromState(event.sessionId);
      if (existingSession != null) {
        PaymentValidation.validateSessionCanBePaid(existingSession);
      }

      final calculated = await _api.calculateParkingSession(event.sessionId);

      // validateSessionCanBePaid must check lifecycle status, not the billing
      // result from calculate (ParkingDetailsDto has unreliable isActive/status).
      // Prefer state session, then fall back to re-fetching the real session.
      final sessionForValidation = existingSession ??
          await _api.parkingSession(event.sessionId).catchError((e, st) {
            _logError('PayParkingSession/sessionForValidation', e, st);
            throw const ApiException(
              'Could not verify this parking session before payment. Please try again.',
            );
          });
      PaymentValidation.validateSessionCanBePaid(sessionForValidation);

      final promoCode = event.promoCode?.trim();
      DiscountRedemption? redemption;
      var payableSession = calculated.copyWith(
        status: sessionForValidation.status,
        isActive: sessionForValidation.isActive,
      );
      var amountDue = calculated.cost;

      if (promoCode != null && promoCode.isNotEmpty) {
        redemption = await _api.applyDiscount(
          sessionId: event.sessionId,
          code: promoCode,
        );
        amountDue = redemption.finalAmount;
        payableSession = payableSession.copyWith(
          cost: redemption.finalAmount,
          discountAmount: redemption.discountAmount,
        );
        _logSuccess(
          'PayParkingSession/applyDiscount',
          'discount=${redemption.discountAmount} final=${redemption.finalAmount}',
        );
      }

      if (event.amount != null && (promoCode == null || promoCode.isEmpty)) {
        PaymentValidation.validateAmountMatches(
          providedAmount: event.amount!,
          calculatedAmount: amountDue,
        );
      }

      if (amountDue <= 0) {
        if (redemption != null) {
          final completed = await _api
              .payParkingSession(sessionId: event.sessionId, useWallet: true)
              .catchError((e, st) {
            _logError('PayParkingSession/freePromoPay', e, st);
            return payableSession.copyWith(
              status: 'COMPLETED',
              isActive: false,
              endTime: DateTime.now(),
              amountPaid: 0,
            );
          });
          final updatedSession = _hydrateSessionVehicle(
            completed.copyWith(
              status: 'COMPLETED',
              isActive: false,
              endTime: completed.endTime ?? DateTime.now(),
              cost: amountDue,
              amountPaid: 0,
              discountAmount: redemption.discountAmount,
            ),
          );
          final sessions = [
            updatedSession,
            ...state.recentSessions
                .where((session) => session.id != updatedSession.id),
          ];

          emit(
            state.copyWith(
              recentSessions: sessions,
              selectedSession: updatedSession,
              isLoading: false,
              isWaitingForPayment: false,
              statusMessage: 'Promo applied. No payment is due.',
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            selectedSession: _hydrateSessionVehicle(payableSession),
            isLoading: false,
            statusMessage: 'No parking fee is due during the grace period',
          ),
        );
        return;
      }

      PaymentValidation.validateAmount(amountDue);

      final phone = PaymentValidation.requireValidMpesaPhone(
        event.phoneNumber ?? state.phoneNumber,
      );
      final plateNumber =
          (event.plateNumber ?? calculated.vehicle.plateNumber)
              .trim()
              .toUpperCase();
      final location = (event.location ?? calculated.locationName).trim();

      PaymentValidation.validatePlateNumber(plateNumber);
      PaymentValidation.validateLocation(location);

      final response = await _api.startSessionStkPush(
        phoneNumber: phone,
        amount: amountDue,
        sessionId: event.sessionId,
        plateNumber: plateNumber,
        location: location,
        transactionDesc: 'Parking session payment',
      );
      _logSuccess(
        'PayParkingSession/startSessionStkPush',
        'paymentId=${response.paymentId} '
        'checkoutRequestId=${response.checkoutRequestId}',
      );

      emit(
        state.copyWith(
          selectedSession: _hydrateSessionVehicle(payableSession),
          isLoading: false,
          isWaitingForPayment: true,
          activePayment: PaymentStatusSnapshot(
            paymentId: response.paymentId,
            checkoutRequestId: response.checkoutRequestId,
            sessionId: event.sessionId,
            status: response.status ?? 'PENDING',
            message: response.customerMessage,
          ),
          statusMessage:
              response.customerMessage ?? 'Waiting for M-Pesa confirmation...',
        ),
      );

      final terminalStatus = await _pollPaymentUntilTerminal(
        paymentId: response.paymentId,
        checkoutRequestId: response.checkoutRequestId,
        sessionId: event.sessionId,
      );

      if (terminalStatus.isSuccess) {
        final completed = await _api.parkingSession(event.sessionId).catchError(
          (e, st) {
            _logError('PayParkingSession/parkingSession', e, st);
            return calculated.copyWith(
              status: 'COMPLETED',
              isActive: false,
              endTime: DateTime.now(),
              amountPaid: amountDue,
              cost: amountDue,
              discountAmount: redemption?.discountAmount ?? 0,
            );
          },
        );
        final updatedSession = _hydrateSessionVehicle(
          completed.copyWith(
            status: 'COMPLETED',
            isActive: false,
            endTime: completed.endTime ?? DateTime.now(),
            cost: amountDue,
            amountPaid: redemption != null
                ? amountDue
                : (completed.amountPaid > 0 ? completed.amountPaid : amountDue),
            discountAmount:
                redemption?.discountAmount ?? completed.discountAmount,
          ),
        );
        final sessions = [
          updatedSession,
          ...state.recentSessions
              .where((session) => session.id != updatedSession.id),
        ];

        emit(
          state.copyWith(
            recentSessions: sessions,
            selectedSession: updatedSession,
            isLoading: false,
            isWaitingForPayment: false,
            activePayment: terminalStatus,
            statusMessage: 'Parking payment confirmed',
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          selectedSession: _hydrateSessionVehicle(payableSession),
          isLoading: false,
          isWaitingForPayment: false,
          activePayment: terminalStatus,
          errorMessage: _paymentFailureMessage(terminalStatus),
        ),
      );
    } catch (error, st) {
      _logError('PayParkingSession', error, st);
      emit(
        state.copyWith(
          isLoading: false,
          isWaitingForPayment: false,
          errorMessage: _friendlyError(error),
        ),
      );
    }
  }

  Future<PaymentStatusSnapshot> _pollPaymentUntilTerminal({
    required String sessionId,
    String? paymentId,
    String? checkoutRequestId,
  }) async {
    PaymentStatusSnapshot? lastStatus;

    for (var attempt = 0; attempt < 30; attempt++) {
      if (isClosed) {
        return PaymentStatusSnapshot(
          paymentId: lastStatus?.paymentId ?? paymentId,
          checkoutRequestId:
              lastStatus?.checkoutRequestId ?? checkoutRequestId,
          sessionId: lastStatus?.sessionId ?? sessionId,
          status: 'CANCELLED',
          message: 'Payment polling cancelled',
        );
      }
      if (attempt > 0) {
        await Future.delayed(const Duration(seconds: 3));
      }

      try {
        if (paymentId != null && paymentId.isNotEmpty) {
          lastStatus = await _api.paymentStatus(paymentId);
        } else if (checkoutRequestId != null && checkoutRequestId.isNotEmpty) {
          lastStatus = await _api.paymentStatusByCheckout(checkoutRequestId);
        } else {
          lastStatus = await _api.paymentStatusBySession(sessionId);
        }
      } catch (error, st) {
        _logError('PayParkingSession/pollPaymentStatus', error, st);
        try {
          if (checkoutRequestId != null && checkoutRequestId.isNotEmpty) {
            lastStatus = await _api.paymentStatusByCheckout(checkoutRequestId);
          } else {
            lastStatus = await _api.paymentStatusBySession(sessionId);
          }
        } catch (fallbackError, fallbackSt) {
          _logError(
            'PayParkingSession/pollPaymentStatusFallback',
            fallbackError,
            fallbackSt,
          );
        }
      }

      if (lastStatus?.isTerminal == true) return lastStatus!;
    }

    return PaymentStatusSnapshot(
      paymentId: lastStatus?.paymentId ?? paymentId,
      checkoutRequestId: lastStatus?.checkoutRequestId ?? checkoutRequestId,
      sessionId: lastStatus?.sessionId ?? sessionId,
      status: 'TIMEOUT',
      message: 'M-Pesa confirmation timed out',
    );
  }

  String _paymentFailureMessage(PaymentStatusSnapshot status) {
    final message = status.message;
    if (message != null && message.isNotEmpty) return message;

    switch (status.status) {
      case 'CANCELLED':
      case 'CANCELED':
        return 'M-Pesa payment was cancelled';
      case 'TIMEOUT':
      case 'TIMED_OUT':
        return 'M-Pesa confirmation timed out';
      case 'FAILED':
        return 'M-Pesa payment failed';
      default:
        return 'M-Pesa payment did not complete';
    }
  }

  ParkingSession? _sessionFromState(String sessionId) {
    final selected = state.selectedSession;
    if (selected != null && selected.id == sessionId) return selected;

    for (final session in state.recentSessions) {
      if (session.id == sessionId) return session;
    }
    return null;
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

  Future<List<ParkingSession>> _activeParkingSessionsWithAmounts() async {
    final sessions = await _api.activeParkingSessions();
    if (sessions.isEmpty) return sessions;

    return Future.wait(
      sessions.map((session) async {
        if (session.id.isEmpty) return session;

        try {
          final calculated = await _api.calculateParkingSession(session.id);

          // calculateParkingSession returns ParkingDetailsDto (billing data only).
          // Its status/isActive fields are unreliable — the DTO lacks exitTime so
          // fromJson defaults to status='ACTIVE'. Use the active-sessions endpoint's
          // own status as the source of truth and only take billing fields from calculate.
          final effectiveAmountPaid = calculated.amountPaid > 0
              ? calculated.amountPaid
              : session.amountPaid;

          // A session with any amount paid is completed, regardless of what the
          // active-sessions endpoint (or calculate) says about its status.
          final isPaid = effectiveAmountPaid > 0;
          final effectiveStatus = isPaid ? 'COMPLETED' : session.status;
          final effectiveIsActive = isPaid ? false : session.isActive;

          return session.copyWith(
            cost: calculated.cost > 0 || session.cost == 0
                ? calculated.cost
                : session.cost,
            amountPaid: effectiveAmountPaid,
            durationMinutes:
                calculated.durationMinutes ?? session.durationMinutes,
            locationName: calculated.locationName == 'Parking Location'
                ? session.locationName
                : calculated.locationName,
            autoPayEnabled:
                calculated.autoPayEnabled || session.autoPayEnabled,
            walletBalance: calculated.walletBalance ?? session.walletBalance,
            willAutoDeduct:
                calculated.willAutoDeduct || session.willAutoDeduct,
            vehicle: calculated.vehicle.plateNumber.isEmpty
                ? session.vehicle
                : calculated.vehicle,
            status: effectiveStatus,
            isActive: effectiveIsActive,
            endTime: isPaid ? (session.endTime ?? DateTime.now()) : session.endTime,
          );
        } catch (error, st) {
          _logError('LoadDashboardData/calculateParkingSession', error, st);
          return session;
        }
      }),
    );
  }

  /// Sessions fetched per registered plate from the open by-plate endpoint.
  ///
  /// The auth-scoped lists (`/parking/sessions/recent` and `/active`) only
  /// return sessions the backend has linked to this account. ANPR creates
  /// sessions keyed by plate alone, so an ongoing session can be missing from
  /// those lists while `/parking/sessions/by-plate` still has it. Query by
  /// plate as well and let the merge dedupe on session id.
  Future<List<ParkingSession>> _sessionsForRegisteredPlates(
    List<Vehicle> vehicles,
  ) async {
    // Query the canonical form the gates write, not the user's spacing.
    final plates = <String>{
      for (final vehicle in vehicles) _plateKey(vehicle.plateNumber),
    }..remove('');
    if (plates.isEmpty) return const [];

    final results = await Future.wait(
      plates.map(
        (plate) => _api.parkingSessionsForPlate(plate).catchError(
          (Object e, StackTrace st) {
            _logError('LoadDashboardData/plateSessions[$plate]', e, st);
            return const <ParkingSession>[];
          },
        ),
      ),
    );
    return [for (final sessions in results) ...sessions];
  }

  List<ParkingSession>? _mergeFetchedSessions({
    required List<ParkingSession>? recentSessions,
    required List<ParkingSession>? activeSessions,
    required List<ParkingSession>? plateSessions,
    required List<Vehicle> vehicles,
  }) {
    if (recentSessions == null &&
        activeSessions == null &&
        (plateSessions == null || plateSessions.isEmpty)) {
      return null;
    }

    final candidates = <ParkingSession>[
      if (recentSessions != null)
        ...recentSessions
      else
        ...state.recentSessions.where((session) => !session.isActive),
      if (activeSessions != null)
        ...activeSessions
      else
        // Active-sessions API failed — preserve state's active sessions so a
        // partial API failure doesn't silently clear them.
        ...state.recentSessions.where((session) => session.isActive),
      ...?plateSessions,
    ];

    return _mergeParkingSessions(candidates, vehicles: vehicles);
  }

  List<ParkingSession> _mergeParkingSessions(
    Iterable<ParkingSession> sessions, {
    required List<Vehicle> vehicles,
  }) {
    final byKey = <String, ParkingSession>{};

    for (final session in sessions) {
      final hydrated = _hydrateSessionVehicle(session, vehicles: vehicles);
      final key = _sessionKey(hydrated);
      final existing = byKey[key];
      // Prefer completed/paid over active so a paid session isn't reverted by
      // stale active-endpoint data. A session with amountPaid > 0 is always
      // treated as completed even if the server still lists it as active.
      final hydratedIsDone = !hydrated.isActive || hydrated.amountPaid > 0;
      final existingIsDone = existing != null &&
          (!existing.isActive || existing.amountPaid > 0);
      if (existing == null || (!existingIsDone && hydratedIsDone)) {
        byKey[key] = hydrated;
      }
    }

    return byKey.values.toList()
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return b.startTime.compareTo(a.startTime);
      });
  }

  String _sessionKey(ParkingSession session) {
    if (session.id.isNotEmpty) return 'id:${session.id}';

    return [
      _plateKey(session.vehicle.plateNumber),
      session.startTime.toIso8601String(),
      session.status,
    ].join(':');
  }

  ParkingSession _hydrateSessionVehicle(
    ParkingSession session, {
    List<Vehicle>? vehicles,
  }) {
    final plateKey = _plateKey(session.vehicle.plateNumber);
    if (plateKey.isEmpty) return session;

    final vehicle = (vehicles ?? state.vehicles).firstWhere(
      (item) => _plateKey(item.plateNumber) == plateKey,
      orElse: () => session.vehicle,
    );
    return session.copyWith(vehicle: vehicle);
  }

  String _plateKey(String plateNumber) => Vehicle.plateKey(plateNumber);

  bool _isUnauthorized(Object error) =>
      error is ApiException && error.statusCode == 403;

  bool _isEmptyTenancyData(Object error) {
    if (error is! ApiException) return false;
    final message = error.message.trim().toLowerCase();
    return error.statusCode == 403 ||
        error.statusCode == 404 ||
        message.isEmpty ||
        message.contains('forbidden') ||
        message.contains('not tenant') ||
        message.contains('no tenant') ||
        message.contains('no profile') ||
        message.contains('no request') ||
        message.contains('none found') ||
        message.contains('no record');
  }

  String _friendlyError(Object error) => ErrorHandler.toMessage(error);

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
      userRole: user?.role ?? state.userRole,
      requiresVehicleSetup: requiresVehicleSetup ?? auth.requiresVehicle,
      isLoading: false,
      sessionExpired: false,
      statusMessage: statusMessage,
    );
  }

}
