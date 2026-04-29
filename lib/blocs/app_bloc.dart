import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_event.dart';
import 'app_state.dart';
import '../models/vehicle.dart';
import '../models/parking_session.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc() : super(const AppState()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<AddVehicle>(_onAddVehicle);
    on<TopUpWallet>(_onTopUpWallet);
    on<EndParkingSession>(_onEndParkingSession);
  }

  void _onLoadDashboardData(LoadDashboardData event, Emitter<AppState> emit) {
    emit(state.copyWith(isLoading: true));

    final vehicle1 = const Vehicle(
      plateNumber: 'KBZ 123A',
      type: 'SUV 4×4',
      make: 'Toyota',
      model: 'Prado',
      autoPayEnabled: true,
    );

    final vehicle2 = const Vehicle(
      plateNumber: 'KBC 456B',
      type: 'SUV',
      make: 'Honda',
      model: 'CR-V',
      autoPayEnabled: false,
    );

    final mockSessions = [
      ParkingSession(
        id: '1',
        locationName: 'Garden City Mall',
        startTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 43)),
        endTime: DateTime.now().subtract(const Duration(minutes: 2)),
        cost: 180.0,
        vehicle: vehicle1,
        isActive: false,
      ),
      ParkingSession(
        id: '2',
        locationName: 'Two Rivers Mall',
        startTime: DateTime.now().subtract(const Duration(days: 1, hours: 2, minutes: 35)),
        endTime: DateTime.now().subtract(const Duration(days: 1)),
        cost: 290.0,
        vehicle: vehicle2,
        isActive: false,
      ),
      ParkingSession(
        id: '3',
        locationName: 'Westgate Shopping Centre',
        startTime: DateTime.now().subtract(const Duration(days: 2, hours: 1, minutes: 30)),
        endTime: DateTime.now().subtract(const Duration(days: 2)),
        cost: 150.0,
        vehicle: vehicle1,
        isActive: false,
      ),
    ];


    emit(state.copyWith(
      vehicles: [vehicle1, vehicle2],
      recentSessions: mockSessions,
      isLoading: false,
    ));
  }

  void _onAddVehicle(AddVehicle event, Emitter<AppState> emit) {
    final newVehicle = Vehicle(
      plateNumber: event.plateNumber,
      type: event.type,
      make: event.make,
      model: event.model,
    );
    emit(state.copyWith(vehicles: [...state.vehicles, newVehicle]));
  }

  void _onTopUpWallet(TopUpWallet event, Emitter<AppState> emit) {
    emit(state.copyWith(walletBalance: state.walletBalance + event.amount));
  }

  void _onEndParkingSession(EndParkingSession event, Emitter<AppState> emit) {
    final updatedSessions = state.recentSessions.map((session) {
      if (session.id == event.sessionId) {
        return ParkingSession(
          id: session.id,
          locationName: session.locationName,
          startTime: session.startTime,
          endTime: DateTime.now(),
          cost: session.cost,
          vehicle: session.vehicle,
          isActive: false,
        );
      }
      return session;
    }).toList();

    emit(state.copyWith(recentSessions: updatedSessions));
  }
}
