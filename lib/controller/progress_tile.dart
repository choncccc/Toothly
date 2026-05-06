import 'package:flutter/material.dart';

class ProgressTile extends StatelessWidget {
  final String patientName;
  final String date;
  final String task;

  const ProgressTile({
    super.key,
    required this.patientName,
    required this.task,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        visualDensity: VisualDensity.compact,
        leading: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFB191FF),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: const Icon(Icons.calendar_today, color: Colors.white),
        ),
        title: Row(
          children: [
            Text(
              patientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF5D4B8A),
              ),
            ),
            const Spacer(),
            Text(
              date,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5D4B8A)),
            ),
          ],
        ),
        subtitle: Text(
          task,
          style: const TextStyle(fontSize: 14, color: Color(0xFF5D4B8A)),
        ),
        trailing: const Icon(Icons.more_vert),
      ),
    );
  }
}
