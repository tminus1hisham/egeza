import '../models/api_models.dart';
import '../models/parking_session.dart';
import '../models/vehicle.dart';

/// Seeded figures behind the sign-in screen's tenancy and owner demo buttons.
///
/// A demo session never reaches the backend, so everything the driver-facing
/// screens read out of [AppState] has to come from here. The manager side has
/// its own generator — see [ManagerSampleData] — which this only switches on.
///
/// Testing-only, and deliberately obvious: the tenant is called "Demo" and the
/// plates are not real registrations, so nothing here can be mistaken for a
/// live account's figures.
class DemoSessionData {
  const DemoSessionData._();

  static const tenantName = 'Demo Tenant';
  static const ownerName = 'Demo Owner';
  static const tenantPhoneNumber = '+254700000001';
  static const ownerPhoneNumber = '+254700000002';

  static const walletBalance = 2450.0;

  static const locations = <ParkingLocation>[
    ParkingLocation(
      id: 'demo-sarit',
      name: 'Sarit Centre',
      address: 'Sarit Centre, Westlands',
      ratePerHour: 60,
      maxCapacity: 300,
      currentOccupancy: 184,
    ),
    ParkingLocation(
      id: 'demo-cbd',
      name: 'Nairobi CBD Parking',
      address: 'Kimathi Street',
      ratePerHour: 50,
      maxCapacity: 250,
      currentOccupancy: 121,
    ),
  ];

  static const vehicles = <Vehicle>[
    Vehicle(
      id: 'demo-vehicle-1',
      plateNumber: 'KDG221M',
      type: 'Saloon',
      make: 'Toyota',
      model: 'Axio',
      autoPayEnabled: true,
    ),
    Vehicle(
      id: 'demo-vehicle-2',
      plateNumber: 'KBR656Z',
      type: 'SUV / 4x4',
      make: 'Mazda',
      model: 'CX-5',
    ),
  ];

  /// The tenant's own parking history, most recent first.
  static List<ParkingSession> recentSessions({DateTime? now}) {
    final at = now ?? DateTime.now();

    return [
      ParkingSession(
        id: 'demo-session-1',
        locationName: 'Sarit Centre',
        startTime: at.subtract(const Duration(hours: 3, minutes: 10)),
        endTime: at.subtract(const Duration(hours: 1, minutes: 40)),
        cost: 120,
        amountPaid: 120,
        durationMinutes: 90,
        ratePerHour: 60,
        billableHours: 2,
        status: 'COMPLETED',
        vehicle: vehicles.first,
        isActive: false,
      ),
      ParkingSession(
        id: 'demo-session-2',
        locationName: 'Nairobi CBD Parking',
        startTime: at.subtract(const Duration(days: 1, hours: 6)),
        endTime: at.subtract(const Duration(days: 1, hours: 3)),
        cost: 150,
        amountPaid: 150,
        durationMinutes: 180,
        ratePerHour: 50,
        billableHours: 3,
        status: 'COMPLETED',
        vehicle: vehicles.last,
        isActive: false,
      ),
      ParkingSession(
        id: 'demo-session-3',
        locationName: 'Sarit Centre',
        startTime: at.subtract(const Duration(days: 3, hours: 2)),
        endTime: at.subtract(const Duration(days: 3)),
        cost: 120,
        amountPaid: 120,
        durationMinutes: 120,
        ratePerHour: 60,
        billableHours: 2,
        status: 'COMPLETED',
        vehicle: vehicles.first,
        isActive: false,
      ),
    ];
  }

  static List<WalletTransaction> walletTransactions({DateTime? now}) {
    final at = now ?? DateTime.now();

    return [
      WalletTransaction(
        id: 'demo-txn-1',
        amount: 1000,
        type: 'TOPUP',
        status: 'COMPLETED',
        reference: 'DEMO1000A',
        description: 'M-Pesa top up',
        createdAt: at.subtract(const Duration(hours: 5)),
      ),
      WalletTransaction(
        id: 'demo-txn-2',
        amount: 120,
        type: 'PAYMENT',
        status: 'COMPLETED',
        reference: 'DEMO1001B',
        description: 'Parking — Sarit Centre',
        createdAt: at.subtract(const Duration(hours: 1, minutes: 40)),
      ),
      WalletTransaction(
        id: 'demo-txn-3',
        amount: 150,
        type: 'PAYMENT',
        status: 'COMPLETED',
        reference: 'DEMO1002C',
        description: 'Parking — Nairobi CBD Parking',
        createdAt: at.subtract(const Duration(days: 1, hours: 3)),
      ),
    ];
  }

  /// One paid-up tenancy and one waiting on payment, so the tab shows both the
  /// active state and the pay-now state without any tapping about.
  static List<TenantProfile> tenantProfiles({DateTime? now}) {
    final at = now ?? DateTime.now();

    return [
      TenantProfile(
        id: 'demo-tenant-1',
        name: 'Demo Tenant',
        clientId: 'demo-client-1',
        clientName: 'Sarit Centre Management',
        locationId: 'demo-sarit',
        locationName: 'Sarit Centre',
        allocatedSlots: 2,
        status: 'ACTIVE',
        paymentStatus: 'PAID',
        slotEnforcement: 'ALLOCATED_SLOTS',
        subscriptionFee: 12000,
        pricingPlanName: 'Monthly Tenant Parking',
        subscriptionStartDate: at.subtract(const Duration(days: 12)),
        subscriptionEndDate: at.add(const Duration(days: 18)),
        plateNumbers: const ['KDG221M', 'KBR656Z'],
        ownerId: 'demo-owner-1',
        ownerName: 'Sarit Centre Management',
        ownerPhoneNumber: ownerPhoneNumber,
      ),
      TenantProfile(
        id: 'demo-tenant-2',
        name: 'Demo Tenant',
        clientId: 'demo-client-2',
        clientName: 'CBD Parking Ltd',
        locationId: 'demo-cbd',
        locationName: 'Nairobi CBD Parking',
        allocatedSlots: 1,
        status: 'PENDING',
        paymentStatus: 'PENDING',
        slotEnforcement: 'ALLOCATED_SLOTS',
        subscriptionFee: 7500,
        pricingPlanName: 'Monthly Tenant Parking',
        subscriptionStartDate: at,
        subscriptionEndDate: at.add(const Duration(days: 30)),
        plateNumbers: const ['KBR656Z'],
        ownerId: 'demo-owner-2',
        ownerName: 'CBD Parking Ltd',
        ownerPhoneNumber: ownerPhoneNumber,
      ),
    ];
  }

  static List<TenancyRequest> tenancyRequests({DateTime? now}) {
    final at = now ?? DateTime.now();

    return [
      TenancyRequest(
        id: 'demo-request-1',
        requesterId: 'demo-user-1',
        requesterName: tenantName,
        locationId: 'demo-cbd',
        locationName: 'Nairobi CBD Parking',
        tenantName: tenantName,
        plateNumber: 'KBR656Z',
        message: 'Requesting one reserved slot for the CBD office.',
        status: 'PENDING',
        allocatedSlots: 1,
        subscriptionFee: 7500,
        pricingPlanName: 'Monthly Tenant Parking',
        slotEnforcement: 'ALLOCATED_SLOTS',
        subscriptionStartDate: at,
        subscriptionEndDate: at.add(const Duration(days: 30)),
        createdAt: at.subtract(const Duration(days: 2)),
      ),
    ];
  }
}
