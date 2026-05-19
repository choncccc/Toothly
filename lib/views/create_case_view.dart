import 'package:flutter/material.dart';
import 'package:toothly/views/pdf_annotator_view.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

class _CaseItem {
  final String label;
  final String pdfPath;
  const _CaseItem(this.label, this.pdfPath);
}

class _CaseCard {
  final String title;
  final IconData icon;
  final List<_CaseItem> items;
  const _CaseCard(this.title, this.icon, this.items);
}

class CreateCaseView extends StatefulWidget {
  const CreateCaseView({super.key});

  @override
  State<CreateCaseView> createState() => _CreateCaseViewState();
}

class _CreateCaseViewState extends State<CreateCaseView> {
  static const List<_CaseCard> _cases = [
    _CaseCard('Pediatric', Icons.child_care_rounded, [
      _CaseItem('ART Pedia (Check List)',
          'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/Copy of ART-Pedia.pdf'),
      _CaseItem('PFS Pedia (Check List)',
          'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PFS-Pedia (1).pdf'),
      _CaseItem('PRR Pedia (Check List)',
          'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PRR-Pediaa.pdf'),
      _CaseItem('Space Maintainer (Live PX)',
          'assets/pdf/PEDIA CHART/PEDIA (LIVE PX)/Pediatric-appliance-SPACE-MAINTAINER.pdf'),
    ]),
    _CaseCard('Complete Dentures', Icons.face_rounded, [
      _CaseItem('Patient Chart', 'assets/pdf/CD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet',
          'assets/pdf/CD CHART/CD PATIENT SCORE SHEET.pdf'),
      _CaseItem('6 Hours Board Type Score Sheet',
          'assets/pdf/CD CHART/CD 6 HOURS BOARD TYPE SCORE SHEET.pdf'),
      _CaseItem('Simu Exercise Score Sheet',
          'assets/pdf/CD CHART/CD SIMU EXERCISE SCORE SHEET.pdf'),
    ]),
    _CaseCard('Endodontics', Icons.biotech_rounded, [
      _CaseItem('Endodontics Simulation',
          'assets/pdf/ENDO CHART/ENDO (SIMULATION)/ENDODONTICS-Simulation.pdf'),
      _CaseItem('Endodontic Form (Live PX)',
          'assets/pdf/ENDO CHART/ENDO (LIVE PX)/Endodontic-form.pdf'),
      _CaseItem('Endodontic Case Recall',
          'assets/pdf/ENDO CHART/ENDO (LIVE PX)/ENDODONTIC-CASE-RECALL.pdf'),
    ]),
    _CaseCard('Exodontia', Icons.medical_services_rounded, [
      _CaseItem('Patient Form (Live PX)',
          'assets/pdf/EXO CHART/EXO (LIVE PX)/Exodontia-patient-form.pdf'),
      _CaseItem('Surgery Instrument Check List',
          'assets/pdf/EXO CHART/EXO (CHECK LIST)/Surgery-instrument-check-list-1.pdf'),
    ]),
    _CaseCard('Fixed Partial Denture', Icons.dashboard_rounded, [
      _CaseItem('Patient Chart', 'assets/pdf/FPD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet',
          'assets/pdf/FPD CHART/FPD PATIENT SCORE SHEET.pdf'),
      _CaseItem('Simu Score Sheet',
          'assets/pdf/FPD CHART/FPD SIMU SCORE SHEET.pdf'),
    ]),
    _CaseCard('Removable Partial Denture', Icons.swap_horiz_rounded, [
      _CaseItem('Patient Chart', 'assets/pdf/RPD CHART/PATIENT CHART.pdf'),
      _CaseItem('Patient Score Sheet',
          'assets/pdf/RPD CHART/RPD PATIENT SCORE SHEET.pdf'),
      _CaseItem('Simu Score Sheet',
          'assets/pdf/RPD CHART/RPD SIMU SCORE SHEET.pdf'),
    ]),
    _CaseCard('Restorative', Icons.build_circle_rounded, [
      _CaseItem('Patient Form 2024',
          'assets/pdf/RESTO CHART/Patient-Form-2024.pdf'),
      _CaseItem('Class I (Live PX)',
          'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-I-LIVE-PX.pdf'),
      _CaseItem('Class II (Live PX)',
          'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-II-LIVE-PX.pdf'),
      _CaseItem('Class III (Live PX)',
          'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-III-LIVE-PX.pdf'),
      _CaseItem('Class IV (Live PX)',
          'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-IV-LIVE-PX.pdf'),
      _CaseItem('Class V (Live PX)',
          'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-V-LIVE-PX.pdf'),
      _CaseItem('Class I (Check List)',
          'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-I-LIVE-PX.pdf'),
      _CaseItem('Class II (Check List)',
          'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-II-LIVE-PX.pdf'),
      _CaseItem('Class III (Check List)',
          'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-III-LIVE-PX.pdf'),
      _CaseItem('Class IV (Check List)',
          'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-IV-LIVE-PX.pdf'),
      _CaseItem('Class V (Check List)',
          'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-V-LIVE-PX.pdf'),
    ]),
    _CaseCard('Periodontics', Icons.spa_rounded, [
      _CaseItem('Perio Chart', 'assets/pdf/PERIO CHART/PERIO-CHART.pdf'),
      _CaseItem('Oral Prophylaxis',
          'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/Oral-Prophylaxis-form-PX(1).pdf'),
      _CaseItem('Fluoride Application',
          'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/FLUORIDE-APPLICATION(1).pdf'),
    ]),
  ];

