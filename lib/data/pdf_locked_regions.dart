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
    0.1079,
    0.1528,
    0.95,
    0.1737,
  ),
  r'assets/pdf/ENDO CHART/ENDO (LIVE PX)/ENDODONTIC-CASE-RECALL.pdf':
      Rect.fromLTRB(0.1079, 0.2463, 0.95, 0.2741),
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

/// Where the auto-generated case number is stamped on a form's first page: the
/// blank just after the "…Control Number:" label. All values are normalised to
/// the page (0..1).
class CaseStampAnchor {
  /// Left edge of the stamped text.
  final double x;

  /// Vertical centre of the stamped text.
  final double centerY;

  /// Text height as a fraction of page height (used to scale the font).
  final double height;

  const CaseStampAnchor(this.x, this.centerY, this.height);
}

const Map<String, CaseStampAnchor> _kCaseStampAnchors = {
  r'assets/pdf/CD CHART/PATIENT CHART.pdf': CaseStampAnchor(
    0.4151,
    0.1427,
    0.0128,
  ),
  r'assets/pdf/CD CHART/CD PATIENT SCORE SHEET.pdf': CaseStampAnchor(
    0.4242,
    0.1786,
    0.0119,
  ),
  r'assets/pdf/ENDO CHART/ENDO (LIVE PX)/Endodontic-form.pdf': CaseStampAnchor(
    0.7914,
    0.1632,
    0.0109,
  ),
  r'assets/pdf/ENDO CHART/ENDO (LIVE PX)/ENDODONTIC-CASE-RECALL.pdf':
      CaseStampAnchor(0.4211, 0.2602, 0.0152),
  r'assets/pdf/EXO CHART/EXO (LIVE PX)/Exodontia-patient-form.pdf':
      CaseStampAnchor(0.4242, 0.2004, 0.0119),
  r'assets/pdf/FPD CHART/PATIENT CHART.pdf': CaseStampAnchor(
    0.4151,
    0.1427,
    0.0128,
  ),
  r'assets/pdf/FPD CHART/FPD PATIENT SCORE SHEET.pdf': CaseStampAnchor(
    0.3993,
    0.2421,
    0.0109,
  ),
  r'assets/pdf/RPD CHART/PATIENT CHART.pdf': CaseStampAnchor(
    0.4151,
    0.1427,
    0.0128,
  ),
  r'assets/pdf/RPD CHART/RPD PATIENT SCORE SHEET.pdf': CaseStampAnchor(
    0.3993,
    0.1779,
    0.0109,
  ),
  r'assets/pdf/RESTO CHART/Patient-Form-2024.pdf': CaseStampAnchor(
    0.4151,
    0.1427,
    0.0128,
  ),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-I-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-II-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-III-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-IV-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (LIVE PX)/CLASS-V-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-I-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-II-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-III-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-IV-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/RESTO CHART/RESTO (CHECK LIST)/Copy of CLASS-V-LIVE-PX.pdf':
      CaseStampAnchor(0.3654, 0.1956, 0.0128),
  r'assets/pdf/PERIO CHART/PERIO-CHART.pdf': CaseStampAnchor(
    0.4831,
    0.1652,
    0.0128,
  ),
  r'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/Oral-Prophylaxis-form-PX(1).pdf':
      CaseStampAnchor(0.4831, 0.1884, 0.0128),
  r'assets/pdf/PERIO CHART/PERIO (CHECK LIST)/FLUORIDE-APPLICATION(1).pdf':
      CaseStampAnchor(0.4824, 0.181, 0.0128),
};

/// Anchor for the case-number stamp on [assetPath] page [page] (1-based), or
/// null when this form/page has no patient field to stamp.
CaseStampAnchor? caseStampAnchorForPage(String assetPath, int page) {
  if (page != 1) return null;
  return _kCaseStampAnchors[assetPath];
}
