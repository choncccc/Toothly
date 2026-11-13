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
  // 2026 charting set (assets/NEW CHARTING 2026) — patient (PX) forms.
  r'assets/NEW CHARTING 2026/ENDODONTICS/ENDODONTICS PX CHART/Endodontic-form.pdf':
      Rect.fromLTRB(0.1117, 0.1652, 0.7243, 0.1891),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-III-LIVE-PX.pdf':
      Rect.fromLTRB(0.0528, 0.1832, 0.7001, 0.2080),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-II-LIVE-PX.pdf':
      Rect.fromLTRB(0.0528, 0.1832, 0.7001, 0.2080),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-I-LIVE-PX.pdf':
      Rect.fromLTRB(0.0528, 0.1832, 0.7001, 0.2080),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-IV-LIVE-PX.pdf':
      Rect.fromLTRB(0.0528, 0.1832, 0.7001, 0.2080),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-V-LIVE-PX.pdf':
      Rect.fromLTRB(0.0528, 0.1832, 0.7001, 0.2080),
  r'assets/NEW CHARTING 2026/ORAL SURGERY/Exodontia-patient-form.pdf':
      Rect.fromLTRB(0.1117, 0.1885, 0.6638, 0.2124),
  r'assets/NEW CHARTING 2026/PEDIATRIC/ART PEDIA.pdf':
      Rect.fromLTRB(0.0544, 0.2277, 0.6584, 0.2540),
  r'assets/NEW CHARTING 2026/PEDIATRIC/FLUORIDE APPLICATION PEDIA.pdf':
      Rect.fromLTRB(0.1705, 0.1913, 0.7220, 0.2161),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PFS PEDIA.pdf':
      Rect.fromLTRB(0.0544, 0.2288, 0.6584, 0.2550),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PRR PEDIA.pdf':
      Rect.fromLTRB(0.0528, 0.2042, 0.6411, 0.2291),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PULP THERAPHY PEDIA.pdf':
      Rect.fromLTRB(0.1116, 0.2253, 0.7236, 0.2524),
  r'assets/NEW CHARTING 2026/PEDIATRIC/SPACE MAINTAINER PEDIA.pdf':
      Rect.fromLTRB(0.1705, 0.1827, 0.7824, 0.2075),
  r'assets/NEW CHARTING 2026/PERIODONTICS/Oral-Prophylaxis-form-PX.pdf':
      Rect.fromLTRB(0.1706, 0.1759, 0.7226, 0.2008),
  r'assets/NEW CHARTING 2026/PERIODONTICS/PERIO CHART.pdf':
      Rect.fromLTRB(0.1705, 0.1566, 0.7220, 0.1814),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/COMPLETE DENTURE/CD PX CHART/CD-patient-form.pdf':
      Rect.fromLTRB(0.1117, 0.1667, 0.6638, 0.1906),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/FIXED PARTIAL DENTURE/FPD PX CHART/Fixed-restoration-patient-1.pdf':
      Rect.fromLTRB(0.1117, 0.2307, 0.6658, 0.2536),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/REMOVABLE PARTIAL DENTURE/RPD PX CHART/RPD-patient-form.pdf':
      Rect.fromLTRB(0.1117, 0.1664, 0.6569, 0.1893),

};

/// Normalised locked rectangles for [assetPath] on [page] (1-based). Returns an
/// empty list when nothing is protected on that page.
List<Rect> lockedRegionsForPage(String assetPath, int page) {
  if (page != 1) return const [];
  final r = _kFirstPageLocks[assetPath];
  return r == null ? const [] : [r];
}

