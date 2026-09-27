import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../data/pdf_locked_regions.dart';
import '../services/local/record_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';

enum _Mode { none, draw, text, pan }

class _Action {
  final VoidCallback undo;
  final VoidCallback redo;
  const _Action({required this.undo, required this.redo});
}

class _Stroke {
  /// Mutable so the in-progress stroke can grow in place. Copying the list on
  /// every pointer move made long strokes quadratic, which showed up as ink
  /// lagging behind and then skipping.
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke(this.points, this.color, this.width);

  _Stroke copyWithPoints(List<Offset> pts) => _Stroke(pts, color, width);
}

/// Holds the stroke currently under the pointer, outside the widget tree.
///
/// Drawing used to append each point with `setState`, which rebuilt the page
/// image, every text label and every committed stroke between one pointer move
/// and the next. At stylus sampling rates the framework could not keep up and
/// dropped points, which is what made lines come out broken. Notifying only the
/// ink layer keeps the pen at the same rate as the hardware.
class _ActiveStroke extends ChangeNotifier {
  _Stroke? stroke;
  int page = -1;

  void begin(int page, _Stroke s) {
    this.page = page;
    stroke = s;
    notifyListeners();
  }

  void extend(Offset p) {
    final s = stroke;
    if (s == null) return;
    // Drop sub-pixel moves: they cost a repaint and a path segment without
    // being visible.
    if ((p - s.points.last).distanceSquared < 0.5) return;
    s.points.add(p);
    notifyListeners();
  }

  /// Hands the finished stroke over and clears the layer.
  _Stroke? take() {
    final s = stroke;
    stroke = null;
    page = -1;
    if (s != null) notifyListeners();
    return s;
  }

  void discard() {
    if (stroke == null) return;
    stroke = null;
    page = -1;
    notifyListeners();
  }
}

class _TextLabel {
  Offset position;
  String text;
  Color color;
  double fontSize;
  _TextLabel({
    required this.position,
    required this.text,
    required this.color,
    required this.fontSize,
  });
}

/// A horizontal rule printed on the form, normalised to the page: the line
/// [y] sits at, spanning [left] to [right].
class _RuleLine {
  final double y;
  final double left;
  final double right;
  const _RuleLine(this.y, this.left, this.right);
}

/// Dark runs from consecutive scan rows, stacked while they keep overlapping.
/// A band that stays thin is a rule; a thick one is printed text.
class _RuleBand {
  final int top;
  int bottom;
  double left;
  double right;
  bool extendedThisRow = false;
  _RuleBand(this.top, this.left, this.right) : bottom = top;
}

/// The open band a run belongs to: the one it overlaps by most of the shorter
/// of the two, which keeps a long rule from swallowing a short tick that
/// happens to sit under it.
_RuleBand? _bandOver(List<_RuleBand> open, int start, int end) {
  for (final band in open) {
    final overlap =
        math.min(band.right, end.toDouble()) -
        math.max(band.left, start.toDouble());
    if (overlap <= 0) continue;
    final shorter = math.min(band.right - band.left, (end - start).toDouble());
    if (shorter > 0 && overlap / shorter > 0.6) return band;
  }
  return null;
}

/// Where a pointer is and what put it there, so a resting palm can be told
/// apart from a deliberate two-finger scroll.
class _PointerSample {
  Offset position;
  final PointerDeviceKind kind;
  _PointerSample(this.position, this.kind);
}

class _TextDialogResult {
  final String text;
  final double fontSize;
  const _TextDialogResult(this.text, this.fontSize);
}

class PdfAnnotatorView extends StatefulWidget {
  final String title;
  final String editablePdfPath;
  final List<String> companionPdfPaths;

  /// Folder the saved record belongs to, e.g. 'Pediatric'. Falls back to the
  /// department inferred from [editablePdfPath] when not supplied.
  final String? category;

  /// Non-null when reopening an already-saved record, which restores its
  /// annotations and updates that same row on save instead of creating a new
  /// one.
  final PatientRecord? record;

  const PdfAnnotatorView({
    super.key,
    required this.title,
    required this.editablePdfPath,
    this.companionPdfPaths = const [],
    this.category,
    this.record,
  });

  @override
  State<PdfAnnotatorView> createState() => _PdfAnnotatorViewState();
}

class _PdfAnnotatorViewState extends State<PdfAnnotatorView> {
  pdfx.PdfDocument? _doc;
  final Map<int, Uint8List> _pageImages = {};
  final Map<int, double> _pageAspectRatios = {};
  final Map<int, List<_Stroke>> _strokes = {};
  final Map<int, List<_TextLabel>> _textLabels = {};
  final Map<int, GlobalKey> _repaintKeys = {};
  final Map<int, TransformationController> _zoomControllers = {};
  // Rendered on-screen size of each page box, used to map normalised locked
  // regions to local pixel coordinates for hit-testing.
  final Map<int, Size> _pageSizes = {};
  final ScrollController _scrollController = ScrollController();

  final _ActiveStroke _active = _ActiveStroke();

  /// Page the erase drag in progress belongs to, or -1. Strokes track their own
  /// page on [_ActiveStroke].
  int _drawingPage = -1;

  /// Pointer that owns the stroke or erase in progress, and the kind of device
  /// it came from. A stylus keeps its stroke when a finger or palm lands, so
  /// resting a hand on the tablet while writing does not break the line.
  int? _drawPointer;
  PointerDeviceKind? _drawPointerKind;
  Offset? _pointerDownAt;

  /// Every pointer currently down anywhere on the document, in global
  /// coordinates. Two fingers means "scroll the chart" — previously the thin
  /// handle down the side was the only way to move through the pages.
  final Map<int, _PointerSample> _pointers = {};
  double? _twoFingerSpread;
  double? _lastFocalY;
  bool _pinching = false;

  Color _color = Colors.blue;
  double _penWidth = 3.0;
  double _eraserWidth = 8.0;
  double _textSize = 16.0;
  bool _erasing = false;
  _Mode _mode = _Mode.draw;
  bool _saving = false;
  String? _error;

  final List<_Action> _undoStack = [];
  final List<_Action> _redoStack = [];

  // Identity of the record being edited. Null id means nothing has been saved
  // yet, so the first save inserts a new row rather than overwriting one.
  int? _recordId;
  String? _patientCode;

  String get _category =>
      widget.category ??
      RecordStore.categoryForTemplate(widget.editablePdfPath);

