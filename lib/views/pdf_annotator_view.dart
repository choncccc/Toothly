import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../viewmodel/home_viewmodel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  const _Stroke(this.points, this.color, this.width);
}

class _TextLabel {
  final Offset position;
  final String text;
  final Color color;
  const _TextLabel({required this.position, required this.text, required this.color});
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
  final Map<int, List<_Stroke>> _strokes = {};
  final Map<int, List<_TextLabel>> _textLabels = {};
  final Map<int, GlobalKey> _repaintKeys = {};
  final ScrollController _scrollController = ScrollController();

  _Stroke? _active;
  int _drawingPage = -1;
  Color _color = Colors.blue;
  double _penWidth = 3.0;
  bool _erasing = false;
  bool _textMode = false;
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

  GlobalKey _keyFor(int page) =>
      _repaintKeys.putIfAbsent(page, () => GlobalKey());

  List<_Stroke> _strokesFor(int page) => _strokes.putIfAbsent(page, () => []);
  List<_TextLabel> _textLabelsFor(int page) =>
      _textLabels.putIfAbsent(page, () => []);

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
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _TextInputDialog(),
    );
    if (text != null && text.isNotEmpty && mounted) {
      setState(() => _textLabelsFor(page).add(
        _TextLabel(position: position, text: text, color: _color),
      ));
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _saving = true);
    try {
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

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          '${widget.title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdfDoc.save());

      await Share.shareXFiles([XFile(file.path)], subject: widget.title);

      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        await Supabase.instance.client.rpc(
          'increment_cases_completed',
          params: {'user_id': user.id},
        );
        if (mounted) {
          await context.read<HomeViewmodel>().refresh();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
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
              icon: const Icon(Icons.ios_share),
              onPressed: _exportPdf,
              tooltip: 'Export & Share',
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
      child: Row(
        children: [
          // Draw / Text mode toggle
          _ModeButton(
            icon: Icons.draw,
            active: !_textMode,
            onTap: () => setState(() => _textMode = false),
          ),
          _ModeButton(
            icon: Icons.text_fields,
            active: _textMode,
            onTap: () => setState(() {
              _textMode = true;
              _erasing = false;
            }),
          ),
          const SizedBox(width: 4),
          // Color swatches
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
          if (!_textMode) ...[
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
          ] else
            const Spacer(),
          const SizedBox(width: 6),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black45, blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: RepaintBoundary(
        key: _keyFor(page),
        child: Stack(
          children: [
            Image.memory(imageBytes, fit: BoxFit.contain),
            // Text labels
            for (final label in _textLabelsFor(page))
              Positioned(
                key: ObjectKey(label),
                left: label.position.dx,
                top: label.position.dy,
                child: GestureDetector(
                  onLongPress: () =>
                      setState(() => _textLabelsFor(page).remove(label)),
                  child: Text(
                    label.text,
                    style: TextStyle(
                      color: label.color,
                      fontSize: 16,
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
            // Drawing / tap overlay
            Positioned.fill(
              key: const ValueKey('draw-layer'),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: _textMode ? null : (d) => _startStroke(d, page),
                onPanUpdate: _textMode ? null : (d) => _updateStroke(d, page),
                onPanEnd: _textMode ? null : (d) => _endStroke(d, page),
                onTapUp: _textMode
                    ? (d) => _addTextLabel(page, d.localPosition)
                    : null,
                child: CustomPaint(
                  painter: _DrawingPainter(
                    strokes: _strokesFor(page),
                    active: _drawingPage == page ? _active : null,
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

// ── Text input dialog ─────────────────────────────────────────────────────────

class _TextInputDialog extends StatefulWidget {
  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter text...'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Add'),
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

  const _ModeButton({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
