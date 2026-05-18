import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:toothly/views/create_case_view.dart';
import '../views/task_dashboard_view.dart';
import '../views/appointments_view.dart';
import '../views/clinical_cases_view.dart';
import '../services/case_sync_service.dart';

class HomeViewmodel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String user_type = '';
  String fName = 'Guest';
  String clinicLevel = '';
  int casesCompleted = 0;
  int selectedIndex = 0;

  // Getter (not a field) so hot reload picks up new entries without needing a
  // full restart — field initializers only run when the instance is created.
  List<Widget> get pages => const [
        TaskDashboardPage(),
        CreateCaseView(),
        ClinicalCasesView(),
        AppointmentsView(),
      ];

  StreamSubscription<int>? _syncSub;

  HomeViewmodel() {
    _loadUserData();
    _syncSub = CaseSyncService.instance.onSynced.listen((_) {
      _loadUserData();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _loadUserData();

  Future<void> _loadUserData() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      fName = 'Guest';
      user_type = '';
      notifyListeners();
      return;
    }

    final response = await supabase
        .from('profiles')
        .select('first_name, user_type, cases_completed, year')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      fName = response['first_name'] ?? user.email ?? 'Guest';

      final type = response['user_type'];
      user_type = type == 'teacher'
          ? 'Prof.'
          : type == 'student'
          ? 'Dentist'
          : '';

      casesCompleted = (response['cases_completed'] as int?) ?? 0;
      clinicLevel = (response['year'] as String?) ?? '';
    } else {
      fName = user.userMetadata?['first_name'] ?? user.email ?? 'Guest';
      user_type = '';
      casesCompleted = 0;
      clinicLevel = '';
    }

    notifyListeners();
  }

  void onItemTapped(int index) {
    selectedIndex = index;
    notifyListeners();
  }

  void _showToast(String msg, Color color) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: color,
      textColor: Colors.white,
    );
  }
}
