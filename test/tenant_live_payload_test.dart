import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:egesha/core/api/parking_iq_api.dart';
import 'package:egesha/models/vehicle.dart';

/// Captured verbatim from the live API for the tenant test account
/// (254733333333) on 2026-09-01. This is the shape that was reported as
/// "the vehicle is in the API but not in the app": the tenancy carries the
/// plate, and the user's own vehicle collection is empty.
const _myProfilesBody = '''
{
 "status": "success",
 "data": [
  {
   "id": "51ff8e55-b54e-46a8-92d1-82ace939d77d",
   "name": "Carrefour Limited",
   "clientId": "0d65020b-1b3d-46f0-9254-a0857eaeddf6",
   "clientName": "Sarit Center",
   "locationId": "2ce5e02f-2805-4fae-a200-12befccd3c83",
   "locationName": "Sarit",
   "allocatedSlots": 2,
   "status": "PENDING",
   "paymentStatus": "OVERDUE",
   "slotEnforcement": "ALLOCATED_SLOTS",
   "subscriptionFee": 5.0,
   "pricingPlanName": "Monthly Tenant Parking",
   "subscriptionStartDate": "2026-05-14T00:00:00",
   "subscriptionEndDate": "2026-06-12T00:00:00",
   "subscriptionId": "1e9b6415-258b-4bd6-9fba-d95ff3957e9d",
   "plateNumbers": ["KDS 123A"],
   "ownerId": "e0cd801e-53da-4e5d-b891-0966840fb05f",
   "ownerName": "James Gathuru",
   "ownerPhoneNumber": "254733333333",
   "apiKey": "tpk_redacted"
  }
 ],
 "message": "Tenancy profiles loaded"
}
''';

const _vehiclesBody =
    '{"status":"success","data":[],"message":"Vehicles loaded"}';

ParkingIqApi _api() {
  return ParkingIqApi(
    token: 'test-token',
    debug: false,
    client: MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/tenancy/my-profiles':
          return http.Response(_myProfilesBody, 200);
        case '/api/v1/vehicles':
          return http.Response(_vehiclesBody, 200);
      }
      return http.Response('{"status":"error"}', 404);
    }),
  );
}

void main() {
  group('live tenant payload', () {
    test('carries the tenancy plate through to the profile', () async {
      final profiles = await _api().fetchMyTenantProfiles();

      expect(profiles, hasLength(1));
      expect(profiles.single.name, 'Carrefour Limited');
      expect(profiles.single.locationName, 'Sarit');
      expect(profiles.single.plateNumbers, ['KDS 123A']);
    });

    test('the user owns no vehicles of their own', () async {
      expect(await _api().listVehicles(), isEmpty);
    });

    test('a PENDING/OVERDUE tenancy still surfaces its plate', () async {
      final profile = (await _api().fetchMyTenantProfiles()).single;

      // The plate must not be gated on the tenancy being paid up — this
      // account is PENDING/OVERDUE and still has a car on site.
      expect(profile.status, 'PENDING');
      expect(profile.paymentStatus, 'OVERDUE');
      expect(profile.plateNumbers, isNotEmpty);
    });

    test('the tenancy spells the plate spaced, ANPR does not', () {
      // The tenancy holds 'KDS 123A'; gate cameras write 'KDS123A'. Anything
      // matching these two sources has to go through plateKey().
      expect(Vehicle.plateKey('KDS 123A'), 'KDS123A');
      expect('KDS 123A' == 'KDS123A', isFalse);
    });
  });
}
