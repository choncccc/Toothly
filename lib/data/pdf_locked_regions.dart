import 'package:flutter/widgets.dart' show Rect;

/// Read-only zones on a form's **first page** that the user must not draw, paint,
/// erase, or place text over — the patient-identifying field
/// ("Patient's Card/Control Number"). The client assigns this per user, so it
/// stays blank/protected on the chart.
///
/// Rectangles are normalised to the page (left/top/right/bottom as fractions of
/// page width/height, 0..1). Only page 1 is protected; the date field beside it
/// is intentionally left writable.
///
/// To add or tweak a region, change the rect for the matching asset path. The
/// path must exactly match the `editablePdfPath` passed to the annotator.
const Map<String, Rect> _kFirstPageLocks = {
  r'assets/pdf/CD CHART/PATIENT CHART.pdf': Rect.fromLTRB(
    0.1667,
    0.131,
    0.6602,
    0.1545,
  ),
  r'assets/pdf/CD CHART/CD PATIENT SCORE SHEET.pdf': Rect.fromLTRB(
    0.1079,
    0.1677,
    0.66,
    0.1895,
  ),
  r'assets/pdf/ENDO CHART/ENDO (LIVE PX)/Endodontic-form.pdf': Rect.fromLTRB(
    0.1117,
    0.1652,
    0.7243,
    0.1891,
  ),
  r'assets/pdf/ENDO CHART/ENDO (LIVE PX)/ENDODONTIC-CASE-RECALL.pdf':
      Rect.fromLTRB(0.1117, 0.2466, 0.6259, 0.2737),
  r'assets/pdf/EXO CHART/EXO (LIVE PX)/Exodontia-patient-form.pdf':
      Rect.fromLTRB(0.1079, 0.1895, 0.66, 0.2114),
  r'assets/pdf/FPD CHART/PATIENT CHART.pdf': Rect.fromLTRB(
    0.1667,
    0.131,
    0.6602,
    0.1545,
  ),
  r'assets/pdf/FPD CHART/FPD PATIENT SCORE SHEET.pdf': Rect.fromLTRB(
    0.1079,
    0.2317,
    0.662,
    0.2525,
  ),
  r'assets/pdf/RPD CHART/PATIENT CHART.pdf': Rect.fromLTRB(
    0.1667,
    0.131,
    0.6602,
    0.1545,
  ),
  r'assets/pdf/RPD CHART/RPD PATIENT SCORE SHEET.pdf': Rect.fromLTRB(
    0.1079,
    0.1675,
    0.6531,
    0.1883,
  ),
  r'assets/pdf/RESTO CHART/Patient-Form-2024.pdf': Rect.fromLTRB(
    0.1667,
    0.131,
    0.6602,
    0.1545,
  ),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-I-LIVE-PX.pdf': Rect.fromLTRB(
    0.049,
    0.1838,
    0.6963,
    0.2073,
  ),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-II-LIVE-PX.pdf': Rect.fromLTRB(
    0.049,
    0.1838,
    0.6963,
    0.2073,
  ),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-III-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-IV-LIVE-PX.pdf': Rect.fromLTRB(
    0.049,
    0.1838,
    0.6963,
    0.2073,
  ),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-V-LIVE-PX.pdf': Rect.fromLTRB(
    0.049,
    0.1838,
    0.6963,
    0.2073,
  ),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-I-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-II-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-III-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-IV-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-V-LIVE-PX.pdf':
      Rect.fromLTRB(0.049, 0.1838, 0.6963, 0.2073),
  r'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/Copy of ART-Pedia.pdf':
      Rect.fromLTRB(0.0545, 0.2166, 0.6593, 0.2428),
  r'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PFS-Pedia (1).pdf': Rect.fromLTRB(
    0.0545,
    0.2171,
    0.6593,
    0.2434,
  ),
  r'assets/pdf/PEDIA CHART/PEDIA (CHECK LIST)/PRR-Pediaa.pdf': Rect.fromLTRB(
    0.0529,
    0.1950,
    0.6413,
    0.2198,
  ),
  r'assets/pdf/PEDIA CHART/PEDIA (LIVE PX)/Pediatric-appliance-SPACE-MAINTAINER.pdf':
      Rect.fromLTRB(0.1706, 0.1606, 0.7829, 0.1854),
  r'assets/pdf/PERIO CHART/PERIO-CHART.pdf': Rect.fromLTRB(
    0.1667,
    0.1534,
    0.7189,
    0.1769,
  ),
  r'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/Oral-Prophylaxis-form-PX(1).pdf':
      Rect.fromLTRB(0.1667, 0.1766, 0.7188, 0.2001),
  r'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/FLUORIDE-APPLICATION(1).pdf':
      Rect.fromLTRB(0.1667, 0.1692, 0.7183, 0.1927),
};

/// Normalised locked rectangles for [assetPath] on [page] (1-based). Returns an
/// empty list when nothing is protected on that page.
List<Rect> lockedRegionsForPage(String assetPath, int page) {
  if (page != 1) return const [];
  final r = _kFirstPageLocks[assetPath];
  return r == null ? const [] : [r];
}
