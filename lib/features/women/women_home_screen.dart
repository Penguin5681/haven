import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth/women_register_cubit.dart';
import 'auth/women_register_screen.dart';

class WomenHomeScreen extends StatelessWidget {
  const WomenHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Cubit lives here — survives back-navigation within the Women flow.
    return BlocProvider(
      create: (_) => WomenRegisterCubit(),
      child: const WomenRegisterScreen(),
    );
  }
}
