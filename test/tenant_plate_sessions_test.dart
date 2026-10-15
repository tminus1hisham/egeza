import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/api_models.dart';
import 'package:egesha/models/parking_session.dart';
import 'package:egesha/models/vehicle.dart';

void main() {
  // The bloc persists the account role on every state change; without the
  // binding that write throws into the log and buries the real output.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sessions for tenancy plates', () {
    test('finds the session for a tenant who owns no vehicle', () async {
      // The live shape of the tenant test account: GET /vehicles is empty and
      // the only car is a plate on the tenancy. Without the tenancy plates the
      // by-plate lookup has nothing to ask for and the tenant sees no parking.
      final api = _TenantFakeApi();
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(LoadDashboardData());

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.vehicles, 'vehicles', isEmpty)
              .having((s) => s.recentSessions.length, 'sessions', 1)
              .having((s) => s.recentSessions.first.id, 'id', 'tenancy-1'),
        ),
      );

      // Queried in the canonical gate spelling, not the tenancy's spaced form.
      expect(api.platesQueried, contains('KDS123A'));
      expect(api.platesQueried, isNot(contains('KDS 123A')));

      await bloc.close();
    });

    test('asks for each plate once across both load passes', () async {
      // The tenancies are unknown on a cold start, so the catch-up pass must
      // fetch only what the first pass missed.
      final api = _TenantFakeApi(
        vehicles: const [
          Vehicle(
            id: 'vehicle-1',
            plateNumber: 'KCY001A',
            type: 'Saloon',
            make: 'Toyota',
            model: 'Axio',
          ),
        ],
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(LoadDashboardData());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.recentSessions.length, 'sessions', 1),
        ),
      );

      expect(api.platesQueried, ['KCY001A', 'KDS123A']);

      await bloc.close();
    });

    test('the background poll watches the tenancy plate too', () async {
      final api = _TenantFakeApi();
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      // Seed the tenancies the way a completed load leaves them.
      bloc.add(LoadDashboardData());
      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>().having((s) => s.tenantProfiles, 'tenants', hasLength(1)),
        ),
      );
      api.platesQueried.clear();

      bloc.add(const StartSessionWatch(interval: Duration(milliseconds: 20)));
      await Future<void>.delayed(const Duration(milliseconds: 90));

      expect(api.platesQueried, contains('KDS123A'));

      bloc.add(StopSessionWatch());
      await bloc.close();
    });

    test('a cancelled tenancy is not polled', () async {
      final api = _TenantFakeApi(tenantStatus: 'CANCELLED');
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(LoadDashboardData());
      await expectLater(
        bloc.stream,
        emitsThrough(isA<AppState>().having((s) => s.isLoading, 'loading', isFalse)),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(api.platesQueried, isEmpty);
      expect(bloc.state.recentSessions, isEmpty);

      await bloc.close();
    });
  });
}

class _TenantFakeApi extends ParkingIqApi {
  _TenantFakeApi({
    this.vehicles = const [],
    this.tenantStatus = 'PENDING',
  }) : super(debug: false);

  final List<Vehicle> vehicles;
  final String tenantStatus;
  final List<String> platesQueried = [];

  @override
  bool get hasToken => true;

  @override
  Future<UserProfile> me() async => const UserProfile(
        id: 'user-1',
        phoneNumber: '254733333333',
        fullName: 'James Gathuru',
        role: 'TENANT',
      );

  @override
  Future<double> walletBalance() async => 0;

  @override
  Future<List<Vehicle>> listVehicles() async => vehicles;

  @override
  Future<List<ParkingLocation>> fetchParkingLocations() async =>
      const <ParkingLocation>[];

  @override
  Future<List<ParkingSession>> recentParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> activeParkingSessions() async =>
      const <ParkingSession>[];

  @override
  Future<List<ParkingSession>> parkingSessionsForPlate(
    String plateNumber,
  ) async {
    platesQueried.add(plateNumber);
    if (plateNumber != 'KDS123A') return const <ParkingSession>[];
    return [
      ParkingSession(
        id: 'tenancy-1',
        locationName: 'Sarit',
        startTime: DateTime.utc(2026, 9, 1, 7),
        cost: 50,
        status: 'ACTIVE',
        // The gates write the plate unspaced.
        vehicle: const Vehicle(
          plateNumber: 'KDS123A',
          type: 'Saloon',
          make: '',
          model: '',
        ),
        isActive: true,
      ),
    ];
  }

  @override
  Future<List<WalletTransaction>> walletTransactions() async =>
      const <WalletTransaction>[];

  @override
  Future<List<TenancyRequest>> fetchTenancyRequests() async =>
      const <TenancyRequest>[];

  @override
  Future<List<TenantProfile>> fetchMyTenantProfiles() async => [
        TenantProfile(
          id: 'tenant-1',
          name: 'Carrefour Limited',
          clientId: 'client-1',
          clientName: 'Sarit Center',
          locationId: 'location-1',
          locationName: 'Sarit',
          allocatedSlots: 2,
          status: tenantStatus,
          paymentStatus: 'OVERDUE',
          slotEnforcement: 'ALLOCATED_SLOTS',
          subscriptionFee: 5,
          pricingPlanName: 'Monthly Tenant Parking',
          // Spaced, exactly as the tenancy service returns it.
          plateNumbers: const ['KDS 123A'],
          ownerId: 'user-1',
          ownerName: 'James Gathuru',
          ownerPhoneNumber: '254733333333',
        ),
      ];
}
