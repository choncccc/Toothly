import 'package:flutter/material.dart';
import 'package:toothly/views/pdf_annotator_view.dart';

class _CaseItem {
  final String label;
  final String pdfPath;
  const _CaseItem(this.label, this.pdfPath);
}

class _CaseCard {
  final String title;
  final List<_CaseItem> items;
  const _CaseCard(this.title, this.items);
}

class CreateCaseView extends StatefulWidget {
  const CreateCaseView({super.key});

  @override
  State<CreateCaseView> createState() => _CreateCaseViewState();
}

class _CreateCaseViewState extends State<CreateCaseView> {
  static const List<_CaseCard> _cases = [
    _CaseCard('PEDIATRIC', [
      _CaseItem('ART Pedia (Check List)', 'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/Copy of ART-Pedia.pdf'),
      _CaseItem('PFS Pedia (Check List)', 'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PFS-Pedia (1).pdf'),
      _CaseItem('PRR Pedia (Check List)', 'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PRR-Pediaa.pdf'),
      _CaseItem('Space Maintainer (Live PX)', 'assets/pdf/PEDIA CHART/PEDIA (LIVE PX)/Pediatric-appliance-SPACE-MAINTAINER.pdf'),
    ]),
    _CaseCard('COMPLETE DENTURES', [
      _CaseItem('Patient Chart', 'assets/pdf/CD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet', 'assets/pdf/CD CHART/CD PATIENT SCORE SHEET.pdf'),
      _CaseItem('6 Hours Board Type Score Sheet', 'assets/pdf/CD CHART/CD 6 HOURS BOARD TYPE SCORE SHEET.pdf'),
      _CaseItem('Simu Exercise Score Sheet', 'assets/pdf/CD CHART/CD SIMU EXERCISE SCORE SHEET.pdf'),
    ]),
    _CaseCard('ENDODONTICS', [
      _CaseItem('Endodontics Simulation', 'assets/pdf/ENDO CHART/ENDO (SIMULATION)/ENDODONTICS-Simulation.pdf'),
      _CaseItem('Endodontic Form (Live PX)', 'assets/pdf/ENDO CHART/ENDO (LIVE PX)/Endodontic-form.pdf'),
      _CaseItem('Endodontic Case Recall', 'assets/pdf/ENDO CHART/ENDO (LIVE PX)/ENDODONTIC-CASE-RECALL.pdf'),
    ]),
    _CaseCard('EXODONTIA', [
      _CaseItem('Patient Form (Live PX)', 'assets/pdf/EXO CHART/EXO (LIVE PX)/Exodontia-patient-form.pdf'),
      _CaseItem('Surgery Instrument Check List', 'assets/pdf/EXO CHART/EXO (CHECK LIST)/Surgery-instrument-check-list-1.pdf'),
    ]),
    _CaseCard('FIXED PARTIAL DENTURE', [
      _CaseItem('Patient Chart', 'assets/pdf/FPD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet', 'assets/pdf/FPD CHART/FPD PATIENT SCORE SHEET.pdf'),
      _CaseItem('Simu Score Sheet', 'assets/pdf/FPD CHART/FPD SIMU SCORE SHEET.pdf'),
    ]),
    _CaseCard('REMOVABLE PARTIAL DENTURE', [
      _CaseItem('Patient Chart', 'assets/pdf/RPD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet', 'assets/pdf/RPD CHART/RPD PATIENT SCORE SHEET.pdf'),
      _CaseItem('Simu Score Sheet', 'assets/pdf/RPD CHART/RPD SIMU SCORE SHEET.pdf'),
    ]),
    _CaseCard('RESTORATIVE', [
      _CaseItem('Patient Form 2024', 'assets/pdf/RESTO CHART/Patient-Form-2024.pdf'),
      _CaseItem('Class I (Live PX)', 'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-I-LIVE-PX.pdf'),
      _CaseItem('Class II (Live PX)', 'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-II-LIVE-PX.pdf'),
      _CaseItem('Class III (Live PX)', 'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-III-LIVE-PX.pdf'),
      _CaseItem('Class IV (Live PX)', 'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-IV-LIVE-PX.pdf'),
      _CaseItem('Class V (Live PX)', 'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-V-LIVE-PX.pdf'),
      _CaseItem('Class I (Check List)', 'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-I-LIVE-PX.pdf'),
      _CaseItem('Class II (Check List)', 'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-II-LIVE-PX.pdf'),
      _CaseItem('Class III (Check List)', 'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-III-LIVE-PX.pdf'),
      _CaseItem('Class IV (Check List)', 'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-IV-LIVE-PX.pdf'),
      _CaseItem('Class V (Check List)', 'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-V-LIVE-PX.pdf'),
    ]),
    _CaseCard('PERIODONTICS', [
      _CaseItem('Perio Chart', 'assets/pdf/PERIO CHART/PERIO-CHART.pdf'),
      _CaseItem('Oral Prophylaxis', 'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/Oral-Prophylaxis-form-PX(1).pdf'),
      _CaseItem('Fluoride Application', 'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/FLUORIDE-APPLICATION(1).pdf'),
    ]),
  ];

  final Map<int, String> _selected = {};

  void _openPdf(BuildContext context, String label, String pdfPath,
      List<String> companions) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfAnnotatorView(
          title: label,
          editablePdfPath: pdfPath,
          companionPdfPaths: companions,
        ),
      ),
    );
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
        child: ListView.separated(
          itemCount: _cases.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final card = _cases[i];
            return _buildExpandableCard(
              title: _selected[i] ?? card.title,
              items: card.items,
              onSelected: (item) {
                setState(() => _selected[i] = item.label);
                final companions = card.items
                    .where((it) => it.pdfPath != item.pdfPath)
                    .map((it) => it.pdfPath)
                    .toList();
                _openPdf(context, item.label, item.pdfPath, companions);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required List<_CaseItem> items,
    required Function(_CaseItem) onSelected,
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
              title: Text(item.label, style: const TextStyle(color: Colors.white)),
              onTap: () => onSelected(item),
            );
          }).toList(),
        ),
      ),
    );
  }
}
