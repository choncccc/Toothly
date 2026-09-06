import 'package:flutter/material.dart';

import '../services/local/record_store.dart';
import 'pdf_annotator_view.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _border = Color(0xFFE6E1F5);

/// Icon per department folder, mirroring the case cards in `create_case_view`.
const Map<String, IconData> _folderIcons = {
  'Pediatric': Icons.child_care_rounded,
  'Complete Dentures': Icons.face_rounded,
  'Endodontics': Icons.biotech_rounded,
  'Exodontia': Icons.medical_services_rounded,
  'Fixed Partial Denture': Icons.dashboard_rounded,
  'Removable Partial Denture': Icons.swap_horiz_rounded,
  'Restorative': Icons.build_circle_rounded,
  'Periodontics': Icons.spa_rounded,
  'Other': Icons.folder_rounded,
};

// =============================================================================
// Records home — folder grid with a search bar across every folder
// =============================================================================
class PatientRecordsView extends StatefulWidget {
  const PatientRecordsView({super.key});

  @override
  State<PatientRecordsView> createState() => _PatientRecordsViewState();
}

class _PatientRecordsViewState extends State<PatientRecordsView> {
  final _store = RecordStore.instance;

  String _query = '';
  Map<String, int> _counts = const {};
  List<PatientRecord> _results = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final counts = await _store.categoryCounts();
    final results = _query.trim().isEmpty
        ? const <PatientRecord>[]
        : await _store.search(_query);
    if (!mounted) return;
    setState(() {
      _counts = counts;
      _results = results;
      _loading = false;
    });
  }

  Future<void> _onQueryChanged(String value) async {
    _query = value;
    final results = value.trim().isEmpty
        ? const <PatientRecord>[]
        : await _store.search(value);
    if (!mounted) return;
    setState(() => _results = results);
  }

  Future<void> _openFolder(String category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FolderView(category: category),
      ),
    );
    _refresh();
  }

  Future<void> _openRecord(PatientRecord record) async {
    await openRecord(context, record);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final totalRecords =
        _counts.values.fold<int>(0, (sum, count) => sum + count);

    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: _purpleDeep,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              const Text(
                'Patient Records',
                style: TextStyle(
                  fontFamily: 'Derrick',
                  fontSize: 26,
                  color: _primary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalRecords == 1
                    ? '1 saved record'
                    : '$totalRecords saved records',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _SearchField(onChanged: _onQueryChanged),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: _purpleDeep),
                  ),
                )
              else if (searching)
                ..._buildSearchResults()
              else
                ..._buildFolders(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSearchResults() {
    if (_results.isEmpty) {
      return [
        _EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matching patient',
          message: 'Nothing found for "${_query.trim()}". '
              'Try part of the name or the patient code.',
        ),
      ];
    }
    return [
      Text(
        _results.length == 1
            ? '1 result'
            : '${_results.length} results',
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      const SizedBox(height: 8),
      for (final r in _results) ...[
        _RecordTile(
          record: r,
          showCategory: true,
          onTap: () => _openRecord(r),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _buildFolders() {
    return [
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          for (final category in RecordStore.categories)
            _FolderCard(
              label: category,
              icon: _folderIcons[category] ?? Icons.folder_rounded,
              count: _counts[category] ?? 0,
              onTap: () => _openFolder(category),
            ),
          // Only surfaced when legacy imports could not be matched to a folder.
          if ((_counts['Other'] ?? 0) > 0)
            _FolderCard(
              label: 'Other',
              icon: Icons.folder_rounded,
              count: _counts['Other'] ?? 0,
              onTap: () => _openFolder('Other'),
            ),
        ],
      ),
    ];
  }
}

/// Opens [record] in the annotator with its saved annotations restored.
Future<void> openRecord(BuildContext context, PatientRecord record) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PdfAnnotatorView(
        title: record.formTitle,
        editablePdfPath: record.templatePath,
        companionPdfPaths: record.companionPaths,
        category: record.category,
        record: record,
      ),
    ),
  );
}

// =============================================================================
// One folder's contents
// =============================================================================
class _FolderView extends StatefulWidget {
  final String category;
  const _FolderView({required this.category});

  @override
  State<_FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<_FolderView> {
  late Future<List<PatientRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = RecordStore.instance.listByCategory(widget.category);
  }

  void _reload() {
    setState(() {
      _future = RecordStore.instance.listByCategory(widget.category);
    });
  }

  Future<void> _open(PatientRecord record) async {
    await openRecord(context, record);
    _reload();
  }

  Future<void> _confirmDelete(PatientRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text('Delete record?'),
        content: Text(
          'This permanently removes ${record.displayLabel} '
          '(${record.formTitle}). This cannot be undone.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RecordStore.instance.delete(record.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Text(
          widget.category.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Derrick',
            fontSize: 18,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: FutureBuilder<List<PatientRecord>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _purpleDeep),
            );
          }
          final records = snap.data ?? const <PatientRecord>[];
          if (records.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                SizedBox(height: 40),
                _EmptyState(
                  icon: Icons.folder_off_rounded,
                  title: 'No records yet',
                  message: 'Charts you save in this department will appear '
                      'here, grouped by patient.',
                ),
              ],
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _RecordTile(
              record: records[i],
              onTap: () => _open(records[i]),
              onDelete: () => _confirmDelete(records[i]),
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Pieces
// =============================================================================
class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      cursorColor: _primary,
      style: const TextStyle(color: _primary),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by patient name or code…',
        hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _purpleDeep, width: 1.5),
        ),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _FolderCard({
    required this.label,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_purpleLight, _purpleDeep],
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const Spacer(),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                count == 1 ? '1 record' : '$count records',
                style: TextStyle(
                  color: count == 0 ? Colors.grey.shade400 : _purpleDeep,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  final PatientRecord record;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool showCategory;

  const _RecordTile({
    required this.record,
    required this.onTap,
    this.onDelete,
    this.showCategory = false,
  });

  String get _updatedLabel {
    final d = record.updatedAt;
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      return 'Today $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
    }
    return '${d.month}/${d.day}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _purpleLight.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: _purpleDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      showCategory
                          ? '${record.category} · ${record.formTitle}'
                          : record.formTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Updated $_updatedLabel',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: onDelete,
                  tooltip: 'Delete record',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 30),
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
