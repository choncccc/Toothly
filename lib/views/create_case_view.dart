import 'package:flutter/material.dart';

class CreateCaseView extends StatefulWidget {
  const CreateCaseView({super.key});

  @override
  State<CreateCaseView> createState() => _CreateCaseViewState();
}

class _CreateCaseViewState extends State<CreateCaseView> {
  String? selectedCD;
  String? selectedCD2;
  String? selectedPriority;
  String? selectedStatus;

  final List<String> items = ["Patient", "Simulation"];

  late final List<String> completeDentures;
  late final List<String> priorities;
  late final List<String> statuses;

  @override
  void initState() {
    super.initState();
    completeDentures = items;
    priorities = items;
    statuses = items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FF),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Text(
            "Create Case",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Derrick',
              letterSpacing: 1.1,
              color: Color(0xFF5D4B8A),
            ),
          ),
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          // ✅ prevent overflow
          children: [
            _buildExpandableCard(
              title: selectedCD ?? "ART PEDIATRIC",
              items: items,
              onSelected: (val) => setState(() => selectedCD = val),
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: selectedCD2 ?? "COMPLETE DENTURES",
              items: items,
              onSelected: (val) => setState(() => selectedCD2 = val),
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: selectedPriority ?? "ENDODONTIC CASE",
              items: items,
              onSelected: (val) => setState(() => selectedPriority = val),
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: selectedStatus ?? "EXODONTIA FORM",
              items: items,
              onSelected: (val) => setState(() => selectedStatus = val),
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: "FIXED RESTORATION",
              items: items,
              onSelected: (_) {},
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: "FLUORIDE APPLICATION",
              items: items,
              onSelected: (_) {},
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: "PFS PEDIATRIC CASE",
              items: items,
              onSelected: (_) {},
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: "PRR PEDIATRIC CASES",
              items: items,
              onSelected: (_) {},
            ),

            const SizedBox(height: 12),

            _buildExpandableCard(
              title: "ORAL PROPHYLAXIS",
              items: items,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required List<String> items,
    required Function(String) onSelected,
  }) {
    return Card(
      elevation: 5,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFF7E4B0), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB191FF), Color(0xFF8F6BFF)],
          ),
        ),
        child: ExpansionTile(
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontFamily: "Derrick",
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white,
          children: items.map((item) {
            return ListTile(
              title: Text(item, style: const TextStyle(color: Colors.white)),
              onTap: () => onSelected(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}
