import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../services/local/draft_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:permission_handler/permission_handler.dart';

enum _Mode { none, draw, text, pan }

class _Action {
  final VoidCallback undo;
  final VoidCallback redo;
  const _Action({required this.undo, required this.redo});
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  const _Stroke(this.points, this.color, this.width);
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

class _TextDialogResult {
  final String text;
  final double fontSize;
  const _TextDialogResult(this.text, this.fontSize);
}

class PdfAnnotatorView extends StatefulWidget {
  final String title;
  final String editablePdfPath;
  final List<String> companionPdfPaths;

  const PdfAnnotatorView({
    super.key,
    required this.title,
    required this.editablePdfPath,
    this.companionPdfPaths = const [],
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
  final ScrollController _scrollController = ScrollController();

  _Stroke? _active;
  int _drawingPage = -1;
  Color _color = Colors.blue;
  double _penWidth = 3.0;
  double _textSize = 16.0;
  bool _erasing = false;
  _Mode _mode = _Mode.draw;
  bool _saving = false;
  String? _error;

  final List<_Action> _undoStack = [];
  final List<_Action> _redoStack = [];

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
    _loadDocument();
  }

  @override
  void dispose() {
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
        await _maybeRestoreDraft();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // ── Draft persistence ─────────────────────────────────────────────────────

  Future<File> _draftFile() => DraftStore.fileFor(widget.editablePdfPath);

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
          .map((s) => {
                'color': _encodeColor(s.color),
                'width': s.width,
                'points': s.points
                    .map((o) => [o.dx, o.dy])
                    .toList(growable: false),
              })
          .toList();
    });
    final labels = <String, dynamic>{};
    _textLabels.forEach((page, list) {
      labels['$page'] = list
          .map((l) => {
                'x': l.position.dx,
                'y': l.position.dy,
                'text': l.text,
                'color': _encodeColor(l.color),
                'fontSize': l.fontSize,
              })
          .toList();
    });
    return {
      'savedAt': DateTime.now().toIso8601String(),
      'title': widget.title,
      'editablePdfPath': widget.editablePdfPath,
      'companionPdfPaths': widget.companionPdfPaths,
      'strokes': strokes,
      'labels': labels,
    };
  }

  void _applyDraft(Map<String, dynamic> data) {
    final strokesJson = (data['strokes'] as Map?)?.cast<String, dynamic>();
    final labelsJson = (data['labels'] as Map?)?.cast<String, dynamic>();
    _strokes.clear();
    _textLabels.clear();
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

  Future<void> _maybeRestoreDraft() async {
    try {
      final f = await _draftFile();
      if (!f.existsSync()) return;
      final json = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      if (!mounted) return;
      final restore = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF2D2D44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Continue draft?',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'You have unsaved annotations for this case. Restore them?',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF8F6BFF),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (restore == true) {
        if (!mounted) return;
        setState(() => _applyDraft(json));
      } else {
        await _clearDraft();
      }
    } catch (_) {
      // Corrupt draft — silently ignore.
    }
  }

  Future<void> _clearDraft() async {
    try {
      final f = await _draftFile();
      if (f.existsSync()) await f.delete();
    } catch (_) {}
  }

  Future<void> _saveDraftAndExit() async {
    try {
      final f = await _draftFile();
      await f.writeAsString(jsonEncode(_serializeDraft()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF5D4B8A),
          content: Text(
            'Draft saved. You can continue later.',
            style: TextStyle(color: Colors.white),
          ),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save draft: $e')),
      );
    }
  }

  GlobalKey _keyFor(int page) =>
      _repaintKeys.putIfAbsent(page, () => GlobalKey());

  TransformationController _zoomFor(int page) => _zoomControllers.putIfAbsent(
    page,
    () => TransformationController(),
  );

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

  void _startStroke(DragStartDetails d, int page) => setState(() {
    _drawingPage = page;
    _active = _Stroke(
      [d.localPosition],
      _erasing ? Colors.white : _color,
      _erasing ? 22.0 : _penWidth,
    );
  });

  void _updateStroke(DragUpdateDetails d, int page) {
    if (_active == null || _drawingPage != page) return;
    setState(() {
      _active = _Stroke(
        [..._active!.points, d.localPosition],
        _active!.color,
        _active!.width,
      );
    });
  }

