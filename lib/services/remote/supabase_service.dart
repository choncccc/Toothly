import 'package:supabase_flutter/supabase_flutter.dart';
import '../local/appointment_db.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  final _client = Supabase.instance.client;

  Future<void> insertAppointment(Appointment appt) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('appointments').insert({
      'user_id': userId,
      'date': Appointment.dateKey(appt.date),
      'title': appt.title,
      'notes': appt.notes,
      'time': appt.time,
      'case_type': appt.caseType,
    });
  }

  Future<List<Appointment>> fetchUpcomingAppointments() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final today = Appointment.dateKey(DateTime.now());

    final result = await _client
        .from('appointments')
        .select()
        .eq('user_id', userId)
        .gte('date', today)
        .order('date');

    return (result as List).map((e) => Appointment.fromMap(e)).toList();
  }
}
