import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';

enum _Mode { draw, text }

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  const _Stroke(this.points, this.color, this.width);
}

class _TextNote {
  Offset position;
  String text;
  Color color;
  double fontSize;
  _TextNote({
    required this.position,
    required this.text,
    this.color = Colors.black,
    this.fontSize = 14,
  });
}

/// Annotate [editablePdfPath] with freehand drawing or tap-to-place text.
/// On export, merges annotated pages with [companionPdfPaths] into one PDF.
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
  // PDF
  pdfx.PdfDocument? _doc;
  final Map<int, Uint8List> _pageImages = {};
  final Map<int, GlobalKey> _repaintKeys = {};
  String? _error;

  // Mode
  _Mode _mode = _Mode.draw;

  // Drawing state
  final Map<int, List<_Stroke>> _pageStrokes = {};
  _Stroke? _activeStroke;
  int _drawingPage = -1;
  Color _penColor = Colors.blue;
  double _penWidth = 3.0;
  bool _erasing = false;

  // Text state
  final Map<int, List<_TextNote>> _pageNotes = {};
  Color _textColor = Colors.black;
  double _fontSize = 14.0;

  // Export
  bool _saving = false;
  bool _exporting = false;

  static const _colors = [
    Colors.black,
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
  ];

  static const _fontSizes = <String, double>{'S': 11, 'M': 14, 'L': 18};

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _doc?.close();
    super.dispose();
  }

  // ─── PDF loading ────────────────────────────────────────────────────────────

  Future<pdfx.PdfDocument> _openAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final safeName = assetPath.split('/').last.replaceAll(' ', '_');
    final tmp = File('${dir.path}/$safeName');
    await tmp.writeAsBytes(data.buffer.asUint8List());
    return pdfx.PdfDocument.openFile(tmp.path);
  }

  Future<void> _loadDocument() async {
    try {
      final doc = await _openAsset(widget.editablePdfPath);
      final images = <int, Uint8List>{};
      for (int i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
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
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  GlobalKey _keyFor(int page) =>
      _repaintKeys.putIfAbsent(page, () => GlobalKey());

  List<_Stroke> _strokesFor(int page) =>
      _pageStrokes.putIfAbsent(page, () => []);

  List<_TextNote> _notesFor(int page) =>
      _pageNotes.putIfAbsent(page, () => []);

  // ─── Drawing ────────────────────────────────────────────────────────────────

  void _startStroke(DragStartDetails d, int page) => setState(() {
        _drawingPage = page;
        _activeStroke = _Stroke(
          [d.localPosition],
          _erasing ? Colors.white : _penColor,
          _erasing ? 22.0 : _penWidth,
        );
      });

  void _updateStroke(DragUpdateDetails d, int page) {
    if (_activeStroke == null || _drawingPage != page) return;
    setState(() {
      _activeStroke = _Stroke(
        [..._activeStroke!.points, d.localPosition],
        _activeStroke!.color,
        _activeStroke!.width,
      );
    });
  }

  void _endStroke(DragEndDetails d, int page) {
    if (_activeStroke == null) return;
    setState(() {
      _strokesFor(page).add(_activeStroke!);
      _activeStroke = null;
      _drawingPage = -1;
    });
  }

  // ─── Text ───────────────────────────────────────────────────────────────────

  Future<void> _onPageTap(TapUpDetails details, int page) async {
    final text = await _showTextDialog(context);
    if (text == null || text.trim().isEmpty) return;
    setState(() {
      _notesFor(page).add(_TextNote(
        position: details.localPosition,
        text: text.trim(),
        color: _textColor,
        fontSize: _fontSize,
      ));
    });
  }

  Future<void> _onNoteTap(_TextNote note, int page) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Text Note'),
        content: Text(note.text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'edit'),
            child: const Text('Edit'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (action == 'delete') {
      setState(() => _notesFor(page).remove(note));
    } else if (action == 'edit') {
      if (!mounted) return;
      final updated = await _showTextDialog(context, initial: note.text);
      if (updated != null && updated.trim().isNotEmpty) {
        setState(() => note.text = updated.trim());
      }
    }
  }

  Future<String?> _showTextDialog(BuildContext context,
      {String initial = ''}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? 'Add Text' : 'Edit Text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'Type here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Undo ───────────────────────────────────────────────────────────────────

  void _undo() {
    // Undo the most recent annotation (stroke or note) across all pages
    int lastStrokePage = -1;
    int lastNotePage = -1;

    for (int i = 1; i <= (_doc?.pagesCount ?? 0); i++) {
      if ((_pageStrokes[i]?.isNotEmpty ?? false)) lastStrokePage = i;
      if ((_pageNotes[i]?.isNotEmpty ?? false)) lastNotePage = i;
    }

    if (lastStrokePage == -1 && lastNotePage == -1) return;

    setState(() {
      if (_mode == _Mode.draw && lastStrokePage != -1) {
        _pageStrokes[lastStrokePage]!.removeLast();
      } else if (_mode == _Mode.text && lastNotePage != -1) {
        _pageNotes[lastNotePage]!.removeLast();
      } else if (lastStrokePage != -1) {
        _pageStrokes[lastStrokePage]!.removeLast();
      } else {
        _pageNotes[lastNotePage]!.removeLast();
      }
    });
  }

  // ─── Export ─────────────────────────────────────────────────────────────────

  Future<void> _exportPdf() async {
    setState(() {
      _saving = true;
      _exporting = true;
    });

    await WidgetsBinding.instance.endOfFrame;

    try {
      final pdfDoc = pw.Document();

      for (int page = 1; page <= (_doc?.pagesCount ?? 0); page++) {
        final key = _repaintKeys[page];
        if (key?.currentContext == null) continue;
        final boundary =
            key!.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        final aspectRatio = image.width / image.height;
        final pageHeight = PdfPageFormat.a4.width / aspectRatio;
        pdfDoc.addPage(pw.Page(
          pageFormat:
              PdfPageFormat(PdfPageFormat.a4.width, pageHeight, marginAll: 0),
          build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
        ));
      }

      for (final assetPath in widget.companionPdfPaths) {
        final compDoc = await _openAsset(assetPath);
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
          pdfDoc.addPage(pw.Page(
            pageFormat: PdfPageFormat(PdfPageFormat.a4.width, pageHeight,
                marginAll: 0),
            build: (_) =>
                pw.Image(pw.MemoryImage(img.bytes), fit: pw.BoxFit.fill),
          ));
        }
        await compDoc.close();
      }

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdfDoc.save());
      await Share.shareXFiles([XFile(file.path)], subject: widget.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _exporting = false;
        });
      }
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5D4B8A),
        foregroundColor: Colors.white,
        title: Text(widget.title,
            style: const TextStyle(
                fontFamily: 'Derrick', color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
              icon: const Icon(Icons.undo),
              onPressed: _undo,
              tooltip: 'Undo'),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
          else
            IconButton(
                icon: const Icon(Icons.ios_share),
                onPressed: _exportPdf,
                tooltip: 'Export & Share'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        children: [
          // Mode toggle
          _ModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),

          const SizedBox(width: 10),
          Container(width: 1, height: 28, color: Colors.white24),
          const SizedBox(width: 10),

          // Draw controls
          if (_mode == _Mode.draw) ...[
            // Color swatches
            ..._colors.map((c) => GestureDetector(
                  onTap: () => setState(() {
                    _penColor = c;
                    _erasing = false;
                  }),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !_erasing && _penColor == c
                            ? Colors.white
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                )),
            const SizedBox(width: 6),
            // Eraser
            GestureDetector(
              onTap: () => setState(() => _erasing = !_erasing),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _erasing ? Colors.white24 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.auto_fix_normal,
                    color: Colors.white, size: 20),
              ),
            ),
            // Width slider
            Expanded(
              child: Slider(
                value: _penWidth,
                min: 1,
                max: 12,
                activeColor: _penColor,
                inactiveColor: Colors.white24,
                onChanged: (v) => setState(() => _penWidth = v),
              ),
            ),
            Icon(Icons.circle, color: _penColor, size: _penWidth * 2 + 4),
          ],

          // Text controls
          if (_mode == _Mode.text) ...[
            // Font size presets
            ..._fontSizes.entries.map((e) => GestureDetector(
                  onTap: () => setState(() => _fontSize = e.value),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _fontSize == e.value
                          ? const Color(0xFF8F6BFF)
                          : Colors.white12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(e.key,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                )),
            const SizedBox(width: 6),
            // Color swatches
            ..._colors.map((c) => GestureDetector(
                  onTap: () => setState(() => _textColor = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _textColor == c
                            ? Colors.white
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                )),
            const Spacer(),
            const Icon(Icons.touch_app, color: Colors.white38, size: 16),
            const SizedBox(width: 4),
            const Text('Tap to add',
                style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
          child: Text('Failed to load PDF: $_error',
              style: const TextStyle(color: Colors.red)));
    }
    if (_pageImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF8F6BFF)),
            SizedBox(height: 12),
            Text('Loading chart...',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        children: [
          for (int page = 1; page <= _pageImages.length; page++)
            _buildPage(page),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPage(int page) {
    final imageBytes = _pageImages[page];
    if (imageBytes == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: const BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: RepaintBoundary(
        key: _keyFor(page),
        child: Stack(
          children: [
            Image.memory(imageBytes, fit: BoxFit.contain),

            // Drawing layer
            Positioned.fill(
              child: GestureDetector(
                behavior: _mode == _Mode.draw
                    ? HitTestBehavior.opaque
                    : HitTestBehavior.translucent,
                onPanStart:
                    _mode == _Mode.draw ? (d) => _startStroke(d, page) : null,
                onPanUpdate:
                    _mode == _Mode.draw ? (d) => _updateStroke(d, page) : null,
                onPanEnd:
                    _mode == _Mode.draw ? (d) => _endStroke(d, page) : null,
                onTapUp:
                    _mode == _Mode.text ? (d) => _onPageTap(d, page) : null,
                child: CustomPaint(
                  painter: _DrawingPainter(
                    strokes: _strokesFor(page),
                    active: _drawingPage == page ? _activeStroke : null,
                  ),
                ),
              ),
            ),

            // Text note overlays
            for (final note in _notesFor(page))
              Positioned(
                left: note.position.dx,
                top: note.position.dy,
                child: GestureDetector(
                  onTap: () => _onNoteTap(note, page),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: _exporting
                        ? null
                        : BoxDecoration(
                            border: Border.all(
                                color: Colors.blueAccent
                                    .withValues(alpha: 0.6),
                                width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                    child: Text(
                      note.text,
                      style: TextStyle(
                        color: note.color,
                        fontSize: note.fontSize,
                        fontFamily: 'Roboto',
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Mode toggle widget ───────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab(Icons.edit, _Mode.draw, 'Draw'),
          _tab(Icons.text_fields, _Mode.text, 'Text'),
        ],
      ),
    );
  }

  Widget _tab(IconData icon, _Mode value, String label) {
    final active = mode == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF8F6BFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Drawing painter ─────────────────────────────────────────────────────────

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