  void _endStroke(DragEndDetails d, int page) {
    if (_active == null) return;
    final added = _active!;
    setState(() {
      _strokesFor(page).add(added);
      _active = null;
      _drawingPage = -1;
    });
    _pushAction(_Action(
      undo: () => _strokesFor(page).remove(added),
      redo: () => _strokesFor(page).add(added),
    ));
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Clear page?',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Remove all annotations from page $page?',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
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
    _pushAction(_Action(
      undo: () {
        _strokes[page] = List<_Stroke>.from(prevStrokes);
        _textLabels[page] = List<_TextLabel>.from(prevLabels);
      },
      redo: () {
        _strokes[page] = [];
        _textLabels[page] = [];
      },
    ));
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
        position: position,
        text: result.text,
        color: _color,
        fontSize: result.fontSize,
      );
      setState(() {
        _textSize = result.fontSize;
        _textLabelsFor(page).add(label);
      });
      _pushAction(_Action(
        undo: () => _textLabelsFor(page).remove(label),
        redo: () => _textLabelsFor(page).add(label),
      ));
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
      _pushAction(_Action(
        undo: () => _textLabelsFor(page).insert(idx, label),
        redo: () => _textLabelsFor(page).remove(label),
      ));
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

  Future<String> _writePdfBytes(Uint8List bytes, String fileName) async {
    if (Platform.isAndroid) {
      final downloads = Directory('/storage/emulated/0/Download');
      try {
        if (!downloads.existsSync()) {
          downloads.createSync(recursive: true);
        }
        final f = File('${downloads.path}/$fileName');
        await f.writeAsBytes(bytes);
        return f.path;
      } catch (_) {
        // fall through to app-internal fallback
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes);
    return f.path;
  }

  Future<void> _exportPdf() async {
    setState(() => _saving = true);
    try {
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

      final pdfBytes = await pdfDoc.save();
      final fileName =
          '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      await _ensureStoragePermission();
      final savedPath = await _writePdfBytes(pdfBytes, fileName);

      // Case is complete — drop any leftover draft.
      await _clearDraft();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF5D4B8A),
            content: Text(
              'Saved to: $savedPath',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
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
              Container(
                width: 1,
                height: 24,
                color: Colors.white24,
              ),
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
              if (_mode == _Mode.none)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Pick a tool',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
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
                  const Icon(Icons.format_size,
                      color: Colors.white, size: 18),
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
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ] else ...[
                  GestureDetector(
                    onTap: () => setState(() => _erasing = !_erasing),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color:
                            _erasing ? Colors.white24 : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.auto_fix_normal,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
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
                child: RepaintBoundary(
                  key: _keyFor(page),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(imageBytes, fit: BoxFit.fill),
                      // Draw / tap overlay (below labels so labels stay interactive)
                      Positioned.fill(
                        child: Listener(
                          onPointerSignal: (event) {
                            if (event is PointerScrollEvent &&
                                HardwareKeyboard
                                    .instance.isControlPressed) {
                              final factor =
                                  event.scrollDelta.dy < 0 ? 1.15 : 1 / 1.15;
                              _zoomPageBy(page, factor, event.localPosition);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: _mode == _Mode.draw
                                ? (d) => _startStroke(d, page)
                                : null,
                            onPanUpdate: _mode == _Mode.draw
                                ? (d) => _updateStroke(d, page)
                                : null,
                            onPanEnd: _mode == _Mode.draw
                                ? (d) => _endStroke(d, page)
                                : null,
                            onTapUp: _mode == _Mode.text
                                ? (d) => _addTextLabel(page, d.localPosition)
                                : null,
                            child: CustomPaint(
                              painter: _DrawingPainter(
                                strokes: _strokesFor(page),
                                active:
                                    _drawingPage == page ? _active : null,
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
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _editTextLabel(page, label),
                            onLongPress: () {
                              final list = _textLabelsFor(page);
                              final idx = list.indexOf(label);
                              if (idx == -1) return;
                              setState(() => list.removeAt(idx));
                              _pushAction(_Action(
                                undo: () => _textLabelsFor(page)
                                    .insert(idx, label),
                                redo: () =>
                                    _textLabelsFor(page).remove(label),
                              ));
                            },
                            onPanUpdate: (d) => setState(
                              () => label.position += d.delta,
                            ),
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
                    ],
                  ),
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
                          Icon(Icons.zoom_out_map,
                              color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.layers_clear_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white70)),
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

  const _ToolbarIcon({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

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

class _DrawingPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final _Stroke? active;

  const _DrawingPainter({required this.strokes, this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final all = [...strokes, if (active != null) active!];
    for (final s in all) {
      if (s.points.length < 2) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (int i = 1; i < s.points.length; i++) {
        path.lineTo(s.points[i].dx, s.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DrawingPainter old) => true;
}