  static const _colors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.black,
    Colors.orange,
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.record;
    if (existing != null) {
      _recordId = existing.id;
      _patientCode = existing.patientCode;
    }
    if (_patientCode == null) unawaited(_assignPatientCode());
    _loadDocument();
  }

  /// Issues the card/control number as the chart opens rather than at save
  /// time, so it can be stamped into the form's own control-number field right
  /// away. Numbers are derived from the saved rows, so one handed out here and
  /// then abandoned is simply offered again next time.
  Future<void> _assignPatientCode() async {
    try {
      final code = await RecordStore.instance.nextPatientCode(_category);
      if (!mounted) return;
      setState(() => _patientCode ??= code);
    } catch (_) {
      // Not worth failing the chart over: _persistRecord assigns one on save.
    }
  }

  @override
  void dispose() {
    _active.dispose();
    _scrollController.dispose();
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    _doc?.close();
    super.dispose();
  }

  Future<Uint8List> _loadAssetBytes(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  Future<void> _loadDocument() async {
    try {
      final bytes = await _loadAssetBytes(widget.editablePdfPath);
      final doc = await pdfx.PdfDocument.openData(bytes);
      final images = <int, Uint8List>{};
      final ratios = <int, double>{};
      for (int i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        ratios[i] = page.width / page.height;
        final img = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );
        await page.close();
        if (img != null) images[i] = img.bytes;
      }
      if (mounted) {
        setState(() {
          _doc = doc;
          _pageImages.addAll(images);
          _pageAspectRatios.addAll(ratios);
        });
        _restoreSavedRecord();
        // Scan for the form's ruled lines in the background: it is only needed
        // once the student taps to type, and it must not delay first paint.
        unawaited(_detectLinesForAll(images));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // ── Line snapping ─────────────────────────────────────────────────────────

  /// The horizontal rules printed on each form, so typed text can be dropped
  /// onto the line it belongs to instead of wherever the tap happened to land.
  final Map<int, List<_RuleLine>> _pageLines = {};

  /// Scans pages one at a time. Each scan decodes a page to raw RGBA — tens of
  /// megabytes for an A4 page at 2x — so running them concurrently would hold
  /// every page in memory at once and starve the export, which needs a large
  /// allocation of its own.
  Future<void> _detectLinesForAll(Map<int, Uint8List> images) async {
    for (final entry in images.entries) {
      if (!mounted) return;
      await _detectLines(entry.key, entry.value);
    }
  }

  /// Scans a rendered page for the printed rules of the chart.
  ///
  /// The earlier pass only accepted rows that were dark across more than half
  /// the page, which almost no form satisfies — the rules are field-length, a
  /// few inches at most — so nothing was found and typed text simply stayed
  /// wherever the finger landed. This instead collects every long horizontal
  /// run of dark pixels, stacks the runs that sit on top of each other into a
  /// band, and keeps the bands that are thin. Thinness is what separates a rule
  /// from a row of printed labels: a rule is two or three pixels tall, a line
  /// of text twenty.
  Future<void> _detectLines(int page, Uint8List pngBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(pngBytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final width = image.width;
      final height = image.height;
      image.dispose();
      codec.dispose();
      if (data == null || width < 8 || height < 8) return;

      final pixels = data.buffer.asUint8List();
      const xStep = 2;
      const yStep = 2;
      // Shorter than this and it is a tick, a letter or the corner of a box
      // rather than something to write on.
      final minRun = math.max(24, (width * 0.06).round());
      // Rules are often broken or dotted; bridge small gaps but not the spaces
      // between letters.
      final maxGap = math.max(2, (width * 0.004).round());
      final maxThickness = math.max(3.0, height * 0.006);

      final rules = <_RuleLine>[];
      final open = <_RuleBand>[];

      void close(_RuleBand band) {
        if (band.bottom - band.top > maxThickness) return;
        rules.add(
          _RuleLine(
            ((band.top + band.bottom) / 2) / height,
            band.left / width,
            band.right / width,
          ),
        );
      }

      for (int y = 0; y < height; y += yStep) {
        final runs = _darkRunsInRow(pixels, width, y, xStep, minRun, maxGap);
        for (final band in open) {
          band.extendedThisRow = false;
        }
        for (final run in runs) {
          final band = _bandOver(open, run[0], run[1]);
          if (band == null) {
            open.add(
              _RuleBand(y, run[0].toDouble(), run[1].toDouble())
                ..extendedThisRow = true,
            );
          } else {
            band.bottom = y;
            band.left = math.min(band.left, run[0].toDouble());
            band.right = math.max(band.right, run[1].toDouble());
            band.extendedThisRow = true;
          }
        }
        open.removeWhere((band) {
          if (band.extendedThisRow) return false;
          close(band);
          return true;
        });
      }
      for (final band in open) {
        close(band);
      }

      if (rules.isNotEmpty && mounted) _pageLines[page] = rules;
    } catch (_) {
      // Snapping is a convenience — fall back to the raw tap position.
    }
  }

  /// The dark runs along one row of [pixels], as `[startX, endX]` pairs.
  ///
  /// A run counts only if it is long and nearly solid. A printed rule is a
  /// continuous line; a row taken through printed text is mostly gaps between
  /// letters, and text being mistaken for something to write on would put the
  /// entry straight over the form's own labels.
  static List<List<int>> _darkRunsInRow(
    Uint8List pixels,
    int width,
    int y,
    int xStep,
    int minRun,
    int maxGap,
  ) {
    const minFill = 0.8;
    final runs = <List<int>>[];
    var start = -1;
    var lastDark = -1;
    var darkSamples = 0;

    void close() {
      if (start >= 0 && lastDark - start >= minRun) {
        final samples = (lastDark - start) ~/ xStep + 1;
        if (darkSamples / samples >= minFill) runs.add([start, lastDark]);
      }
      start = -1;
      darkSamples = 0;
    }

    for (int x = 0; x < width; x += xStep) {
      final i = (y * width + x) * 4;
      final dark =
          pixels[i] < 140 && pixels[i + 1] < 140 && pixels[i + 2] < 140;
      if (dark) {
        if (start < 0) start = x;
        lastDark = x;
        darkSamples++;
      } else if (start >= 0 && x - lastDark > maxGap) {
        close();
      }
    }
    close();
    return runs;
  }

  /// Seats [position] on the printed rule the tap belongs to, the way the entry
  /// would be written by hand. Only rules the tap sits over horizontally are
  /// considered, so a tap in one column never jumps to a line in another, and a
  /// tap in genuinely open space is left where it was made.
  Offset _snapToLine(int page, Offset position, double fontSize) {
    final rules = _pageLines[page];
    final size = _pageSizes[page];
    if (rules == null ||
        rules.isEmpty ||
        size == null ||
        size.height == 0 ||
        size.width == 0) {
      return position;
    }
    final x = position.dx / size.width;
    final y = position.dy / size.height;

    _RuleLine? best;
    var bestDistance = double.infinity;
    for (final rule in rules) {
      if (x < rule.left - 0.02 || x > rule.right + 0.02) continue;
      // Writing sits above its rule, so a rule just below the tap is the
      // likelier target than one the same distance above it.
      final distance = y <= rule.y ? rule.y - y : (y - rule.y) * 2.2;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = rule;
      }
    }
    if (best == null || bestDistance > 0.035) return position;

    // position.dy is the vertical centre of the label, so lift it by roughly
    // half a line to sit the text on top of the rule rather than through it.
    return Offset(
      position.dx.clamp(best.left * size.width, best.right * size.width),
      best.y * size.height - fontSize * 0.45,
    );
  }

  /// Notes the page's rendered size and carries the annotations with it when it
  /// changes.
  ///
  /// Marks are held in the page's on-screen pixels, so a rotation, a
  /// split-screen resize, or a record reopened on a different device would
  /// otherwise leave every stroke and every label at coordinates that no longer
  /// mean the same place on the form. Rescaling keeps them on the lines they
  /// were written on. The page sits in an AspectRatio, so both axes scale by the
  /// same factor and the writing does not distort.
  void _recordPageSize(int page, Size size) {
    final previous = _pageSizes[page];
    _pageSizes[page] = size;
    if (previous == null ||
        previous == size ||
        previous.width <= 0 ||
        previous.height <= 0 ||
        size.width <= 0 ||
        size.height <= 0) {
      return;
    }
    final scaleX = size.width / previous.width;
    final scaleY = size.height / previous.height;

    for (final stroke in _strokes[page] ?? const <_Stroke>[]) {
      for (int i = 0; i < stroke.points.length; i++) {
        stroke.points[i] = Offset(
          stroke.points[i].dx * scaleX,
          stroke.points[i].dy * scaleY,
        );
      }
    }
    for (final label in _textLabels[page] ?? const <_TextLabel>[]) {
      label.position = Offset(
        label.position.dx * scaleX,
        label.position.dy * scaleY,
      );
      label.fontSize *= scaleY;
    }
  }

  /// Keeps a label inside the page bounds.
  Offset _clampToPage(int page, Offset position) {
    final size = _pageSizes[page];
    if (size == null) return position;
    return Offset(
      position.dx.clamp(0.0, size.width),
      position.dy.clamp(0.0, size.height),
    );
  }

  // ── Record persistence ────────────────────────────────────────────────────

  /// Applies the annotations of the record this view was opened with. Opening a
  /// blank template starts empty on purpose — each patient gets their own row
  /// rather than reviving whoever last used this form.
  void _restoreSavedRecord() {
    final existing = widget.record;
    if (existing == null) return;
    setState(() => _applyDraft(existing.annotations));
  }

  int _encodeColor(Color c) {
    final a = (c.a * 255).round();
    final r = (c.r * 255).round();
    final g = (c.g * 255).round();
    final b = (c.b * 255).round();
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  Map<String, dynamic> _serializeDraft() {
    final strokes = <String, dynamic>{};
    _strokes.forEach((page, list) {
      strokes['$page'] = list
          .map(
            (s) => {
              'color': _encodeColor(s.color),
              'width': s.width,
              'points': s.points
                  .map((o) => [o.dx, o.dy])
                  .toList(growable: false),
            },
          )
          .toList();
    });
    final labels = <String, dynamic>{};
    _textLabels.forEach((page, list) {
      labels['$page'] = list
          .map(
            (l) => {
              'x': l.position.dx,
              'y': l.position.dy,
              'text': l.text,
              'color': _encodeColor(l.color),
              'fontSize': l.fontSize,
            },
          )
          .toList();
    });
    // Marks are stored in the page's on-screen pixels, so the size they were
    // made at has to travel with them: reopened on a rotated tablet or a device
    // with a different screen, they are scaled back onto the page rather than
    // landing wherever those pixels now happen to fall.
    final pageSizes = <String, dynamic>{};
    _pageSizes.forEach((page, size) {
      pageSizes['$page'] = [size.width, size.height];
    });
    return {
      'savedAt': DateTime.now().toIso8601String(),
      'title': widget.title,
      'editablePdfPath': widget.editablePdfPath,
      'companionPdfPaths': widget.companionPdfPaths,
      'strokes': strokes,
      'labels': labels,
      'pageSizes': pageSizes,
    };
  }

  void _applyDraft(Map<String, dynamic> data) {
    final strokesJson = (data['strokes'] as Map?)?.cast<String, dynamic>();
    final labelsJson = (data['labels'] as Map?)?.cast<String, dynamic>();
    _strokes.clear();
    _textLabels.clear();

    // Seed the page sizes the marks were made at. The first real layout then
    // finds them stale and rescales everything onto the page as it is now —
    // see [_recordPageSize]. Records written before sizes were stored have
    // none, and are restored as they always were.
    final sizesJson = (data['pageSizes'] as Map?)?.cast<String, dynamic>();
    if (sizesJson != null) {
      sizesJson.forEach((pageStr, raw) {
        final page = int.tryParse(pageStr);
        final pair = raw as List?;
        if (page == null || pair == null || pair.length < 2) return;
        final width = (pair[0] as num).toDouble();
        final height = (pair[1] as num).toDouble();
        if (width <= 0 || height <= 0) return;
        _pageSizes[page] = Size(width, height);
      });
    }
    if (strokesJson != null) {
      strokesJson.forEach((pageStr, raw) {
        final page = int.tryParse(pageStr);
        if (page == null) return;
        final list = (raw as List).map((s) {
          final pts = (s['points'] as List).map((p) {
            final l = p as List;
            return Offset((l[0] as num).toDouble(), (l[1] as num).toDouble());
          }).toList();
          return _Stroke(
            pts,
            Color(s['color'] as int),
            (s['width'] as num).toDouble(),
          );
        }).toList();
        _strokes[page] = list;
      });
    }
    if (labelsJson != null) {
      labelsJson.forEach((pageStr, raw) {
        final page = int.tryParse(pageStr);
        if (page == null) return;
        final list = (raw as List).map((l) {
          return _TextLabel(
            position: Offset(
              (l['x'] as num).toDouble(),
              (l['y'] as num).toDouble(),
            ),
            text: l['text'] as String,
            color: Color(l['color'] as int),
            fontSize: (l['fontSize'] as num).toDouble(),
          );
        }).toList();
        _textLabels[page] = list;
      });
    }
  }

  /// Writes the current annotations to the patient's record. The card/control
  /// number is issued by the app on first save — never typed — which is why the
  /// matching field on the chart is a locked region.
  Future<bool> _persistRecord() async {
    _patientCode ??= await RecordStore.instance.nextPatientCode(_category);
    final id = await RecordStore.instance.save(
      id: _recordId,
      patientCode: _patientCode,
      category: _category,
      formTitle: widget.title,
      templatePath: widget.editablePdfPath,
      companionPaths: widget.companionPdfPaths,
      annotations: _serializeDraft(),
    );
    _recordId = id;
    return true;
  }

  Future<void> _saveDraftAndExit() async {
    try {
      final saved = await _persistRecord();
      if (!saved || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF5D4B8A),
          content: Text(
            'Saved to $_category · $_patientCode',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save record: $e')));
    }
  }

  GlobalKey _keyFor(int page) =>
      _repaintKeys.putIfAbsent(page, () => GlobalKey());

  TransformationController _zoomFor(int page) =>
      _zoomControllers.putIfAbsent(page, () => TransformationController());

  double _scaleFor(int page) {
    final c = _zoomControllers[page];
    if (c == null) return 1.0;
    return c.value.getMaxScaleOnAxis();
  }

  List<_Stroke> _strokesFor(int page) => _strokes.putIfAbsent(page, () => []);
  List<_TextLabel> _textLabelsFor(int page) =>
      _textLabels.putIfAbsent(page, () => []);

  void _resetZoom(int page) {
    final c = _zoomControllers[page];
    if (c != null) {
      setState(() => c.value = Matrix4.identity());
    }
  }

  void _resetAllZoom() {
    setState(() {
      for (final c in _zoomControllers.values) {
        c.value = Matrix4.identity();
      }
    });
  }

  void _zoomAllBy(double factor) {
    setState(() {
      for (final c in _zoomControllers.values) {
        final current = c.value.getMaxScaleOnAxis();
        final next = (current * factor).clamp(1.0, 5.0);
        c.value = Matrix4.identity()..scaleByDouble(next, next, 1.0, 1.0);
      }
    });
  }

  void _zoomPageBy(int page, double factor, [Offset? focal]) {
    final c = _zoomControllers[page];
    if (c == null) return;
    final current = c.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(1.0, 5.0);
    if (next == current) return;
    // Zoom around the given focal point (in child coords) when possible.
    final matrix = Matrix4.identity();
    if (focal != null) {
      matrix
        ..translateByDouble(focal.dx, focal.dy, 0.0, 1.0)
        ..scaleByDouble(next, next, 1.0, 1.0)
        ..translateByDouble(-focal.dx, -focal.dy, 0.0, 1.0);
    } else {
      matrix.scaleByDouble(next, next, 1.0, 1.0);
    }
    setState(() => c.value = matrix);
  }

  // ── Locked (read-only) regions ─────────────────────────────────────────────
  // Patient-identifying field on page 1 that must stay un-annotated.

  List<Rect> _lockedPixelRects(int page) {
    final size = _pageSizes[page];
    if (size == null) return const [];
    final norm = lockedRegionsForPage(widget.editablePdfPath, page);
    if (norm.isEmpty) return const [];
    return norm
        .map(
          (r) => Rect.fromLTRB(
            r.left * size.width,
            r.top * size.height,
            r.right * size.width,
            r.bottom * size.height,
          ),
        )
        .toList(growable: false);
  }

  bool _isLocked(int page, Offset localPos) {
    for (final r in _lockedPixelRects(page)) {
      if (r.contains(localPos)) return true;
    }
    return false;
  }

  void _notifyLocked() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF5D4B8A),
          duration: Duration(seconds: 2),
          content: Text(
            'Patient field is locked and can’t be edited.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
  }

  // ── Pointer routing ───────────────────────────────────────────────────────
  //
  // Input is handled from raw pointer events rather than pan gestures. A pan
  // recognizer reports nothing until the pointer has travelled kTouchSlop
  // (~18 logical pixels), so the start of every stroke was discarded and short
  // marks — a tick, a dot, the tail of a letter — never registered at all.
  // Raw events also stay out of the gesture arena, so the page's zoom
  // recognizer can no longer take a quick stroke away from the pen.

  /// How far two fingers have to spread before the gesture is a pinch rather
  /// than a scroll.
  static const double _kPinchSlop = 22.0;

  /// How far a pointer may travel and still count as a tap.
  static const double _kTapSlop = 12.0;

  static bool _isStylus(PointerDeviceKind kind) =>
      kind == PointerDeviceKind.stylus ||
      kind == PointerDeviceKind.invertedStylus;

  int get _fingersDown =>
      _pointers.values.where((p) => p.kind == PointerDeviceKind.touch).length;

  /// Distance between the first two pointers. Fingers that hold their spacing
  /// are scrolling; fingers that change it are zooming.
  double? get _pointerSpread {
    if (_pointers.length < 2) return null;
    final samples = _pointers.values.toList(growable: false);
    return (samples[0].position - samples[1].position).distance;
  }

  /// Mean vertical position of the fingers — the point a two-finger scroll
  /// follows. Tracking the middle of the hand rather than each pointer's own
  /// delta keeps the chart moving at the right speed when one finger is doing
  /// all the travelling.
  double? get _touchFocalY {
    var sum = 0.0;
    var count = 0;
    for (final sample in _pointers.values) {
      if (sample.kind != PointerDeviceKind.touch) continue;
      sum += sample.position.dy;
      count++;
    }
    return count == 0 ? null : sum / count;
  }

  void _onViewportPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = _PointerSample(e.position, e.kind);
    if (_fingersDown < 2) return;
    // Two fingers means scroll or pinch. A stylus stroke survives it, so a palm
    // resting on the tablet cannot break a line; a stroke being drawn with a
    // finger is dropped, because that same hand is about to scroll.
    if (_drawPointerKind == null || !_isStylus(_drawPointerKind!)) {
      _abandonActiveInput();
    }
    _twoFingerSpread = _pointerSpread;
    _lastFocalY = _touchFocalY;
    _pinching = false;
  }

  void _onViewportPointerMove(PointerMoveEvent e) {
    final sample = _pointers[e.pointer];
    if (sample == null) return;
    sample.position = e.position;

    if (_mode == _Mode.pan) return; // the scroll view drives itself there
    if (_pinching || _fingersDown < 2) return;

    final spread = _pointerSpread;
    final start = _twoFingerSpread;
    if (spread != null &&
        start != null &&
        (spread - start).abs() > _kPinchSlop) {
      // The fingers are opening or closing: leave the gesture to the zoom.
      _pinching = true;
      return;
    }

    final focal = _touchFocalY;
    final previous = _lastFocalY;
    if (focal == null) return;
    _lastFocalY = focal;
    if (previous != null) _scrollBy(previous - focal);
  }

  void _onViewportPointerFinished(PointerEvent e) {
    _pointers.remove(e.pointer);
    // Re-seat the focal point so lifting one of three fingers doesn't jump the
    // page by the distance between them.
    _lastFocalY = _fingersDown >= 2 ? _touchFocalY : null;
    if (_pointers.isEmpty) {
      _twoFingerSpread = null;
      _pinching = false;
    }
  }

  /// Scrolls the chart directly. The list keeps NeverScrollableScrollPhysics so
  /// that a single finger is always the pen, which is why this drives the
  /// controller by hand — the same thing [_ScrollHandle] does.
  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) return;
    _scrollController.jumpTo(
      (position.pixels + delta).clamp(0.0, position.maxScrollExtent),
    );
  }

  void _onDrawPointerDown(PointerDownEvent e, int page) {
    if (_drawPointer != null) return;
    // A finger that joins a touch already on the glass is scrolling, not
    // drawing. A stylus draws regardless of what else is resting there.
    if (!_isStylus(e.kind) &&
        _pointers.keys.any((pointer) => pointer != e.pointer)) {
      return;
    }
    _drawPointer = e.pointer;
    _drawPointerKind = e.kind;
    _pointerDownAt = e.localPosition;
    if (_mode == _Mode.draw) {
      if (_erasing) {
        _startErase(page, e.localPosition);
      } else {
        _startStroke(page, e.localPosition);
      }
    }
  }

  void _onDrawPointerMove(PointerMoveEvent e, int page) {
    if (e.pointer != _drawPointer || _mode != _Mode.draw) return;
    if (_erasing) {
      _eraseAt(page, e.localPosition);
    } else {
      _extendStroke(page, e.localPosition);
    }
  }

  void _onDrawPointerUp(PointerUpEvent e, int page) {
    if (e.pointer != _drawPointer) return;
    final downAt = _pointerDownAt;
    _clearDrawPointer();
    switch (_mode) {
      case _Mode.draw:
        if (_erasing) {
          _endErase(page);
        } else {
          _commitActiveStroke(page);
        }
      case _Mode.text:
        // Only a tap places text; a drag was meant for something else.
        if (downAt == null || (e.localPosition - downAt).distance > _kTapSlop) {
          return;
        }
        if (_isLocked(page, e.localPosition)) {
          _notifyLocked();
        } else {
          _addTextLabel(page, e.localPosition);
        }
      case _Mode.pan:
      case _Mode.none:
        break;
    }
  }

  void _onDrawPointerCancel(PointerCancelEvent e, int page) {
    if (e.pointer != _drawPointer) return;
    _clearDrawPointer();
    if (_mode != _Mode.draw) return;
    if (_erasing) {
      _endErase(page);
    } else {
      _commitActiveStroke(page);
    }
  }

  void _clearDrawPointer() {
    _drawPointer = null;
    _drawPointerKind = null;
    _pointerDownAt = null;
  }

  /// Drops the input in progress because the gesture turned out to be a scroll,
  /// so no stray mark is left behind.
  void _abandonActiveInput() {
    final page = _drawingPage;
    _clearDrawPointer();
    _active.discard();
    if (_erasing && page > 0) _endErase(page);
  }

  void _startStroke(int page, Offset position) {
    // Block drawing that begins inside the protected patient field.
    if (_isLocked(page, position)) {
      _notifyLocked();
      return;
    }
    _active.begin(page, _Stroke([position], _color, _penWidth));
  }

  void _extendStroke(int page, Offset position) {
    if (_active.stroke == null || _active.page != page) return;
    // If the pointer wanders into the protected field, finalize the stroke and
    // stop drawing for the rest of this drag. Skipping the point alone isn't
    // enough — the painter connects consecutive points with a straight line, so
    // a stroke crossing the field would bridge right over it.
    if (_isLocked(page, position)) {
      _commitActiveStroke(page);
      return;
    }
    _active.extend(position);
  }

  // ── Eraser ────────────────────────────────────────────────────────────────
  //
  // Removes what was drawn rather than painting white over it, so the printed
  // chart underneath survives being erased.
  //
  // It takes out only the part of a line it is rubbed over. Erasing used to
  // delete whole strokes, so touching one wrong tick lifted the entire line it
  // belonged to; now the stroke is split into the runs of points the eraser
  // missed and those are kept, which is what makes correcting a small slip
  // possible.

  /// Eraser reach in page pixels. Zoom shrinks it against the page, so zooming
  /// in is how a small mistake gets rubbed out without touching its neighbours.
  double _eraserRadiusFor(int page) {
    final scale = _scaleFor(page);
    return _eraserWidth / (scale <= 0 ? 1.0 : scale);
  }

  /// Page contents as they were when the current erase drag started, so one
  /// swipe undoes as a single action however many fragments it produced.
  List<_Stroke>? _strokesBeforeErase;
  List<_TextLabel>? _labelsBeforeErase;

  void _startErase(int page, Offset position) {
    _drawingPage = page;
    _strokesBeforeErase = List<_Stroke>.from(_strokesFor(page));
    _labelsBeforeErase = List<_TextLabel>.from(_textLabelsFor(page));
    _eraseAt(page, position);
  }

  void _endErase(int page) {
    final strokesBefore = _strokesBeforeErase;
    final labelsBefore = _labelsBeforeErase;
    _strokesBeforeErase = null;
    _labelsBeforeErase = null;
    _drawingPage = -1;
    if (strokesBefore == null || labelsBefore == null) return;

    final strokesAfter = List<_Stroke>.from(_strokesFor(page));
    final labelsAfter = List<_TextLabel>.from(_textLabelsFor(page));
    if (_sameContents(strokesBefore, strokesAfter) &&
        _sameContents(labelsBefore, labelsAfter)) {
      return;
    }
    // setState so the undo button picks up the new action.
    setState(() {});
    _pushAction(
      _Action(
        undo: () {
          _strokes[page] = List<_Stroke>.from(strokesBefore);
          _textLabels[page] = List<_TextLabel>.from(labelsBefore);
        },
        redo: () {
          _strokes[page] = List<_Stroke>.from(strokesAfter);
          _textLabels[page] = List<_TextLabel>.from(labelsAfter);
        },
      ),
    );
  }

  static bool _sameContents(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  void _eraseAt(int page, Offset point) {
    if (_drawingPage != page) return;
    final radius = _eraserRadiusFor(page);
    final strokes = _strokesFor(page);
    final labels = _textLabelsFor(page);

    var changed = false;
    final remaining = <_Stroke>[];
    for (final stroke in strokes) {
      if (!_strokeNear(stroke, point, radius)) {
        remaining.add(stroke);
        continue;
      }
      final pieces = _splitAroundEraser(stroke, point, radius);
      final keptPoints = pieces.fold<int>(0, (n, s) => n + s.points.length);
      if (pieces.length == 1 && keptPoints == stroke.points.length) {
        // Near enough to test but nothing actually rubbed out.
        remaining.add(stroke);
        continue;
      }
      changed = true;
      remaining.addAll(pieces);
    }

    // Text is erased whole: half a word is not a correction.
    final keptLabels = labels
        .where((l) => !_labelNear(l, point, radius))
        .toList();
    if (keptLabels.length != labels.length) changed = true;
    if (!changed) return;

    setState(() {
      _strokes[page] = remaining;
      _textLabels[page] = keptLabels;
    });
  }

  /// The parts of [stroke] the eraser did not touch, in order. Points inside the
  /// eraser are dropped and each surviving run becomes a stroke of its own, so
  /// rubbing the middle of a line leaves both ends where they were.
  static List<_Stroke> _splitAroundEraser(
    _Stroke stroke,
    Offset point,
    double radius,
  ) {
    final reach = radius + stroke.width / 2;
    final pieces = <_Stroke>[];
    var run = <Offset>[];

    void flush() {
      // A leftover single point would show up as a speck, so only keep runs
      // that still draw as a line.
      if (run.length > 1) pieces.add(stroke.copyWithPoints(run));
      run = <Offset>[];
    }

    for (int i = 0; i < stroke.points.length; i++) {
      final p = stroke.points[i];
      if ((p - point).distance <= reach) {
        flush();
        continue;
      }
      run.add(p);
      // A fast stroke samples sparsely, so the line can pass straight through
      // the eraser without any of its points landing inside. Cut it there too,
      // otherwise the gap gets bridged by the segment that spans it.
      if (i + 1 < stroke.points.length &&
          _distanceToSegment(point, p, stroke.points[i + 1]) <= reach) {
        flush();
      }
    }
    flush();
    return pieces;
  }

  static bool _strokeNear(_Stroke s, Offset p, double radius) {
    final reach = radius + s.width / 2;
    if (s.points.length == 1) return (s.points.first - p).distance <= reach;
    for (int i = 0; i < s.points.length - 1; i++) {
      if (_distanceToSegment(p, s.points[i], s.points[i + 1]) <= reach) {
        return true;
      }
    }
    return false;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared)
        .clamp(0.0, 1.0);
    return (p - Offset(a.dx + ab.dx * t, a.dy + ab.dy * t)).distance;
  }

  bool _labelNear(_TextLabel l, Offset p, double radius) {
    return _labelRect(l).inflate(radius).contains(p);
  }

  /// On-page bounds of a label. The widget is shifted up by half its height by
  /// the FractionalTranslation it is drawn with, so [_TextLabel.position] is the
  /// vertical centre, not the top edge.
  Rect _labelRect(_TextLabel l) {
    final painter = TextPainter(
      text: TextSpan(
        text: l.text,
        style: TextStyle(fontSize: l.fontSize, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return Rect.fromLTWH(
      l.position.dx,
      l.position.dy - painter.size.height / 2,
      painter.size.width,
      painter.size.height,
    );
  }

  /// Moves the in-progress stroke (if any) onto the page and records it for
  /// undo. This is the only point where drawing touches setState.
  void _commitActiveStroke(int page) {
    if (_active.stroke == null || _active.page != page) return;
    final added = _active.take()!;
    setState(() => _strokesFor(page).add(added));
    _pushAction(
      _Action(
        undo: () => _strokesFor(page).remove(added),
        redo: () => _strokesFor(page).add(added),
      ),
    );
  }

  void _pushAction(_Action a) {
    _undoStack.add(a);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final a = _undoStack.removeLast();
    setState(a.undo);
    _redoStack.add(a);
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final a = _redoStack.removeLast();
    setState(a.redo);
    _undoStack.add(a);
  }

  Future<void> _clearPage(int page) async {
    final strokes = _strokes[page] ?? const <_Stroke>[];
    final labels = _textLabels[page] ?? const <_TextLabel>[];
    if (strokes.isEmpty && labels.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Clear page?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove all annotations from page $page?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prevStrokes = List<_Stroke>.from(strokes);
    final prevLabels = List<_TextLabel>.from(labels);
    setState(() {
      _strokes[page] = [];
      _textLabels[page] = [];
    });
    _pushAction(
      _Action(
        undo: () {
          _strokes[page] = List<_Stroke>.from(prevStrokes);
          _textLabels[page] = List<_TextLabel>.from(prevLabels);
        },
        redo: () {
          _strokes[page] = [];
          _textLabels[page] = [];
        },
      ),
    );
  }

  Future<void> _addTextLabel(int page, Offset position) async {
    final result = await showDialog<_TextDialogResult>(
      context: context,
      builder: (ctx) => _TextInputDialog(
        initialText: '',
        initialFontSize: _textSize,
        color: _color,
      ),
    );
    if (result != null && result.text.isNotEmpty && mounted) {
      final label = _TextLabel(
        position: _snapToLine(page, position, result.fontSize),
        text: result.text,
        color: _color,
        fontSize: result.fontSize,
      );
      setState(() {
        _textSize = result.fontSize;
        _textLabelsFor(page).add(label);
      });
      _pushAction(
        _Action(
          undo: () => _textLabelsFor(page).remove(label),
          redo: () => _textLabelsFor(page).add(label),
        ),
      );
    }
  }

  Future<void> _editTextLabel(int page, _TextLabel label) async {
    final result = await showDialog<_TextDialogResult>(
      context: context,
      builder: (ctx) => _TextInputDialog(
        initialText: label.text,
        initialFontSize: label.fontSize,
        color: label.color,
      ),
    );
    if (result == null || !mounted) return;
    if (result.text.isEmpty) {
      final list = _textLabelsFor(page);
      final idx = list.indexOf(label);
      if (idx == -1) return;
      setState(() => list.removeAt(idx));
      _pushAction(
        _Action(
          undo: () => _textLabelsFor(page).insert(idx, label),
          redo: () => _textLabelsFor(page).remove(label),
        ),
      );
    } else {
      setState(() {
        label.text = result.text;
        label.fontSize = result.fontSize;
      });
    }
  }

  // ── Save flow ─────────────────────────────────────────────────────────────

  Future<bool> _ensureStoragePermission() async {
    if (!Platform.isAndroid) return true;
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    if (status.isGranted) return true;
    var legacy = await Permission.storage.status;
    if (!legacy.isGranted) {
      legacy = await Permission.storage.request();
    }
    return legacy.isGranted;
  }

  static const String _casesFolderName = 'Toothly Cases';

  Future<String> _writePdfBytes(Uint8List bytes, String fileName) async {
    if (Platform.isAndroid) {
      final casesDir = Directory(
        '/storage/emulated/0/Documents/$_casesFolderName',
      );
      try {
        if (!casesDir.existsSync()) {
          casesDir.createSync(recursive: true);
        }
        final f = File('${casesDir.path}/$fileName');
        await f.writeAsBytes(bytes);
        return f.path;
      } catch (_) {
        // fall through to app-internal fallback
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final casesDir = Directory('${docs.path}/$_casesFolderName');
    if (!casesDir.existsSync()) {
      casesDir.createSync(recursive: true);
    }
    final f = File('${casesDir.path}/$fileName');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  /// Renders the annotated chart plus its companion forms into a single PDF.
  /// Shared by the save and print flows so both produce an identical document.
  Future<Uint8List> _buildPdfBytes() async {
    // Reset zoom on all pages so the rendered snapshot is the full page.
    for (final c in _zoomControllers.values) {
      c.value = Matrix4.identity();
    }
    await WidgetsBinding.instance.endOfFrame;

    final pdfDoc = pw.Document();

    for (int page = 1; page <= (_doc?.pagesCount ?? 0); page++) {
      final key = _repaintKeys[page];
      if (key?.currentContext == null) continue;
      final boundary =
          key!.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final aspectRatio = image.width / image.height;
      final pageHeight = PdfPageFormat.a4.width / aspectRatio;
      pdfDoc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            PdfPageFormat.a4.width,
            pageHeight,
            marginAll: 0,
          ),
          build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        ),
      );
    }

    for (final assetPath in widget.companionPdfPaths) {
      final compBytes = await _loadAssetBytes(assetPath);
      final compDoc = await pdfx.PdfDocument.openData(compBytes);
      for (int i = 1; i <= compDoc.pagesCount; i++) {
        final page = await compDoc.getPage(i);
        final img = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#ffffff',
        );
        await page.close();
        if (img == null) continue;
        final aspectRatio = (img.width ?? 1) / (img.height ?? 1);
        final pageHeight = PdfPageFormat.a4.width / aspectRatio;
        pdfDoc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              PdfPageFormat.a4.width,
              pageHeight,
              marginAll: 0,
            ),
            build: (_) =>
                pw.Image(pw.MemoryImage(img.bytes), fit: pw.BoxFit.fill),
          ),
        );
      }
      await compDoc.close();
    }

    return pdfDoc.save();
  }

  /// Filename stem for exports and print jobs: patient first, then the form.
  String get _documentName {
    final patient = (_patientCode ?? 'patient').replaceAll(
      RegExp(r'[^A-Za-z0-9]+'),
      '_',
    );
    return '${patient}_${widget.title.replaceAll(' ', '_')}';
  }

  /// Hands the chart to the system print dialog — AirPrint on iOS, the Android
  /// print service otherwise — so a copy can be printed without exporting and
  /// hunting for the file first.
  Future<void> _printPdf() async {
    if (!await _persistRecord()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final bytes = await _buildPdfBytes();
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: _documentName,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not print: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _exportPdf() async {
    // File the record first so the export is never the only copy, and so the
    // PDF can be named after the patient rather than just the form.
    if (!await _persistRecord()) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final pdfBytes = await _buildPdfBytes();
      final fileName =
          '${_documentName}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _ensureStoragePermission();
      await _writePdfBytes(pdfBytes, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF5D4B8A),
            content: const Text(
              'Case saved successfully',
              style: TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4B8A),
        foregroundColor: Colors.white,
        title: Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Derrick',
            color: Colors.white,
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _redoStack.isEmpty ? null : _redo,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: _saving ? null : _printPdf,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saving ? null : _saveDraftAndExit,
            tooltip: 'Continue later',
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_alt),
              onPressed: _exportPdf,
              tooltip: 'Save',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF2D2D44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1: mode selector + zoom controls
          Row(
            children: [
              _ModeButton(
                icon: Icons.draw,
                active: _mode == _Mode.draw,
                onTap: () => setState(() {
                  _mode = _mode == _Mode.draw ? _Mode.none : _Mode.draw;
                }),
                tooltip: 'Draw',
              ),
              _ModeButton(
                icon: Icons.text_fields,
                active: _mode == _Mode.text,
                onTap: () => setState(() {
                  _mode = _mode == _Mode.text ? _Mode.none : _Mode.text;
                  _erasing = false;
                }),
                tooltip: 'Add text',
              ),
              _ModeButton(
                icon: Icons.pan_tool_alt_rounded,
                active: _mode == _Mode.pan,
                onTap: () => setState(() {
                  _mode = _mode == _Mode.pan ? _Mode.none : _Mode.pan;
                  _erasing = false;
                }),
                tooltip: 'Pan & scroll',
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: Colors.white24),
              const SizedBox(width: 8),
              _ToolbarIcon(
                icon: Icons.zoom_out,
                onTap: () => _zoomAllBy(1 / 1.25),
                tooltip: 'Zoom out',
              ),
              _ToolbarIcon(
                icon: Icons.zoom_in,
                onTap: () => _zoomAllBy(1.25),
                tooltip: 'Zoom in',
              ),
              _ToolbarIcon(
                icon: Icons.zoom_out_map,
                onTap: _resetAllZoom,
                tooltip: 'Reset zoom',
              ),
              const Spacer(),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _mode == _Mode.none
                        ? 'Pick a tool'
                        : 'Two fingers to scroll · pinch to zoom',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Row 2: contextual sub-toolbar based on selected mode
          if (_mode != _Mode.none) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                ..._colors.map(
                  (c) => GestureDetector(
                    onTap: () => setState(() {
                      _color = c;
                      _erasing = false;
                    }),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: !_erasing && _color == c
                              ? Colors.white
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                if (_mode == _Mode.text) ...[
                  const Icon(Icons.format_size, color: Colors.white, size: 18),
                  Expanded(
                    child: Slider(
                      value: _textSize,
                      min: 10,
                      max: 48,
                      activeColor: _color,
                      inactiveColor: Colors.white24,
                      onChanged: (v) => setState(() => _textSize = v),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      _textSize.toStringAsFixed(0),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () => setState(() => _erasing = !_erasing),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _erasing ? Colors.white24 : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.auto_fix_normal,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                  // The one slider sizes whichever tool is in hand. The eraser
                  // starts small so a single wrong tick can be lifted out of a
                  // line, and zooming in makes it finer still.
                  if (_erasing)
                    Expanded(
                      child: Slider(
                        value: _eraserWidth,
                        min: 4,
                        max: 32,
                        activeColor: Colors.white,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _eraserWidth = v),
                      ),
                    )
                  else
                    Expanded(
                      child: Slider(
                        value: _penWidth,
                        min: 1,
                        max: 12,
                        activeColor: _color,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _penWidth = v),
                      ),
                    ),
                  if (_erasing)
                    Icon(
                      Icons.circle_outlined,
                      color: Colors.white,
                      size: (_eraserWidth * 1.2 + 6).clamp(10.0, 34.0),
                    )
                  else
                    Icon(Icons.circle, color: _color, size: _penWidth * 2 + 4),
                ],
                const SizedBox(width: 6),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(
          'Failed to load PDF: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_pageImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF8F6BFF)),
            SizedBox(height: 12),
            Text(
              'Loading chart...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Row(
      children: [
        Expanded(
          // Two fingers anywhere on the chart scroll it, so the pages can be
          // moved through over the charting itself instead of only by the
          // handle down the side. A single finger stays the pen, which is why
          // the list itself never takes drags.
          child: Listener(
            onPointerDown: _onViewportPointerDown,
            onPointerMove: _onViewportPointerMove,
            onPointerUp: _onViewportPointerFinished,
            onPointerCancel: _onViewportPointerFinished,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: _mode == _Mode.pan
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              child: Column(
                children: [
                  for (int page = 1; page <= _pageImages.length; page++)
                    _buildPage(page),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        _ScrollHandle(controller: _scrollController),
      ],
    );
  }

  Widget _buildPage(int page) {
    final imageBytes = _pageImages[page];
    if (imageBytes == null) return const SizedBox.shrink();
    final aspect = _pageAspectRatios[page] ?? (1 / 1.4142);
    final zoom = _zoomFor(page);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: aspect,
            child: ClipRect(
              child: InteractiveViewer(
                transformationController: zoom,
                panEnabled: _mode == _Mode.pan,
                scaleEnabled: true,
                minScale: 1.0,
                maxScale: 5.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _recordPageSize(
                      page,
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                    return Stack(
                      children: [
                        RepaintBoundary(
                          key: _keyFor(page),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(imageBytes, fit: BoxFit.fill),
                              // Card/control number, stamped into the form's
                              // own field. It is issued by the app rather than
                              // typed, which is why the field stays locked —
                              // and why this is painted inside the
                              // RepaintBoundary, so the number is part of
                              // anything exported or printed.
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _ControlNumberPainter(
                                      code: _patientCode ?? '',
                                      regions: lockedRegionsForPage(
                                        widget.editablePdfPath,
                                        page,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Draw / tap overlay (below labels so labels stay
                              // interactive in text mode)
                              Positioned.fill(
                                child: Listener(
                                  behavior: HitTestBehavior.opaque,
                                  onPointerSignal: (event) {
                                    if (event is PointerScrollEvent &&
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed) {
                                      final factor = event.scrollDelta.dy < 0
                                          ? 1.15
                                          : 1 / 1.15;
                                      _zoomPageBy(
                                        page,
                                        factor,
                                        event.localPosition,
                                      );
                                    }
                                  },
                                  onPointerDown: (e) =>
                                      _onDrawPointerDown(e, page),
                                  onPointerMove: (e) =>
                                      _onDrawPointerMove(e, page),
                                  onPointerUp: (e) => _onDrawPointerUp(e, page),
                                  onPointerCancel: (e) =>
                                      _onDrawPointerCancel(e, page),
                                  child: CustomPaint(
                                    painter: _DrawingPainter(_strokesFor(page)),
                                    // The stroke under the pointer gets its own
                                    // layer: it repaints on every pointer move,
                                    // and the committed ink underneath does not
                                    // have to be redrawn with it.
                                    child: RepaintBoundary(
                                      child: CustomPaint(
                                        painter: _ActiveStrokePainter(
                                          active: _active,
                                          page: page,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Text labels on top so they can be tapped/dragged
                              for (final label in _textLabelsFor(page))
                                Positioned(
                                  key: ObjectKey(label),
                                  left: label.position.dx,
                                  top: label.position.dy,
                                  child: IgnorePointer(
                                    // Only the text tool picks labels up. In
                                    // draw mode a label used to swallow the
                                    // pointer, which is why parts of the chart
                                    // could not be written on once something
                                    // had been typed there.
                                    ignoring: _mode != _Mode.text,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _editTextLabel(page, label),
                                      onLongPress: () {
                                        final list = _textLabelsFor(page);
                                        final idx = list.indexOf(label);
                                        if (idx == -1) return;
                                        setState(() => list.removeAt(idx));
                                        _pushAction(
                                          _Action(
                                            undo: () => _textLabelsFor(
                                              page,
                                            ).insert(idx, label),
                                            redo: () => _textLabelsFor(
                                              page,
                                            ).remove(label),
                                          ),
                                        );
                                      },
                                      onPanUpdate: (d) {
                                        // d.delta is in screen pixels while the
                                        // label is positioned in page pixels, so
                                        // at any zoom other than 1x an uncorrected
                                        // delta makes the text outrun the finger.
                                        final scale = _scaleFor(page);
                                        final next =
                                            label.position +
                                            (scale == 0
                                                ? d.delta
                                                : d.delta / scale);
                                        // Don't let a label be dragged into the
                                        // protected patient field, or off the page.
                                        if (_isLocked(page, next)) return;
                                        setState(
                                          () => label.position = _clampToPage(
                                            page,
                                            next,
                                          ),
                                        );
                                      },
                                      onPanEnd: (_) => setState(() {
                                        // Seat it back on a rule after the move,
                                        // the same way it was placed.
                                        label.position = _snapToLine(
                                          page,
                                          label.position,
                                          label.fontSize,
                                        );
                                      }),
                                      child: FractionalTranslation(
                                        translation: const Offset(0.0, -0.5),
                                        child: Text(
                                          label.text,
                                          style: TextStyle(
                                            color: label.color,
                                            fontSize: label.fontSize,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [
                                              Shadow(
                                                blurRadius: 2,
                                                color: Colors.white,
                                                offset: Offset(0.5, 0.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Lock overlay — visual cue only, drawn outside the
                        // RepaintBoundary so it never appears in the export.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _LockOverlayPainter(
                                lockedRegionsForPage(
                                  widget.editablePdfPath,
                                  page,
                                ),
                                showGlyph: (_patientCode ?? '').isEmpty,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          // Zoom reset chip (only shown when zoomed in)
          AnimatedBuilder(
            animation: zoom,
            builder: (context, _) {
              if (_scaleFor(page) <= 1.01) return const SizedBox.shrink();
              return Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => _resetZoom(page),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.zoom_out_map,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Clear-page chip (top-left, only when this page has annotations).
          if ((_strokes[page]?.isNotEmpty ?? false) ||
              (_textLabels[page]?.isNotEmpty ?? false))
            Positioned(
              top: 6,
              left: 6,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _clearPage(page),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.layers_clear_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Text input dialog ─────────────────────────────────────────────────────────

class _TextInputDialog extends StatefulWidget {
  final String initialText;
  final double initialFontSize;
  final Color color;

  const _TextInputDialog({
    required this.initialText,
    required this.initialFontSize,
    required this.color,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  late double _fontSize;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _fontSize = widget.initialFontSize;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(
    context,
    _TextDialogResult(_controller.text.trim(), _fontSize),
  );

  @override
  Widget build(BuildContext context) {
    final editing = widget.initialText.isNotEmpty;
    return AlertDialog(
      backgroundColor: const Color(0xFF2D2D44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        editing ? 'Edit text' : 'Add text',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              color: widget.color,
              fontSize: _fontSize,
              fontWeight: FontWeight.bold,
            ),
            cursorColor: widget.color,
            decoration: InputDecoration(
              hintText: 'Enter text...',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.format_size, color: Colors.white70, size: 18),
              Expanded(
                child: Slider(
                  value: _fontSize,
                  min: 10,
                  max: 48,
                  activeColor: widget.color,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _fontSize = v),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  _fontSize.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (editing)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, const _TextDialogResult('', 0)),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8F6BFF),
          ),
          onPressed: _submit,
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ── Toolbar mode button ───────────────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String? tooltip;

  const _ModeButton({
    required this.icon,
    required this.active,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? Colors.white38 : Colors.transparent,
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  const _ToolbarIcon({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final btn = InkResponse(
      onTap: onTap,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

// ── Custom scroll handle ──────────────────────────────────────────────────────
// Directly calls jumpTo() so it works even with NeverScrollableScrollPhysics.

class _ScrollHandle extends StatelessWidget {
  final ScrollController controller;
  const _ScrollHandle({required this.controller});

  bool get _ready =>
      controller.hasClients &&
      controller.position.hasContentDimensions &&
      controller.position.maxScrollExtent > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!_ready) return const SizedBox(width: 18);

        final maxScroll = controller.position.maxScrollExtent;
        final offset = controller.offset;

        return Container(
          width: 18,
          color: const Color(0xFF1A1A2E),
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              const thumbFraction = 0.15;
              final trackH = constraints.maxHeight;
              final thumbH = trackH * thumbFraction;
              final thumbTop = (offset / maxScroll) * (trackH - thumbH);

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (d) {
                  if (!_ready) return;
                  final live = controller.offset;
                  final liveMax = controller.position.maxScrollExtent;
                  final scrollPerPx = liveMax / (trackH - thumbH);
                  controller.jumpTo(
                    (live + d.delta.dy * scrollPerPx).clamp(0.0, liveMax),
                  );
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(color: const Color(0xFF2D2D44)),
                    ),
                    Positioned(
                      top: thumbTop,
                      left: 3,
                      right: 3,
                      height: thumbH,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white38,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Painter ───────────────────────────────────────────────────────────────────

/// The ink already committed to a page.
class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;

  const _DrawingPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      paintStroke(canvas, stroke);
    }
  }

  /// Draws one stroke. Points are joined through their midpoints with quadratic
  /// curves rather than straight lines, so handwriting comes out smooth instead
  /// of showing every sample as a corner. A stroke holding a single point is a
  /// deliberate dot — a tick or a decimal point — and is drawn as one; the old
  /// painter skipped those entirely.
  static void paintStroke(Canvas canvas, _Stroke stroke) {
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        stroke.width / 2,
        Paint()
          ..color = stroke.color
          ..style = PaintingStyle.fill,
      );
      return;
    }
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final mid = Offset(
        (points[i].dx + points[i + 1].dx) / 2,
        (points[i].dy + points[i + 1].dy) / 2,
      );
      path.quadraticBezierTo(points[i].dx, points[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}

/// Paints only the stroke under the pointer, repainting straight off
/// [_ActiveStroke] instead of a widget rebuild so the ink keeps pace with the
/// pen.
class _ActiveStrokePainter extends CustomPainter {
  final _ActiveStroke active;
  final int page;

  _ActiveStrokePainter({required this.active, required this.page})
    : super(repaint: active);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = active.stroke;
    if (stroke == null || active.page != page) return;
    _DrawingPainter.paintStroke(canvas, stroke);
  }

  @override
  bool shouldRepaint(_ActiveStrokePainter old) =>
      old.active != active || old.page != page;
}

/// Stamps the app-issued card/control number into the form's own field.
///
/// The field is a locked region that nothing else may write in, and this is what
/// fills it. Unlike the lock tint it is painted inside the page's
/// RepaintBoundary, so the number is part of every exported and printed copy.
class _ControlNumberPainter extends CustomPainter {
  final String code;
  final List<Rect> regions;

  const _ControlNumberPainter({required this.code, required this.regions});

  @override
  void paint(Canvas canvas, Size size) {
    if (code.isEmpty || regions.isEmpty) return;
    for (final normalized in regions) {
      final rect = Rect.fromLTRB(
        normalized.left * size.width,
        normalized.top * size.height,
        normalized.right * size.width,
        normalized.bottom * size.height,
      );
      if (rect.width < 24 || rect.height < 8) continue;

      // Start from the height of the field and step down until the number fits
      // along it: the same rect has to hold codes of different lengths on forms
      // whose fields are different sizes.
      var fontSize = rect.height * 0.7;
      late TextPainter painter;
      while (true) {
        painter = TextPainter(
          text: TextSpan(
            text: code,
            style: TextStyle(
              color: const Color(0xFF15151F),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        if (painter.width <= rect.width - 8 || fontSize <= 6) break;
        fontSize -= 0.5;
      }
      painter.paint(
        canvas,
        Offset(rect.left + 4, rect.center.dy - painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_ControlNumberPainter old) =>
      old.code != code || !listEquals(old.regions, regions);
}

// ── Locked-region overlay ─────────────────────────────────────────────────────
// Shades the protected patient field with a subtle tint, a hatched border and a
// small lock glyph. Normalised rects (0..1) are scaled to the paint size. This
// is purely a visual cue and is never part of the exported PDF.

class _LockOverlayPainter extends CustomPainter {
  final List<Rect> normalizedRects;

  /// Suppressed once the control number has been stamped into the field: the
  /// glyph sits exactly where the number is drawn.
  final bool showGlyph;

  const _LockOverlayPainter(this.normalizedRects, {this.showGlyph = true});

  @override
  void paint(Canvas canvas, Size size) {
    if (normalizedRects.isEmpty) return;
    final fill = Paint()..color = const Color(0x14000000);
    final border = Paint()
      ..color = const Color(0x665D4B8A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final n in normalizedRects) {
      final rect = Rect.fromLTRB(
        n.left * size.width,
        n.top * size.height,
        n.right * size.width,
        n.bottom * size.height,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, border);

      if (!showGlyph) continue;
      // Tiny lock glyph in the top-left corner of the region.
      final tp = TextPainter(
        text: const TextSpan(text: '\u{1F512}', style: TextStyle(fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      if (rect.width > tp.width + 6 && rect.height > tp.height) {
        tp.paint(canvas, rect.topLeft + const Offset(3, 1));
      }
    }
  }

  @override
  bool shouldRepaint(_LockOverlayPainter old) =>
      old.normalizedRects != normalizedRects;
}
