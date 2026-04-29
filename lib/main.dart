import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/theme/app_theme.dart';
import 'blocs/app_bloc.dart';
import 'screens/onboarding/create_account_screen.dart';

void main() {
  runApp(const ParkIQApp());
}

class ParkIQApp extends StatelessWidget {
  const ParkIQApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppBloc>(
          create: (context) => AppBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'Park IQ',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const CreateAccountScreen(),
      ),
    );
  }
}
