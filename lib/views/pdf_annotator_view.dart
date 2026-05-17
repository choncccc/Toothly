import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodel/home_viewmodel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _Mode { none, draw, text }

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
  _Mode _mode = _Mode.none;
  bool _saving = false;
  String? _error;

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
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
    setState(() {
      _strokesFor(page).add(_active!);
      _active = null;
      _drawingPage = -1;
    });
  }

  void _undo() {
    for (int i = (_doc?.pagesCount ?? 0); i >= 1; i--) {
      final labels = _textLabels[i];
      if (labels != null && labels.isNotEmpty) {
        setState(() => labels.removeLast());
        return;
      }
    }
    for (int i = (_doc?.pagesCount ?? 0); i >= 1; i--) {
      final s = _strokes[i];
      if (s != null && s.isNotEmpty) {
        setState(() => s.removeLast());
        return;
      }
    }
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
      setState(() {
        _textSize = result.fontSize;
        _textLabelsFor(page).add(
          _TextLabel(
            position: position,
            text: result.text,
            color: _color,
            fontSize: result.fontSize,
          ),
        );
      });
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
    setState(() {
      if (result.text.isEmpty) {
        _textLabelsFor(page).remove(label);
      } else {
        label.text = result.text;
        label.fontSize = result.fontSize;
      }
    });
  }

  // ── Save flow ─────────────────────────────────────────────────────────────

  Future<void> _confirmAndSave() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          'Save case?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Save this annotated chart to your Downloads folder and submit it as a completed case?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8F6BFF),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, save'),
          ),
        ],
      ),
    );
    if (ok == true) await _exportPdf();
  }

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

      final user = Supabase.instance.client.auth.currentUser;
      String? dbWarning;
      if (user != null) {
        final now = DateTime.now();
        final dateKey =
            DateTime(now.year, now.month, now.day).toIso8601String();
        final timeStr =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final row = {
          'user_id': user.id,
          'date': dateKey,
          'title': widget.title,
          'notes': 'Completed case saved to: $savedPath',
          'time': timeStr,
          'case_type': widget.title,
        };
        try {
          await Supabase.instance.client.from('appointments').insert(row);
        } on PostgrestException catch (e) {
          dbWarning = 'Saved locally, but DB sync failed: ${e.message}';
        }
        try {
          await Supabase.instance.client.rpc(
            'increment_cases_completed',
            params: {'user_id': user.id},
          );
          if (mounted) {
            await context.read<HomeViewmodel>().refresh();
          }
        } catch (_) {
          // Non-fatal; counter just won't bump.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: dbWarning == null
                ? const Color(0xFF5D4B8A)
                : Colors.orange.shade800,
            content: Text(
              dbWarning ?? 'Saved to: $savedPath',
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
          widget.title,
          style: const TextStyle(
            fontFamily: 'Derrick',
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
            tooltip: 'Undo',
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
              onPressed: _confirmAndSave,
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
            physics: const NeverScrollableScrollPhysics(),
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
                panEnabled: false,
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
                            onLongPress: () => setState(
                              () => _textLabelsFor(page).remove(label),
                            ),
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
