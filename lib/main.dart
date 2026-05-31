import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'views/onboarding_view.dart';
import 'views/home_view.dart';
import 'views/create_case_view.dart';

import 'viewmodel/home_viewmodel.dart';
import 'viewmodel/appointments_viewmodel.dart';
import 'services/notification_service.dart';
import 'services/local/profile_store.dart';
import 'services/local/appointment_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ProfileStore.instance.init();
  await NotificationService.instance.init();

  // Reschedule reminders for any locally-stored upcoming appointments.
  try {
    final appointments =
        await AppointmentsDb.instance.getUpcomingAppointments();
    await NotificationService.instance.scheduleAll(appointments);
  } catch (_) {}

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewmodel()),
        ChangeNotifierProvider(
          create: (_) => AppointmentsViewModel()..loadUpcoming(),
        ),
      ],
      child: MaterialApp(
        title: 'Toothly',
        initialRoute: '/',
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF8F9FF),
          inputDecorationTheme: const InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18.0)),
              borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18.0)),
              borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(18.0)),
              borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
          ),
        ),
        routes: {
          '/': (context) => const AppGate(),
          '/onboarding': (context) => const OnboardingView(),
          '/home': (context) => const HomeView(),
          '/create-case': (context) => const CreateCaseView(),
        },
      ),
    );
  }
}

/// Shows onboarding on first launch, otherwise goes straight to the app.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileStore.instance.onboardingComplete
        ? const HomeView()
        : const OnboardingView();
  }
}
