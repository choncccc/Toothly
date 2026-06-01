import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

// Palette ---------------------------------------------------------------------
const _primary = Color(0xFF5D4B8A);
const _purpleDeep = Color(0xFF8F6BFF);

/// Full-screen preview for an attached clinical-case file. Images are shown
/// zoomable, PDFs are rendered page-by-page, and anything else falls back to a
/// details card with a Share/Open action.
class FilePreviewView extends StatefulWidget {
  final String filePath;
  final String displayName;

  const FilePreviewView({
    super.key,
    required this.filePath,
    required this.displayName,
  });

  @override
  State<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends State<FilePreviewView> {
  PdfController? _pdfController;

  bool get _isImage =>
      (lookupMimeType(widget.filePath) ?? '').startsWith('image/');
  bool get _isPdf =>
      (lookupMimeType(widget.filePath) ?? '') == 'application/pdf';

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _pdfController = PdfController(
        document: PdfDocument.openFile(widget.filePath),
      );
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await Share.shareXFiles([XFile(widget.filePath)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isImage ? Colors.black : const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _primary,
        title: Text(
          widget.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _primary, fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: 'Share / Open',
            icon: const Icon(Icons.ios_share_rounded, color: _primary),
            onPressed: _share,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final file = File(widget.filePath);
    if (!file.existsSync()) {
      return _Fallback(
        icon: Icons.broken_image_outlined,
        title: 'File not found',
        subtitle: widget.filePath,
        onShare: null,
      );
    }
    if (_isImage) {
      return InteractiveViewer(
        minScale: 0.8,
        maxScale: 5,
        child: Center(
          child: Image.file(
            file,
            errorBuilder: (_, __, ___) => const _Fallback(
              icon: Icons.broken_image_outlined,
              title: 'Could not load image',
              subtitle: null,
              onShare: null,
            ),
          ),
        ),
      );
    }
    if (_isPdf && _pdfController != null) {
      return PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
        builders: PdfViewBuilders<DefaultBuilderOptions>(
          options: const DefaultBuilderOptions(),
          documentLoaderBuilder: (_) =>
              const Center(child: CircularProgressIndicator(color: _primary)),
          errorBuilder: (_, error) => _Fallback(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Could not open PDF',
            subtitle: '$error',
            onShare: _share,
          ),
        ),
      );
    }
    // Unsupported type — offer to open with another app.
    return _Fallback(
      icon: Icons.insert_drive_file_outlined,
      title: widget.displayName,
      subtitle: 'No in-app preview for this file type.',
      onShare: _share,
    );
  }
}

class _Fallback extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onShare;

  const _Fallback({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _purpleDeep, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _primary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
            if (onShare != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Open with…'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purpleDeep,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