/// Where the issued card/control number is written on a form's first page: the
/// blank underline after the "Patient's Card/Control Number:" label. `left` and
/// `right` are the ends of the underline and `bottom` is its height on the page,
/// so the number sits on the line rather than over the label. `top` is
/// nominal. Measured from each PDF's drawn underline.
///
/// Forms missing here fall back to writing inside the locked rect.
const Map<String, Rect> _kControlNumberFields = {
  r'assets/NEW CHARTING 2026/ENDODONTICS/ENDODONTICS PX CHART/Endodontic-form.pdf':
      Rect.fromLTRB(0.4164, 0.1613, 0.7258, 0.1813),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-III-LIVE-PX.pdf':
      Rect.fromLTRB(0.3573, 0.1803, 0.5884, 0.2003),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-II-LIVE-PX.pdf':
      Rect.fromLTRB(0.3573, 0.1803, 0.5884, 0.2003),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-I-LIVE-PX.pdf':
      Rect.fromLTRB(0.3573, 0.1803, 0.5884, 0.2003),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-IV-LIVE-PX.pdf':
      Rect.fromLTRB(0.3573, 0.1803, 0.5884, 0.2003),
  r'assets/NEW CHARTING 2026/OPERATIVE DENTISTRY/RESTO PX CHART/CLASS-V-LIVE-PX.pdf':
      Rect.fromLTRB(0.3573, 0.1803, 0.5884, 0.2003),
  r'assets/NEW CHARTING 2026/ORAL SURGERY/Exodontia-patient-form.pdf':
      Rect.fromLTRB(0.4164, 0.1847, 0.6474, 0.2047),
  r'assets/NEW CHARTING 2026/PEDIATRIC/ART PEDIA.pdf':
      Rect.fromLTRB(0.3641, 0.2264, 0.6040, 0.2464),
  r'assets/NEW CHARTING 2026/PEDIATRIC/FLUORIDE APPLICATION PEDIA.pdf':
      Rect.fromLTRB(0.4722, 0.1878, 0.7059, 0.2078),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PFS PEDIA.pdf':
      Rect.fromLTRB(0.3641, 0.2276, 0.6040, 0.2476),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PRR PEDIA.pdf':
      Rect.fromLTRB(0.3546, 0.2017, 0.5882, 0.2217),
  r'assets/NEW CHARTING 2026/PEDIATRIC/PULP THERAPHY PEDIA.pdf':
      Rect.fromLTRB(0.4134, 0.2243, 0.7255, 0.2443),
  r'assets/NEW CHARTING 2026/PEDIATRIC/SPACE MAINTAINER PEDIA.pdf':
      Rect.fromLTRB(0.4722, 0.1793, 0.7843, 0.1993),
  r'assets/NEW CHARTING 2026/PERIODONTICS/Oral-Prophylaxis-form-PX.pdf':
      Rect.fromLTRB(0.4753, 0.1729, 0.7062, 0.1929),
  r'assets/NEW CHARTING 2026/PERIODONTICS/PERIO CHART.pdf':
      Rect.fromLTRB(0.4722, 0.1536, 0.7059, 0.1736),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/COMPLETE DENTURE/CD PX CHART/CD-patient-form.pdf':
      Rect.fromLTRB(0.4164, 0.1628, 0.6474, 0.1828),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/FIXED PARTIAL DENTURE/FPD PX CHART/Fixed-restoration-patient-1.pdf':
      Rect.fromLTRB(0.3915, 0.2261, 0.6514, 0.2461),
  r'assets/NEW CHARTING 2026/PROSTHODONTICS/REMOVABLE PARTIAL DENTURE/RPD PX CHART/RPD-patient-form.pdf':
      Rect.fromLTRB(0.3915, 0.1618, 0.6425, 0.1818),
};

/// Normalised underline field for the control number on [assetPath]'s [page],
/// or null when the form has none recorded.
Rect? controlNumberFieldForPage(String assetPath, int page) {
  if (page != 1) return null;
  return _kControlNumberFields[assetPath];
}

/// Forms whose control number is typed in by the user (digits only) instead of
/// being issued by the app. The field stays locked against ink and text, but
/// tapping it opens a number prompt.
const Set<String> _kManualControlNumberForms = {
  r'assets/NEW CHARTING 2026/ORAL SURGERY/Exodontia-patient-form.pdf',
};

/// Whether [assetPath]'s control number is entered by hand.
bool controlNumberIsManual(String assetPath) =>
    _kManualControlNumberForms.contains(assetPath);