  String _query = '';

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

  List<_CaseCard> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _cases;
    final out = <_CaseCard>[];
    for (final c in _cases) {
      final hits = c.items
          .where((it) =>
              it.label.toLowerCase().contains(q) ||
              c.title.toLowerCase().contains(q))
          .toList();
      if (hits.isNotEmpty) {
        out.add(_CaseCard(c.title, c.icon, hits));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final cards = _filtered;
    final totalForms = _cases.fold<int>(0, (s, c) => s + c.items.length);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: const Text(
          'CREATE CASE',
          style: TextStyle(
            color: _primary,
            fontFamily: 'Derrick',
            fontSize: 22,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _IntroCard(
            categoryCount: _cases.length,
            totalForms: totalForms,
          ),
          const SizedBox(height: 16),
          _SearchField(
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          if (cards.isEmpty)
            const _EmptyResult()
          else
            for (int i = 0; i < cards.length; i++) ...[
              _CategoryCard(
                card: cards[i],
                onItemTap: (item) {
                  final original = _cases.firstWhere(
                      (c) => c.title == cards[i].title);
                  final companions = original.items
                      .where((it) => it.pdfPath != item.pdfPath)
                      .map((it) => it.pdfPath)
                      .toList();
                  _openPdf(context, item.label, item.pdfPath, companions);
                },
                startExpanded: _query.isNotEmpty,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

// =============================================================================
// Intro card
// =============================================================================
class _IntroCard extends StatelessWidget {
  final int categoryCount;
  final int totalForms;
  const _IntroCard(
      {required this.categoryCount, required this.totalForms});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purpleLight, _purpleDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _purpleDeep.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pick a form to start',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$categoryCount departments · $totalForms forms available',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Search field
// =============================================================================
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      cursorColor: _primary,
      style: const TextStyle(color: _primary),
      decoration: InputDecoration(
        hintText: 'Search forms or departments…',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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

// =============================================================================
// Category card (expandable)
// =============================================================================
class _CategoryCard extends StatefulWidget {
  final _CaseCard card;
  final void Function(_CaseItem) onItemTap;
  final bool startExpanded;

  const _CategoryCard({
    required this.card,
    required this.onItemTap,
    this.startExpanded = false,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late final AnimationController _ctrl;
  late final Animation<double> _rot;

  @override
  void initState() {
    super.initState();
    _expanded = widget.startExpanded;
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: _expanded ? 1 : 0,
    );
    _rot = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant _CategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startExpanded != oldWidget.startExpanded) {
      _expanded = widget.startExpanded;
      _expanded ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Header
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _toggle,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_purpleLight, _purpleDeep],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(widget.card.icon,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.card.title,
                            style: const TextStyle(
                              color: _primary,
                              fontFamily: 'Roboto',
                              fontSize: 17,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.card.items.length} '
                            '${widget.card.items.length == 1 ? "form" : "forms"}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    RotationTransition(
                      turns: _rot,
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Body
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: _expanded
                ? Column(
                    children: [
                      const Divider(
                          height: 1, color: _border, indent: 14, endIndent: 14),
                      for (int i = 0;
                          i < widget.card.items.length;
                          i++) ...[
                        _CaseItemTile(
                          item: widget.card.items[i],
                          onTap: () => widget.onItemTap(widget.card.items[i]),
                        ),
                        if (i < widget.card.items.length - 1)
                          const Divider(
                              height: 1,
                              color: _border,
                              indent: 60,
                              endIndent: 14),
                      ],
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _CaseItemTile extends StatelessWidget {
  final _CaseItem item;
  final VoidCallback onTap;
  const _CaseItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded,
                  color: _primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _primary, size: 14),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Empty search state
// =============================================================================
class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
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
            child: const Icon(Icons.search_off_rounded,
                color: _primary, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'No matching forms',
            style: TextStyle(
              color: _primary,
              fontFamily: 'Roboto',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try a different keyword.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
