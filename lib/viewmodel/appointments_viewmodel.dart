import 'package:flutter/material.dart';
import '../services/local/appointment_db.dart';
import '../services/remote/supabase_service.dart';

class AppointmentsViewModel extends ChangeNotifier {
  final AppointmentsDb _db = AppointmentsDb.instance;

  List<Appointment> appointments = [];
  bool isLoading = false;
  int upcomingCount = 0;

  Future<void> loadUpcoming({int limit = 20}) async {
    isLoading = true;
    notifyListeners();

    // Best-effort pull from Supabase so appointments created on another
    // device show up here. Failures (offline, signed out) just fall through
    // to the local DB read below.
    try {
      final remote = await SupabaseService.instance.fetchUpcomingAppointments();
      for (final a in remote) {
        await _db.insertIfMissing(a);
      }
    } catch (_) {}

    appointments = await _db.getUpcomingAppointments(limit: limit);
    upcomingCount = await _db.getUpcomingAppointmentCount();

    isLoading = false;
    notifyListeners();
  }
}
