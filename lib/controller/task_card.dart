import 'package:flutter/material.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String doneTask;

  const TaskCard({super.key, required this.title, required this.doneTask});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB191FF), Color(0xFF8F6BFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFf7e4b0), width: 2.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "Roboto",
              fontSize: 20,
            ),
          ),
          Text(
            doneTask,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: "Roboto",
              fontSize: 34,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
