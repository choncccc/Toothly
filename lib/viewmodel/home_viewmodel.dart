import 'package:flutter/material.dart';
import 'package:toothly/views/create_case_view.dart';
import '../views/task_dashboard_view.dart';
import '../views/appointments_view.dart';
import '../views/clinical_cases_view.dart';
import '../services/local/profile_store.dart';

class HomeViewmodel extends ChangeNotifier {
  final _store = ProfileStore.instance;

  String user_type = 'Doc';
  String fName = 'Guest';
  String lName = '';
  String? avatarPath;
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

  HomeViewmodel() {
    _loadUserData();
  }

  Future<void> refresh() => _loadUserData();

  Future<void> _loadUserData() async {
    final first = _store.firstName;
    fName = first.isEmpty ? 'Guest' : first;
    lName = _store.lastName;
    avatarPath = _store.avatarPath;
    clinicLevel = _store.clinicLevel;
    casesCompleted = _store.casesCompleted;
    user_type = 'Doc';
    notifyListeners();
  }

  void onItemTapped(int index) {
    selectedIndex = index;
    notifyListeners();
  }
}
