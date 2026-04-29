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
    
    // Simulate loading data
    final mockVehicle = Vehicle(
      plateNumber: 'KBZ 123A',
      type: 'Sedan',
      make: 'Honda',
      model: 'Civic',
      autoPayEnabled: true,
    );
    
    final mockSessions = [
      ParkingSession(
        id: '1',
        locationName: 'Sarit Centre Parking',
        startTime: DateTime.now().subtract(const Duration(hours: 3, minutes: 30)),
        cost: 150.0,
        vehicle: mockVehicle,
        isActive: true,
      ),
      ParkingSession(
        id: '2',
        locationName: 'Westgate Mall',
        startTime: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        endTime: DateTime.now().subtract(const Duration(days: 1)),
        cost: 200.0,
        vehicle: mockVehicle,
        isActive: false,
      ),
    ];

    emit(state.copyWith(
      vehicles: [mockVehicle],
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
