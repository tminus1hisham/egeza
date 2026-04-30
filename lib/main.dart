import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/user_prefs.dart';
import 'blocs/app_bloc.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saved = await UserPrefs.load();
  runApp(ParkIQApp(
    initialUserName: saved.name,
    initialPhoneNumber: saved.phone,
    initialAuthToken: saved.token,
  ));
}

class ParkIQApp extends StatelessWidget {
  final String? initialUserName;
  final String? initialPhoneNumber;
  final String? initialAuthToken;

  const ParkIQApp({
    super.key,
    this.initialUserName,
    this.initialPhoneNumber,
    this.initialAuthToken,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (context) => AppBloc(
            initialUserName: initialUserName,
            initialPhoneNumber: initialPhoneNumber,
            initialAuthToken: initialAuthToken,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Park IQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
