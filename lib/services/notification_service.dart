import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'local/appointment_db.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'appointment_reminders';
  static const _channelName = 'Appointment Reminders';

  Future<void> init() async {
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleReminder(Appointment appt) async {
    final reminderTime = _reminderDateTime(appt);
    if (reminderTime == null || reminderTime.isBefore(DateTime.now())) return;

    final tzTime = tz.TZDateTime.from(reminderTime, tz.local);

    await _plugin.zonedSchedule(
      _notifId(appt),
      'Appointment Tomorrow',
      '${appt.title}'
          '${appt.time != null ? " at ${appt.time}" : ""}'
          '${appt.caseType != null ? " · ${appt.caseType}" : ""}',
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders for upcoming dental appointments',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleAll(List<Appointment> appointments) async {
    for (final appt in appointments) {
      await scheduleReminder(appt);
    }
  }

  Future<void> cancelReminder(Appointment appt) async {
    await _plugin.cancel(_notifId(appt));
  }

  DateTime? _reminderDateTime(Appointment appt) {
    final apptDate = DateTime(appt.date.year, appt.date.month, appt.date.day);
    final dayBefore = apptDate.subtract(const Duration(days: 1));

    if (appt.time != null) {
      final parsed = _parseTime(appt.time!);
      if (parsed != null) {
        return DateTime(
            dayBefore.year, dayBefore.month, dayBefore.day, parsed.$1, parsed.$2);
      }
    }
    return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 8, 0);
  }

  (int, int)? _parseTime(String time) {
    final match =
        RegExp(r'(\d+):(\d+)\s*(AM|PM)', caseSensitive: false).firstMatch(time);
    if (match == null) return null;
    int hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final isPm = match.group(3)!.toUpperCase() == 'PM';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return (hour, minute);
  }

  static int _notifId(Appointment appt) =>
      (Appointment.dateKey(appt.date) + appt.title).hashCode.abs() % 2147483647;
}
