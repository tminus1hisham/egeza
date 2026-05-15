import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'core/user_prefs.dart';
import 'blocs/app_bloc.dart';
import 'blocs/app_state.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final saved = await UserPrefs.load();

  ThemeMode initialThemeMode = ThemeMode.system;
  if (saved.theme == 'light') initialThemeMode = ThemeMode.light;
  if (saved.theme == 'dark') initialThemeMode = ThemeMode.dark;

  runApp(
    egeshaApp(
      initialUserName: saved.name,
      initialPhoneNumber: saved.phone,
      initialAuthToken: saved.token,
      initialThemeMode: initialThemeMode,
    ),
  );
}

class egeshaApp extends StatelessWidget {
  final String? initialUserName;
  final String? initialPhoneNumber;
  final String? initialAuthToken;
  final ThemeMode initialThemeMode;

  const egeshaApp({
    super.key,
    this.initialUserName,
    this.initialPhoneNumber,
    this.initialAuthToken,
    this.initialThemeMode = ThemeMode.system,
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
            initialThemeMode: initialThemeMode,
          ),
        ),
      ],
      child: BlocBuilder<AppBloc, AppState>(
        buildWhen: (previous, current) =>
            previous.themeMode != current.themeMode,
        builder: (context, state) {
          return MaterialApp(
            title: 'Park IQ',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
