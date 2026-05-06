import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodel/appointments_viewmodel.dart';
import '../services/local/appointment_db.dart'; // adjust path if needed

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  late PageController _pageController;
  late DateTime _currentDate;
  DateTime? _selectedDate;

  final AppointmentsDb _db = AppointmentsDb.instance;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _pageController = PageController(initialPage: 1000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getMonthForPage(int page) {
    final monthOffset = (page - 1000) * 2;
    return DateTime(_currentDate.year, _currentDate.month + monthOffset, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FF),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              "Appointments",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Derrick',
                letterSpacing: 1.1,
                color: Color(0xFF5D4B8A),
              ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) {
          final startMonth = _getMonthForPage(index);
          final nextMonth = DateTime(startMonth.year, startMonth.month + 1, 1);

          return LayoutBuilder(
            builder: (context, constraints) {
              final halfHeight = constraints.maxHeight / 2;

              return Column(
                children: [
                  SizedBox(
                    height: halfHeight,
                    child: _buildMonthCalendar(startMonth),
                  ),
                  const Divider(height: 1, thickness: 1),
                  SizedBox(
                    height: halfHeight - 1,
                    child: _buildMonthCalendar(nextMonth),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMonthCalendar(DateTime month) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final firstDayOfMonth = DateTime(month.year, month.month, 1);
        final startingWeekday = firstDayOfMonth.weekday % 7;

        // Total cells in the grid (empty + days)
        final totalCells = startingWeekday + daysInMonth;
        final weekCount = (totalCells + 6) ~/ 7; // ceil(totalCells / 7)

        const headerHeight = 56.0;
        const weekdayRowHeight = 24.0;
        const spacing = 24.0;

        final remainingHeight =
            constraints.maxHeight - headerHeight - weekdayRowHeight - spacing;

        final rowHeight = remainingHeight > 0
            ? remainingHeight / weekCount
            : 0.0;

        return Container(
          color: const Color(0xFFF8F9FF),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Text(
                _getMonthYearString(month),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Derrick',
                  color: Color(0xFF5D4B8A),
                ),
              ),
              const SizedBox(height: 8),

              // Weekday Headers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  height: weekdayRowHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        .map(
                          (day) => Expanded(
                            child: Text(
                              day,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Derrick',
                                color: Color(0xFF5D4B8A),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Calendar Grid (dynamic rowHeight)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _buildCalendarGrid(
                  month,
                  daysInMonth,
                  startingWeekday,
                  rowHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarGrid(
    DateTime month,
    int daysInMonth,
    int startingWeekday,
    double rowHeight,
  ) {
    List<Widget> dayWidgets = [];

    for (int i = 0; i < startingWeekday; i++) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isToday = _isToday(date);
      final isSelected =
          _selectedDate != null && _isSameDay(date, _selectedDate!);

      dayWidgets.add(
        Expanded(
          child: GestureDetector(
            onTap: () => _onDateSelected(date),
            child: Container(
              margin: const EdgeInsets.all(4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF5D4B8A)
                    : isToday
                    ? const Color(0xFF5D4B8A).withOpacity(0.2)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$day',
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : isToday
                      ? const Color(0xFF5D4B8A)
                      : Colors.black,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    while (dayWidgets.length % 7 != 0) {
      dayWidgets.add(const Expanded(child: SizedBox()));
    }

    List<Widget> rows = [];
    for (int i = 0; i < dayWidgets.length; i += 7) {
      rows.add(
        SizedBox(
          height: rowHeight,
          child: Row(children: dayWidgets.sublist(i, i + 7)),
        ),
      );
    }

    return Column(children: rows);
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
    });

    final appointments = await _db.getAppointmentsForDate(date);
    if (!mounted) return;

    _showAppointmentsBottomSheet(date, appointments);
  }

  void _showAppointmentsBottomSheet(
    DateTime date,
    List<Appointment> initialAppointments,
  ) {
    final titleController = TextEditingController();
    final notesController = TextEditingController();
    TimeOfDay? selectedTime;
    List<Appointment> appointments = List.of(initialAppointments);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickTime() async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime ?? TimeOfDay.now(),
                );
                if (picked != null) {
                  setModalState(() {
                    selectedTime = picked;
                  });
                }
              }

              Future<void> saveAppointment() async {
                final title = titleController.text.trim();
                final notes = notesController.text.trim();

                if (title.isEmpty) return;

                final appt = Appointment(
                  date: date,
                  title: title,
                  notes: notes.isEmpty ? null : notes,
                  time: selectedTime != null
                      ? selectedTime!.format(context)
                      : null,
                );

                final id = await _db.insertAppointment(appt);
                final saved = appt.copyWith(id: id);

                setModalState(() {
                  appointments.add(saved);
                  titleController.clear();
                  notesController.clear();
                  selectedTime = null;
                });

                if (mounted) {
                  context.read<AppointmentsViewModel>().loadUpcoming();
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Appointments for ${_formatFullDate(date)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontFamily: 'Derrick',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4B8A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (appointments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          'No appointments yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appt = appointments[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(appt.title),
                            subtitle: (appt.time != null || appt.notes != null)
                                ? Text(
                                    [
                                      if (appt.time != null) appt.time!,
                                      if (appt.notes != null) appt.notes!,
                                    ].join(' • '),
                                  )
                                : null,
                          );
                        },
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Patient Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Details'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          selectedTime != null
                              ? 'Time: ${selectedTime!.format(context)}'
                              : 'No time selected',
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: pickTime,
                          child: const Text('Pick time'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5D4B8A),
                        ),
                        onPressed: saveAppointment,
                        child: const Text(
                          'Save appointment',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getMonthYearString(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final weekdayName = weekdays[date.weekday - 1];
    final monthName = months[date.month - 1];

    return '$weekdayName, $monthName ${date.day}, ${date.year}';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}
