import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/clinical_checklist.dart';
import '../services/clinical_sync_service.dart';
import '../services/remote/clinical_cases_service.dart';
import '../viewmodel/home_viewmodel.dart';

class ClinicalCasesView extends StatefulWidget {
  const ClinicalCasesView({super.key});

  @override
  State<ClinicalCasesView> createState() => _ClinicalCasesViewState();
}

class _ClinicalCasesViewState extends State<ClinicalCasesView> {
  final _service = ClinicalCasesService.instance;
  final _sync = ClinicalSyncService.instance;
  late Future<_LoadedData> _future;
  // Live checked state — initialized from the loaded snapshot, updated
  // optimistically on each toggle so we can detect completion immediately.
  final Map<String, bool> _checked = {};
  bool _promoting = false;
  StreamSubscription<void>? _syncSub;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _syncSub = _sync.onSynced.listen((_) {
      if (mounted) _refresh();
    });
    // Opportunistic flush — covers the case where the user opens this view
    // right after coming online.
    _sync.syncPending();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
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
    final checked = await _service.fetchCheckedItems(level);
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
      await _service.setClinicLevel(next);
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
              service: _service,
            ));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => rows[i],
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
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFFf7e4b0)),
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
  final ClinicalCasesService service;
  final ValueChanged<bool>? onCheckedChanged;
  const _ChecklistTile({
    super.key,
    required this.level,
    required this.item,
    required this.initiallyChecked,
    required this.service,
    this.onCheckedChanged,
  });

  @override
  State<_ChecklistTile> createState() => _ChecklistTileState();
}

class _ChecklistTileState extends State<_ChecklistTile> {
  final _sync = ClinicalSyncService.instance;
  late bool _checked;
  bool _saving = false;
  bool _uploadsExpanded = false;
  Future<List<_FileEntry>>? _uploadsFuture;

  @override
  void initState() {
    super.initState();
    _checked = widget.initiallyChecked;
  }

  Future<List<_FileEntry>> _loadFiles() async {
    final pending = await _sync.listPendingUploads(
      level: widget.level,
      itemKey: widget.item.key,
    );
    List<ClinicalUpload> remote = const [];
    try {
      remote = await widget.service.listUploads(
        level: widget.level,
        itemKey: widget.item.key,
      );
    } catch (_) {
      // Offline or RLS — fall back to just the local queue.
    }
    return [
      ...pending.map(_FileEntry.pending),
      ...remote.map(_FileEntry.remote),
    ];
  }

  void _refreshFiles() {
    setState(() {
      _uploadsFuture = _loadFiles();
    });
  }

  Future<void> _toggle(bool? v) async {
    if (v == null || _saving) return;
    final prev = _checked;
    setState(() {
      _checked = v;
      _saving = true;
    });
    bool? pushed;
    try {
      pushed = await _sync.submitCheck(
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
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (pushed == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange.shade800,
          content: const Text(
            'Saved offline. Will sync when online.',
            style: TextStyle(color: Colors.white),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
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
    bool? pushed;
    try {
      pushed = await _sync.submitUpload(
        level: widget.level,
        itemKey: widget.item.key,
        sourceFile: File(path),
        displayName: picked.name,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: pushed == true
            ? const Color(0xFF5D4B8A)
            : Colors.orange.shade800,
        content: Text(
          pushed == true
              ? 'Uploaded'
              : 'Saved offline. Will upload when online.',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
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

  Future<void> _openUpload(ClinicalUpload u) async {
    try {
      final url = await widget.service.createSignedUrl(u.filePath);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(u.fileName),
          content: SelectableText(url),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $e')),
        );
      }
    }
  }

  Future<void> _deleteRemote(ClinicalUpload u) async {
    try {
      await widget.service.deleteUpload(u);
      _refreshFiles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _deletePending(PendingUpload u) async {
    try {
      await _sync.deletePendingUpload(u.id);
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
              Checkbox(
                value: _checked,
                onChanged: _saving ? null : _toggle,
                activeColor: const Color(0xFF8F6BFF),
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
                icon: Icon(
                  _uploadsExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: const Color(0xFF5D4B8A),
                ),
              ),
            ],
          ),
          if (_uploadsExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: FutureBuilder<List<_FileEntry>>(
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
                        if (e.pending != null)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.cloud_off,
                                color: Colors.orange),
                            title: Text(e.pending!.displayName,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              'Queued ${_formatTs(e.pending!.queuedAt)} • offline',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _deletePending(e.pending!),
                            ),
                          )
                        else
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.insert_drive_file,
                                color: Color(0xFF8F6BFF)),
                            title: Text(e.remote!.fileName,
                                style: const TextStyle(fontSize: 13)),
                            subtitle: Text(
                              _formatTs(e.remote!.uploadedAt),
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () => _openUpload(e.remote!),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _deleteRemote(e.remote!),
                            ),
                          ),
                    ],
                  );
                },
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

class _FileEntry {
  final ClinicalUpload? remote;
  final PendingUpload? pending;
  const _FileEntry._({this.remote, this.pending});
  factory _FileEntry.remote(ClinicalUpload u) => _FileEntry._(remote: u);
  factory _FileEntry.pending(PendingUpload u) => _FileEntry._(pending: u);
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
