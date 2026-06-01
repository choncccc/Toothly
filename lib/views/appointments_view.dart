import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/local/appointment_db.dart';
import '../services/notification_service.dart';
import '../viewmodel/appointments_viewmodel.dart';
import '../widgets/animations.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

const _caseTypes = [
  'PEDIATRIC',
  'COMPLETE DENTURES',
  'ENDODONTICS',
  'EXODONTIA',
  'FIXED PARTIAL DENTURE',
  'REMOVABLE PARTIAL DENTURE',
  'RESTORATIVE',
  'PERIODONTICS',
];

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  final _db = AppointmentsDb.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<Appointment>> _eventsByDay = {};
  List<Appointment> _selectedDayAppointments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dayOnly(_focusedDay);
    _loadMonth(_focusedDay);
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMonth(DateTime month) async {
    setState(() => _loading = true);
    final start = DateTime(month.year, month.month - 1, 1);
    final end = DateTime(month.year, month.month + 2, 0);
    final all = await _db.getAppointmentsInRange(start, end);
    final map = <DateTime, List<Appointment>>{};
    for (final a in all) {
      final key = _dayOnly(a.date);
      map.putIfAbsent(key, () => []).add(a);
    }
    if (!mounted) return;
    setState(() {
      _eventsByDay = map;
      _selectedDayAppointments = map[_dayOnly(_selectedDay)] ?? [];
      _loading = false;
    });
  }

  List<Appointment> _eventsFor(DateTime day) =>
      _eventsByDay[_dayOnly(day)] ?? const [];

  Future<void> _selectDay(DateTime selected, DateTime focused) async {
    setState(() {
      _selectedDay = _dayOnly(selected);
      _focusedDay = focused;
      _selectedDayAppointments = _eventsFor(_selectedDay);
    });
  }

  Future<void> _onPageChanged(DateTime focused) async {
    _focusedDay = focused;
    await _loadMonth(focused);
  }

  void _jumpToday() {
    final today = DateTime.now();
    setState(() {
      _focusedDay = today;
      _selectedDay = _dayOnly(today);
      _selectedDayAppointments = _eventsFor(_selectedDay);
    });
  }

  Future<void> _openAddSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AddAppointmentSheet(date: _selectedDay),
    );
    if (mounted) {
      await _loadMonth(_focusedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: const Text(
          'SCHEDULE',
          style: TextStyle(
            color: _primary,
            fontFamily: 'Derrick',
            fontSize: 22,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _jumpToday,
              icon: const Icon(Icons.today_rounded, size: 18, color: _primary),
              label: const Text(
                'Today',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () => _loadMonth(_focusedDay),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _CalendarCard(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              eventsFor: _eventsFor,
              onDaySelected: _selectDay,
              onPageChanged: _onPageChanged,
            ),
            const SizedBox(height: 18),
            _DayHeader(date: _selectedDay,
                count: _selectedDayAppointments.length),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: _primary),
                ),
              )
            else if (_selectedDayAppointments.isEmpty)
              const _EmptyDayCard()
            else
              for (final (i, a) in _selectedDayAppointments.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideIn(
                    key: ValueKey(a.id ?? '${a.title}_$i'),
                    delay: Duration(milliseconds: (i * 60).clamp(0, 360)),
                    child: _AppointmentRow(appt: a),
                  ),
                ),
            const SizedBox(height: 16),
            _AddButton(onPressed: _openAddSheet),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Calendar card
// =============================================================================
class _CalendarCard extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<Appointment> Function(DateTime) eventsFor;
  final void Function(DateTime selected, DateTime focused) onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  const _CalendarCard({
    required this.focusedDay,
    required this.selectedDay,
    required this.eventsFor,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _purpleDeep.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TableCalendar<Appointment>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (d) => isSameDay(d, selectedDay),
        eventLoader: eventsFor,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        availableGestures: AvailableGestures.horizontalSwipe,
        availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        rowHeight: 44,
        daysOfWeekHeight: 28,
        headerStyle: const HeaderStyle(
          titleCentered: true,
          formatButtonVisible: false,
          titleTextStyle: TextStyle(
            color: _primary,
            fontFamily: 'Roboto',
            fontSize: 18,
            letterSpacing: 0.6,
          ),
          leftChevronIcon:
              Icon(Icons.chevron_left_rounded, color: _primary, size: 28),
          rightChevronIcon:
              Icon(Icons.chevron_right_rounded, color: _primary, size: 28),
          headerPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: const TextStyle(color: _primary),
          weekendTextStyle: const TextStyle(color: _primary),
          todayDecoration: BoxDecoration(
            color: _border,
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.bold,
          ),
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_purpleLight, _purpleDeep],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          markerDecoration: const BoxDecoration(
            color: Color(0xFFE53935),
            shape: BoxShape.circle,
          ),
          markersAlignment: Alignment.bottomCenter,
          markerSize: 5,
          markersOffset: const PositionedOffset(bottom: 4),
        ),
      ),
    );
  }
}

