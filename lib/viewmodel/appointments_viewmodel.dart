import 'package:flutter/material.dart';
import '../services/local/appointment_db.dart';

class AppointmentsViewModel extends ChangeNotifier {
  final AppointmentsDb _db = AppointmentsDb.instance;

  List<Appointment> appointments = [];
  bool isLoading = false;
  int upcomingCount = 0;

  Future<void> loadUpcoming({int limit = 20}) async {
    isLoading = true;
    notifyListeners();

    appointments = await _db.getUpcomingAppointments(limit: limit);
    upcomingCount = await _db.getUpcomingAppointmentCount();

    isLoading = false;
    notifyListeners();
  }
}
