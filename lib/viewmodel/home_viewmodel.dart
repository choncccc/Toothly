import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:toothly/views/create_case_view.dart';
import '../views/task_dashboard_view.dart';
import '../views/appointments_view.dart';

class HomeViewmodel extends ChangeNotifier {
  final supabase = Supabase.instance.client;

  String user_type = '';
  String fName = 'Guest';
  int selectedIndex = 0;

  List<Widget> pages = const [
    const TaskDashboardPage(),
    const CreateCaseView(),
    Center(child: Text("Draw Page - Coming Soon!")),
    const AppointmentsView(),
  ];

  HomeViewmodel() {
    _loadUserData();
  }

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
        .select('first_name, user_type')
        .eq('id', user.id)
        .maybeSingle();

    if (response != null) {
      fName = response['first_name'] ?? user.email ?? 'Guest';

      // User type prefix
      final type = response['user_type'];
      user_type = type == 'teacher'
          ? 'Prof.'
          : type == 'student'
          ? 'Dentist'
          : '';
    } else {
      fName = user.userMetadata?['first_name'] ?? user.email ?? 'Guest';
      user_type = '';
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
