import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class Appointment {
  final int? id;
  final DateTime date;
  final String title;
  final String? notes;
  final String? time;
  final String? caseType;

  Appointment({
    this.id,
    required this.date,
    required this.title,
    this.notes,
    this.time,
    this.caseType,
  });

  Appointment copyWith({
    int? id,
    DateTime? date,
    String? title,
    String? notes,
    String? time,
    String? caseType,
  }) {
    return Appointment(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      time: time ?? this.time,
      caseType: caseType ?? this.caseType,
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
      'case_type': caseType,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as int?,
      date: DateTime.parse(map['date'] as String),
      title: map['title'] as String,
      notes: map['notes'] as String?,
      time: map['time'] as String?,
      caseType: map['case_type'] as String?,
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

    final db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE appointments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT NOT NULL,
            title TEXT NOT NULL,
            notes TEXT,
            time TEXT,
            case_type TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'ALTER TABLE appointments ADD COLUMN case_type TEXT');
        }
      },
    );

    // Defensive: ensure case_type column exists for installs that skipped the migration
    try {
      await db.execute('ALTER TABLE appointments ADD COLUMN case_type TEXT');
    } catch (_) {}

    return db;
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

  Future<List<Appointment>> getAppointmentsInRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'appointments',
      where: 'date >= ? AND date <= ?',
      whereArgs: [Appointment.dateKey(start), Appointment.dateKey(end)],
      orderBy: 'date ASC, time ASC, id ASC',
    );
    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  Future<int> insertAppointment(Appointment appt) async {
    final db = await database;
    return db.insert('appointments', appt.toMap());
  }

  /// Inserts only if no local row matches on (date, title, time). Used to
  /// merge server-side appointments into the local DB without duplicating
  /// the ones already created on this device.
  Future<void> insertIfMissing(Appointment appt) async {
    final db = await database;
    final dateStr = Appointment.dateKey(appt.date);
    final whereClauses = <String>['date = ?', 'title = ?'];
    final args = <Object?>[dateStr, appt.title];
    if (appt.time == null) {
      whereClauses.add('time IS NULL');
    } else {
      whereClauses.add('time = ?');
      args.add(appt.time);
    }
    final existing = await db.query(
      'appointments',
      where: whereClauses.join(' AND '),
      whereArgs: args,
      limit: 1,
    );
    if (existing.isEmpty) {
      final map = appt.toMap()..remove('id');
      await db.insert('appointments', map);
    }
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
