import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

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
  final String location;
  final String? locationId;

  const FindParkingSession(
    this.plateNumber, {
    required this.location,
    this.locationId,
  });

  @override
  List<Object?> get props => [plateNumber, location, locationId];
}

class PayParkingSession extends AppEvent {
  final String sessionId;
  final bool useWallet;
  final String? phoneNumber;
  final double? amount;
  final String? plateNumber;
  final String? location;

  const PayParkingSession({
    required this.sessionId,
    this.useWallet = true,
    this.phoneNumber,
    this.amount,
    this.plateNumber,
    this.location,
  });

  @override
  List<Object?> get props => [
        sessionId,
        useWallet,
        phoneNumber,
        amount,
        plateNumber,
        location,
      ];
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

class ChangeThemeMode extends AppEvent {
  final ThemeMode themeMode;

  const ChangeThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}
