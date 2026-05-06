import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Appointment {
  final int? id;
  final DateTime date;
  final String title;
  final String? notes;
  final String? time;

  Appointment({
    this.id,
    required this.date,
    required this.title,
    this.notes,
    this.time,
  });

  Appointment copyWith({
    int? id,
    DateTime? date,
    String? title,
    String? notes,
    String? time,
  }) {
    return Appointment(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      time: time ?? this.time,
    );
  }

  static String dateKey(DateTime d) =>
      DateTime(d.year, d.month, d.day).toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': dateKey(date),
      'title': title,
      'notes': notes,
      'time': time,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      title: map['title'] as String,
      notes: map['notes'] as String?,
      time: map['time'] as String?,
    );
  }
}

class AppointmentsDb {
  AppointmentsDb._();
  static final AppointmentsDb instance = AppointmentsDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final path = join(docsDir.path, 'appointments.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE appointments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT,
            time TEXT
          )
        ''');
      },
    );
  }

  Future<List<Appointment>> getAppointmentsForDate(DateTime date) async {
    final db = await database;
    final dateStr = Appointment.dateKey(date);
    final result = await db.query(
      'appointments',
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: 'time ASC, id ASC',
    );
    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  Future<List<Appointment>> getUpcomingAppointments({int limit = 20}) async {
    final db = await database;

    // today at midnight
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final result = await db.query(
      'appointments',
      where: 'date >= ?',
      whereArgs: [today],
      orderBy: 'date ASC, time ASC, id ASC',
      limit: limit,
    );

    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  Future<int> insertAppointment(Appointment appt) async {
    final db = await database;
    return db.insert('appointments', appt.toMap());
  }

  Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getUpcomingAppointmentCount() async {
    final db = await database;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM appointments WHERE date >= ?',
      [today],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }
}