// =============================================================================
// Day header + supporting widgets
// =============================================================================
class _DayHeader extends StatelessWidget {
  final DateTime date;
  final int count;
  const _DayHeader({required this.date, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            _formatLong(date),
            style: const TextStyle(
              color: _primary,
              fontFamily: 'Roboto',
              fontSize: 18,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _border,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count appt${count == 1 ? "" : "s"}',
            style: const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static String _formatLong(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    const weekdays = [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }
}

class _EmptyDayCard extends StatelessWidget {
  const _EmptyDayCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: _primary, size: 26),
          ),
          const SizedBox(height: 10),
          const Text(
            'Nothing scheduled',
            style: TextStyle(
              color: _primary,
              fontFamily: 'Roboto',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap “Add appointment” to book one.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Appointment appt;
  const _AppointmentRow({required this.appt});

  @override
  Widget build(BuildContext context) {
    final hasTime = appt.time != null && appt.time!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_purpleLight, _purpleDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appt.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (appt.caseType != null && appt.caseType!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    appt.caseType!,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (appt.notes != null && appt.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    appt.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (hasTime) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 13, color: _primary),
                      const SizedBox(width: 4),
                      Text(
                        appt.time!,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purpleDeep.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            'Add appointment',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purpleDeep,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _gold, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Add appointment sheet
// =============================================================================
class _AddAppointmentSheet extends StatefulWidget {
  final DateTime date;
  const _AddAppointmentSheet({required this.date});

  @override
  State<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<_AddAppointmentSheet> {
  final _titleCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  TimeOfDay? _time;
  String? _caseType;
  bool _saving = false;

  final _db = AppointmentsDb.instance;

  @override
  void dispose() {
    _titleCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _time ?? TimeOfDay.now();
    var temp = DateTime(now.year, now.month, now.day, initial.hour, initial.minute);

    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const Text(
                  'Select time',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    TimeOfDay(hour: temp.hour, minute: temp.minute),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: _purpleDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 1, color: _border),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: false,
                initialDateTime: temp,
                onDateTimeChanged: (dt) => temp = dt,
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final title = _titleCtl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient name is required')),
      );
      return;
    }
    setState(() => _saving = true);
    final appt = Appointment(
      date: widget.date,
      title: title,
      notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      time: _time != null ? _format12h(_time!) : null,
      caseType: _caseType,
    );
    final id = await _db.insertAppointment(appt);
    final saved = appt.copyWith(id: id);
    NotificationService.instance.scheduleReminder(saved).ignore();
    if (!mounted) return;
    context.read<AppointmentsViewModel>().loadUpcoming();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'New appointment',
                style: TextStyle(
                  color: _primary,
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatLong(widget.date),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _FieldLabel('Patient name'),
              _RoundedField(
                controller: _titleCtl,
                hint: 'e.g. Juan Dela Cruz',
              ),
              const SizedBox(height: 14),
              _FieldLabel('Case type'),
              _CaseTypeDropdown(
                value: _caseType,
                onChanged: (v) => setState(() => _caseType = v),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Notes'),
              _RoundedField(
                controller: _notesCtl,
                hint: 'Anything to remember…',
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              _FieldLabel('Time'),
              _TimePickerRow(
                time: _time,
                onPick: _pickTime,
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_rounded, color: Colors.white),
                  label: const Text(
                    'Save appointment',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purpleDeep,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _gold, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatLong(DateTime d) {
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    const weekdays = [
      'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday',
    ];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 6, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: _primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _RoundedField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _RoundedField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      cursorColor: _primary,
      style: const TextStyle(color: _primary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purpleDeep, width: 1.5),
        ),
      ),
    );
  }
}

class _CaseTypeDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _CaseTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            'Select case type',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _primary),
          style: const TextStyle(color: _primary, fontSize: 14),
          dropdownColor: Colors.white,
          items: _caseTypes
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Text(c),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// Formats a [TimeOfDay] as a 12-hour string (e.g. `9:05 AM`), independent of
/// the device's 24-hour setting.
String _format12h(TimeOfDay t) {
  final period = t.hour < 12 ? 'AM' : 'PM';
  var hour = t.hour % 12;
  if (hour == 0) hour = 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

class _TimePickerRow extends StatelessWidget {
  final TimeOfDay? time;
  final VoidCallback onPick;
  const _TimePickerRow({required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, color: _primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  sizeFactor: anim,
                  axis: Axis.vertical,
                  child: child,
                ),
              ),
              child: Text(
                time != null ? _format12h(time!) : 'Not set',
                key: ValueKey(time == null ? 'none' : '${time!.hour}:${time!.minute}'),
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(
              foregroundColor: _purpleDeep,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(time != null ? 'Change' : 'Pick'),
          ),
        ],
      ),
    );
  }
}
