import 'package:flutter_test/flutter_test.dart';
import 'package:egesha/blocs/app_bloc.dart';
import 'package:egesha/blocs/app_event.dart';
import 'package:egesha/blocs/app_state.dart';
import 'package:egesha/core/api/parking_iq_api.dart';

void main() {
  group('AppBloc wallet balance watch', () {
    test('emits the new balance when the backend value changes', () async {
      final api = _WalletBalanceFakeApi([1000, 1000, 2500]);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartWalletBalanceWatch(
        interval: Duration(milliseconds: 20),
      ));

      await expectLater(
        bloc.stream,
        emitsThrough(
          isA<AppState>()
              .having((s) => s.walletBalance, 'balance', 2500)
              // A background poll must never flip loading or message state.
              .having((s) => s.isLoading, 'isLoading', isFalse)
              .having((s) => s.statusMessage, 'statusMessage', isNull)
              .having((s) => s.errorMessage, 'errorMessage', isNull),
        ),
      );

      bloc.add(StopWalletBalanceWatch());
      await bloc.close();
    });

    test('stops polling once the token is rejected', () async {
      final api = _WalletBalanceFakeApi(
        const [],
        error: const ApiException('Forbidden', statusCode: 403),
      );
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartWalletBalanceWatch(
        interval: Duration(milliseconds: 20),
      ));

      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.callCount, 1);
      expect(bloc.state.walletBalance, 0);

      await bloc.close();
    });

    test('stop cancels further polling', () async {
      final api = _WalletBalanceFakeApi(const [500]);
      final bloc = AppBloc(api: api, initialAuthToken: 'token');

      bloc.add(const StartWalletBalanceWatch(
        interval: Duration(milliseconds: 20),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(StopWalletBalanceWatch());
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final callsAtStop = api.callCount;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(api.callCount, callsAtStop);

      await bloc.close();
    });
  });
}

class _WalletBalanceFakeApi extends ParkingIqApi {
  _WalletBalanceFakeApi(this._balances, {this.error}) : super(debug: false);

  final List<double> _balances;
  final Object? error;
  int callCount = 0;

  @override
  bool get hasToken => true;

  @override
  Future<double> walletBalance() async {
    callCount++;
    if (error != null) throw error!;
    // Holds the last value once the scripted sequence runs out.
    final index = callCount - 1;
    return _balances[index < _balances.length ? index : _balances.length - 1];
  }
}
