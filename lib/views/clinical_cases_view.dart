import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:mime/mime.dart';

import '../data/clinical_checklist.dart';
import '../services/local/clinical_store.dart';
import '../services/local/profile_store.dart';
import '../viewmodel/home_viewmodel.dart';
import '../widgets/animations.dart';
import 'file_preview_view.dart';

class ClinicalCasesView extends StatefulWidget {
  const ClinicalCasesView({super.key});

  @override
  State<ClinicalCasesView> createState() => _ClinicalCasesViewState();
}

class _ClinicalCasesViewState extends State<ClinicalCasesView> {
  final _store = ClinicalStore.instance;
  late Future<_LoadedData> _future;
  // Live checked state — initialized from the loaded snapshot, updated
  // optimistically on each toggle so we can detect completion immediately.
  final Map<String, bool> _checked = {};
  bool _promoting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadedData> _load() async {
    final vm = context.read<HomeViewmodel>();
    if (vm.clinicLevel.isEmpty) {
      await vm.refresh();
    }
    final level = vm.clinicLevel;
    if (level.isEmpty) {
      _checked.clear();
      return _LoadedData(level: '', items: const [], checked: const {});
    }
    final items = ClinicalChecklist.itemsFor(level);
    final checked = await _store.fetchCheckedItems(level);
    _checked
      ..clear()
      ..addAll(checked);
    return _LoadedData(level: level, items: items, checked: checked);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  void _onItemCheckedChanged(_LoadedData data, ChecklistItem item, bool v) {
    _checked[item.key] = v;
    setState(() {});
    final allDone = data.items.isNotEmpty &&
        data.items.every((it) => _checked[it.key] ?? false);
    if (allDone && !_promoting) {
      _promote(data.level);
    }
  }

  Future<void> _promote(String currentLevel) async {
    final levels = ClinicalChecklist.levels;
    final idx = levels.indexOf(currentLevel);
    final atMax = idx < 0 || idx >= levels.length - 1;

    setState(() => _promoting = true);
    try {
      if (atMax) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF5D4B8A),
              content: Text(
                'All cases completed for the highest clinic level!',
                style: TextStyle(color: Colors.white),
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      final next = levels[idx + 1];
      await ProfileStore.instance.setClinicLevel(next);
      if (!mounted) return;
      await context.read<HomeViewmodel>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF5D4B8A),
          content: Text(
            'Promoted to $next!',
            style: const TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {
        _future = _load();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Promotion failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _promoting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        backgroundColor: const Color(0xFFF8F9FF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CLINICAL CASES',
          style: TextStyle(
            color: Color(0xFF5D4B8A),
            fontFamily: 'Derrick',
            fontSize: 22,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: FutureBuilder<_LoadedData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return _ErrorBox(
              message: 'Failed to load: ${snap.error}',
              onRetry: _refresh,
            );
          }
          final data = snap.data!;
          if (data.level.isEmpty) {
            return const _EmptyBox(
              message:
                  'No clinic level set on your profile. Please update your account.',
            );
          }
          if (data.items.isEmpty) {
            return _EmptyBox(
              message:
                  'No checklist items configured for ${data.level} yet.',
            );
          }

          final doneCount =
              data.items.where((it) => _checked[it.key] ?? false).length;
          // Flatten into a list mixing section headers and tiles.
          final rows = <Widget>[
            _Header(
              level: data.level,
              doneCount: doneCount,
              totalCount: data.items.length,
            ),
          ];
          String? lastSection;
          for (final item in data.items) {
            final section = item.section;
            if (section != null && section != lastSection) {
              rows.add(_SectionHeader(
                title: section,
                doneInSection:
                    _countDoneInSection(data.items, _checked, section),
                totalInSection:
                    data.items.where((i) => i.section == section).length,
              ));
              lastSection = section;
            }
            rows.add(_ChecklistTile(
              key: ValueKey('${data.level}_${item.key}'),
              level: data.level,
              item: item,
              initiallyChecked: _checked[item.key] ?? false,
              onCheckedChanged: (v) => _onItemCheckedChanged(data, item, v),
              store: _store,
            ));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => FadeSlideIn(
                delay: Duration(milliseconds: (i * 45).clamp(0, 400)),
                child: rows[i],
              ),
            ),
          );
        },
      ),
    );
  }
}

