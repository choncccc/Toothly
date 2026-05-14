import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toothly/viewmodel/auth_viewmodel.dart';

import '../viewmodel/home_viewmodel.dart';
import '../viewmodel/appointments_viewmodel.dart';
import '../controller/task_card.dart';
import '../controller/progress_tile.dart';

class TaskDashboardPage extends StatelessWidget {
  const TaskDashboardPage({super.key});

  String _formatApptDate(DateTime date, String? time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'June',
      'July',
      'Aug',
      'Sept',
      'Oct',
      'Nov',
      'Dec',
    ];
    final formatted = '${date.day} ${months[date.month - 1]}';
    return (time == null || time.isEmpty) ? formatted : '$formatted • $time';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeViewmodel>();
    final apptVM = context.watch<AppointmentsViewModel>();

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const SizedBox(width: 10),
            Text(
              "Hello, ${("${controller.user_type} ${controller.fName}").trim()}!",
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
        actions: [
          Consumer<AuthViewModel>(
            builder: (context, authVM, child) {
              return IconButton(
                icon: authVM.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, color: Color(0xFF5D4B8A)),
                onPressed: authVM.isLoading
                    ? null
                    : () async {
                        await authVM.logout(context);
                      },
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Container(
                  height: 180,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFB191FF), Color(0xFF8F6BFF)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFf7e4b0),
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "CASE COMPLETED:",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: "Derrick",
                          fontSize: 20,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        controller.casesCompleted.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: "Derrick",
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Spacer(),

                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF5D4B8A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            context.read<HomeViewmodel>().onItemTapped(1);
                          },
                          child: const Text(
                            "Add Case",
                            style: TextStyle(
                              fontFamily: "Derrick",
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: screenWidth * 0.9,
                child: Row(
                  children: [
                    Expanded(
                      child: TaskCard(
                        title: "APPOINTMENTS",
                        doneTask: apptVM.upcomingCount.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Upcoming Appointments",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Derrick',
                    color: Color(0xFF5D4B8A),
                  ),
                ),
              ),

              const SizedBox(height: 5),

              SizedBox(
                height: 475,
                child: apptVM.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : apptVM.appointments.isEmpty
                    ? const Center(
                        child: Text(
                          "No upcoming appointments.",
                          style: TextStyle(
                            color: Color(0xFF5D4B8A),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => apptVM.loadUpcoming(),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: apptVM.appointments.length,
                          itemBuilder: (context, index) {
                            final a = apptVM.appointments[index];
                            return ProgressTile(
                              patientName: a.title,
                              task: a.notes ?? '',
                              date: _formatApptDate(a.date, a.time),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
