import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

import '../models/parking_session.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class LoadDashboardData extends AppEvent {}

class ClearAppMessages extends AppEvent {}

class ClearParkingSelection extends AppEvent {}

class SignOut extends AppEvent {}

class RequestLoginOtp extends AppEvent {
  final String phoneNumber;

  const RequestLoginOtp(this.phoneNumber);

  @override
  List<Object?> get props => [phoneNumber];
}

class SignInWithOtp extends AppEvent {
  final String phoneNumber;
  final String otp;

  const SignInWithOtp({
    required this.phoneNumber,
    required this.otp,
  });

  @override
  List<Object?> get props => [phoneNumber, otp];
}

class RegisterAccount extends AppEvent {
  final String phoneNumber;
  final String otp;
  final String fullName;
  final String idNumber;
  final String county;
  final String? email;

  const RegisterAccount({
    required this.phoneNumber,
    required this.otp,
    required this.fullName,
    required this.idNumber,
    required this.county,
    this.email,
  });

  @override
  List<Object?> get props => [
        phoneNumber,
        otp,
        fullName,
        idNumber,
        county,
        email,
      ];
}

class AddVehicle extends AppEvent {
  final String plateNumber;
  final String type;
  final String make;
  final String model;
  final bool autoPayEnabled;

  const AddVehicle({
    required this.plateNumber,
    required this.type,
    required this.make,
    required this.model,
    this.autoPayEnabled = false,
  });

  @override
  List<Object?> get props => [
        plateNumber,
        type,
        make,
        model,
        autoPayEnabled,
      ];
}

/// Starts the periodic wallet-balance poll. Safe to add repeatedly — an
/// already-running watch is restarted rather than duplicated.
class StartWalletBalanceWatch extends AppEvent {
  final Duration interval;

  const StartWalletBalanceWatch({
    this.interval = const Duration(seconds: 15),
  });

  @override
  List<Object?> get props => [interval];
}

class StopWalletBalanceWatch extends AppEvent {}

/// Emitted by the watcher when the backend reports a different balance.
class WalletBalanceUpdated extends AppEvent {
  final double balance;

  const WalletBalanceUpdated(this.balance);

  @override
  List<Object?> get props => [balance];
}

/// Starts the periodic parking-session poll that keeps the home screen live.
///
/// Sessions are created by the gate cameras, not by this app, so a car that
/// drives in has to *arrive* on the dashboard by itself. Same REST-only story
/// as the wallet balance — no socket channel to subscribe to.
/// Safe to add repeatedly: an already-running watch is restarted, not doubled.
class StartSessionWatch extends AppEvent {
  final Duration interval;

  const StartSessionWatch({
    this.interval = const Duration(seconds: 20),
  });

  @override
  List<Object?> get props => [interval];
}

class StopSessionWatch extends AppEvent {}

/// Emitted by the watcher when the merged session list actually changed.
class SessionsUpdated extends AppEvent {
  final List<ParkingSession> sessions;

  const SessionsUpdated(this.sessions);

  @override
  List<Object?> get props => [sessions];
}

class TopUpWallet extends AppEvent {
  final double amount;
  final String? phoneNumber;

  const TopUpWallet(this.amount, {this.phoneNumber});

  @override
  List<Object?> get props => [amount, phoneNumber];
}

class EndParkingSession extends AppEvent {
  final String sessionId;

  const EndParkingSession(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class FindParkingSession extends AppEvent {
  final String plateNumber;

  const FindParkingSession(this.plateNumber);

  @override
  List<Object?> get props => [plateNumber];
}

class PayParkingSession extends AppEvent {
  final String sessionId;
  final bool useWallet;
  final String? phoneNumber;
  final double? amount;
  final String? plateNumber;
  final String? location;
  final String? promoCode;

  const PayParkingSession({
    required this.sessionId,
    this.useWallet = true,
    this.phoneNumber,
    this.amount,
    this.plateNumber,
    this.location,
    this.promoCode,
  });

  @override
  List<Object?> get props => [
        sessionId,
        useWallet,
        phoneNumber,
        amount,
        plateNumber,
        location,
        promoCode,
      ];
}

/// Redeem a promo code against a session that AutoPay will settle.
///
/// Unlike [PayParkingSession] this never opens an M-Pesa prompt: the promo
/// either clears the bill outright or shaves it down and leaves the remainder
/// to AutoPay.
class ApplySessionPromo extends AppEvent {
  final String sessionId;
  final String code;

  const ApplySessionPromo({
    required this.sessionId,
    required this.code,
  });

  @override
  List<Object?> get props => [sessionId, code];
}

class SetVehicleAutoPay extends AppEvent {
  final String? vehicleId;
  final String plateNumber;
  final bool enabled;

  const SetVehicleAutoPay({
    required this.vehicleId,
    required this.plateNumber,
    required this.enabled,
  });

  @override
  List<Object?> get props => [vehicleId, plateNumber, enabled];
}

class RemoveVehicle extends AppEvent {
  final String? vehicleId;
  final String plateNumber;

  const RemoveVehicle({
    required this.vehicleId,
    required this.plateNumber,
  });

  @override
  List<Object?> get props => [vehicleId, plateNumber];
}

/// Debug-only: forces the app to show the driver side or the manager side,
/// regardless of the signed-in account's role. Pass null to drop the override
/// and follow the real role again.
///
/// This moves what the *app* offers, never what the *API* allows — a forced
/// manager view on a driver account still gets 403s from `/manager/*` and lands
/// on the "no sites assigned" state.
class SetDebugManagerMode extends AppEvent {
  final bool? enabled;

  const SetDebugManagerMode(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

/// Debug-only: fills the manager view with generated figures instead of calling
/// the API, so the layout can be looked at without a manager account or a live
/// site behind it. The screen badges every sample reading as such.
class SetDebugSampleData extends AppEvent {
  final bool enabled;

  const SetDebugSampleData(this.enabled);

  @override
  List<Object?> get props => [enabled];
}

class ChangeThemeMode extends AppEvent {
  final ThemeMode themeMode;

  const ChangeThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

/// Testing-only: signs in as a seeded tenant or property owner without an
/// access token, so either side of the app can be walked through before the
/// matching account exists in the backend.
///
/// [role] is `'tenant'` or `'owner'`. Nothing is written to prefs and no token
/// reaches the API client — closing the app ends the demo session.
class StartDemoSession extends AppEvent {
  final String role;

  const StartDemoSession(this.role);

  @override
  List<Object?> get props => [role];
}
