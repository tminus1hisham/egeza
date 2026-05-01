class ParkingBillingQuote {
  final int durationMinutes;
  final int gracePeriodMinutes;
  final int ratePerHour;
  final int billableHours;
  final int amount;

  const ParkingBillingQuote({
    required this.durationMinutes,
    required this.gracePeriodMinutes,
    required this.ratePerHour,
    required this.billableHours,
    required this.amount,
  });
}

class ParkingBillingCalculator {
  const ParkingBillingCalculator._();

  static ParkingBillingQuote calculate({
    required DateTime entryTime,
    required DateTime currentTime,
    int gracePeriodMinutes = 3,
    int ratePerHour = 5,
  }) {
    final durationMinutes = currentTime.difference(entryTime).inMinutes;
    final elapsedMinutes = durationMinutes < 0 ? 0 : durationMinutes;
    final billableHours = elapsedMinutes <= gracePeriodMinutes
        ? 0
        : ((elapsedMinutes + 59) ~/ 60);

    return ParkingBillingQuote(
      durationMinutes: elapsedMinutes,
      gracePeriodMinutes: gracePeriodMinutes,
      ratePerHour: ratePerHour,
      billableHours: billableHours,
      amount: billableHours * ratePerHour,
    );
  }
}