int _countDoneInSection(
  List<ChecklistItem> items,
  Map<String, bool> checked,
  String section,
) {
  var n = 0;
  for (final it in items) {
    if (it.section == section && (checked[it.key] ?? false)) n++;
  }
  return n;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int doneInSection;
  final int totalInSection;
  const _SectionHeader({
    required this.title,
    required this.doneInSection,
    required this.totalInSection,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF5D4B8A),
                fontFamily: 'Roboto',
                fontSize: 16,
              ),
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE6E1F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$doneInSection/$totalInSection',
              style: const TextStyle(
                color: Color(0xFF5D4B8A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedData {
  final String level;
  final List<ChecklistItem> items;
  final Map<String, bool> checked;
  _LoadedData({
    required this.level,
    required this.items,
    required this.checked,
  });
}

class _Header extends StatelessWidget {
  final String level;
  final int doneCount;
  final int totalCount;
  const _Header({
    required this.level,
    required this.doneCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalCount == 0 ? 0.0 : doneCount / totalCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB191FF), Color(0xFF8F6BFF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(level,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Roboto',
                fontSize: 22,
              )),
          const SizedBox(height: 4),
          Text(
            '$doneCount of $totalCount completed',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFf7e4b0)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatefulWidget {
  final String level;
  final ChecklistItem item;
  final bool initiallyChecked;
  final ClinicalStore store;
  final ValueChanged<bool>? onCheckedChanged;
  const _ChecklistTile({
    super.key,
    required this.level,
    required this.item,
    required this.initiallyChecked,
    required this.store,
    this.onCheckedChanged,
  });

  @override
  State<_ChecklistTile> createState() => _ChecklistTileState();
}

class _ChecklistTileState extends State<_ChecklistTile> {
  late bool _checked;
  bool _saving = false;
  bool _uploadsExpanded = false;
  Future<List<ClinicalFile>>? _uploadsFuture;

  @override
  void initState() {
    super.initState();
    _checked = widget.initiallyChecked;
  }

  Future<List<ClinicalFile>> _loadFiles() {
    return widget.store.listUploads(
      level: widget.level,
      itemKey: widget.item.key,
    );
  }

  void _refreshFiles() {
    setState(() {
      _uploadsFuture = _loadFiles();
    });
  }

  /// Persists the checked state and notifies the parent so progress updates.
  /// Driven by file attachments — never by a direct user tap on the checkbox.
  Future<void> _setChecked(bool v) async {
    if (_checked == v) return;
    final prev = _checked;
    setState(() => _checked = v);
    try {
      await widget.store.setChecked(
        level: widget.level,
        itemKey: widget.item.key,
        checked: v,
      );
      widget.onCheckedChanged?.call(v);
    } catch (e) {
      if (mounted) {
        setState(() => _checked = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final path = picked.path;
    if (path == null) return;

    if (mounted) setState(() => _saving = true);
    try {
      await widget.store.addUpload(
        level: widget.level,
        itemKey: widget.item.key,
        sourceFile: File(path),
        displayName: picked.name,
      );
      // Attaching the first file auto-checks the item and adds to progress.
      if (!_checked) {
        await _setChecked(true);
      }
      if (mounted) {
        await context.read<HomeViewmodel>().refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attach failed: $e')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF5D4B8A),
        content: const Text(
          'File attached',
          style: TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {
      _uploadsExpanded = true;
    });
    _refreshFiles();
  }

  void _toggleUploads() {
    setState(() {
      _uploadsExpanded = !_uploadsExpanded;
    });
    if (_uploadsExpanded) _refreshFiles();
  }

  Future<void> _openFile(ClinicalFile f) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FilePreviewView(
          filePath: f.filePath,
          displayName: f.displayName,
        ),
      ),
    );
  }

  Future<void> _deleteFile(ClinicalFile f) async {
    try {
      await widget.store.deleteUpload(f);
      // Checked state follows attachments: unchecking when the last file goes.
      final remaining = await _loadFiles();
      if (remaining.isEmpty) {
        await _setChecked(false);
        // Keep the dashboard "Completed" stat in sync after unchecking.
        if (mounted) await context.read<HomeViewmodel>().refresh();
      }
      _refreshFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E1F5)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Read-only: the box reflects attachment state and cannot be
              // toggled by tapping — attach a file to complete the item.
              Tooltip(
                message: 'Attach a file to complete this item',
                child: IgnorePointer(
                  child: PopOnChange(
                    trigger: _checked,
                    child: Checkbox(
                      value: _checked,
                      onChanged: (_) {},
                      activeColor: const Color(0xFF8F6BFF),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.title,
                      style: const TextStyle(
                        color: Color(0xFF5D4B8A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.item.subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.item.subtitle!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Attach file',
                onPressed: _saving ? null : _pickAndUpload,
                icon: const Icon(Icons.attach_file,
                    color: Color(0xFF5D4B8A)),
              ),
              IconButton(
                tooltip: _uploadsExpanded ? 'Hide files' : 'Show files',
                onPressed: _toggleUploads,
                icon: AnimatedRotation(
                  turns: _uploadsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.expand_more,
                    color: Color(0xFF5D4B8A),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_uploadsExpanded
                ? const SizedBox(width: double.infinity)
                : Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: FutureBuilder<List<ClinicalFile>>(
                future: _uploadsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(12),
                      child: LinearProgressIndicator(),
                    );
                  }
                  if (snap.hasError) {
                    return Text('Failed: ${snap.error}',
                        style: const TextStyle(color: Colors.red));
                  }
                  final entries = snap.data ?? [];
                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No files attached yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final e in entries)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: _FileThumb(file: e),
                          title: Text(e.displayName,
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                            _formatTs(e.uploadedAt),
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () => _openFile(e),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () => _deleteFile(e),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTs(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

/// Small leading preview for an attached file: a thumbnail for images, or a
/// type-appropriate icon for everything else.
class _FileThumb extends StatelessWidget {
  final ClinicalFile file;
  const _FileThumb({required this.file});

  @override
  Widget build(BuildContext context) {
    final mime = lookupMimeType(file.filePath) ?? '';
    if (mime.startsWith('image/')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(file.filePath),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _ThumbIcon(Icons.broken_image),
        ),
      );
    }
    final icon = mime == 'application/pdf'
        ? Icons.picture_as_pdf
        : mime.startsWith('video/')
            ? Icons.videocam
            : Icons.insert_drive_file;
    return _ThumbIcon(icon);
  }
}

class _ThumbIcon extends StatelessWidget {
  final IconData icon;
  const _ThumbIcon(this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFE6E1F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: const Color(0xFF8F6BFF), size: 20),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String message;
  const _EmptyBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF5D4B8A), fontSize: 15),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
