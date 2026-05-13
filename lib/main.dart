import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:toothly/viewmodel/auth_viewmodel.dart';

import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/home_view.dart';
import 'views/create_case_view.dart';

import 'viewmodel/home_viewmodel.dart';
import 'viewmodel/appointments_viewmodel.dart';
import 'services/notification_service.dart';
import 'services/remote/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null || supabaseAnonKey == null) {
    throw Exception("Missing SUPABASE_URL or SUPABASE_ANON_KEY in .env");
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  await NotificationService.instance.init();

  // Schedule reminders for existing appointments if already logged in
  if (Supabase.instance.client.auth.currentSession != null) {
    try {
      final appointments =
          await SupabaseService.instance.fetchUpcomingAppointments();
      await NotificationService.instance.scheduleAll(appointments);
    } catch (_) {}
  }

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

        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
          child: const MyApp(),
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
          '/': (context) => const AuthGate(),
          '/register': (context) => const RegisterView(),
          '/home': (context) => const HomeView(),
          '/create-case': (context) => const CreateCaseView(),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (session != null) {
          return const HomeView();
        } else {
          return const LoginView();
        }
      },
    );
  }
}
