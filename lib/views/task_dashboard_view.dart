import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/clinical_checklist.dart';
import '../viewmodel/home_viewmodel.dart';
import '../viewmodel/appointments_viewmodel.dart';
import '../services/local/draft_store.dart';
import '../widgets/animations.dart';
import 'pdf_annotator_view.dart';
import 'profile_view.dart';

// Palette ---------------------------------------------------------------------
const _bgColor = Color(0xFFF8F9FF);
const _primary = Color(0xFF5D4B8A);
const _purpleLight = Color(0xFFB191FF);
const _purpleDeep = Color(0xFF8F6BFF);
const _gold = Color(0xFFf7e4b0);
const _border = Color(0xFFE6E1F5);

class TaskDashboardPage extends StatefulWidget {
  const TaskDashboardPage({super.key});

  @override
  State<TaskDashboardPage> createState() => _TaskDashboardPageState();
}

class _TaskDashboardPageState extends State<TaskDashboardPage> {
  final GlobalKey<_DraftsSectionState> _draftsKey = GlobalKey();

  String _greetingPhrase() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatApptDate(DateTime date, String? time) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final d = '${months[date.month - 1]} ${date.day}';
    return (time == null || time.isEmpty) ? d : '$d • $time';
  }

  Future<void> _handleRefresh(BuildContext context) async {
    await Future.wait([
      context.read<HomeViewmodel>().refresh(),
      context.read<AppointmentsViewModel>().loadUpcoming(),
    ]);
    _draftsKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<HomeViewmodel>();
    final apptVM = context.watch<AppointmentsViewModel>();
    final displayName = controller.displayName;
    final clinicLevel = controller.clinicLevel;
    final levelItems = clinicLevel.isEmpty
        ? const <ChecklistItem>[]
        : ClinicalChecklist.itemsFor(clinicLevel);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        title: const Text(
          'TOOTHLY',
          style: TextStyle(
            color: _primary,
            fontFamily: 'Derrick',
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 1.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.account_circle_rounded, color: _primary),
              onPressed: () {
                final home = context.read<HomeViewmodel>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider<HomeViewmodel>.value(
                      value: home,
                      child: const ProfileView(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () => _handleRefresh(context),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            FadeSlideIn(
              child: _GreetingHero(
                greeting: _greetingPhrase(),
                displayName: displayName.isEmpty ? 'there' : displayName,
                initials: controller.userCode.isEmpty ? 'U' : controller.userCode,
                clinicLevel: clinicLevel,
                avatarPath: controller.avatarPath,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: _StatsRow(
                casesCompleted: controller.casesCompleted,
                upcomingAppointments: apptVM.upcomingCount,
                clinicLevel: clinicLevel,
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 160),
              child: _ClinicalCasesPanel(
                clinicLevel: clinicLevel,
                totalItems: levelItems.length,
                onTap: () => context.read<HomeViewmodel>().onItemTapped(2),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 240),
              child: _PrimaryActionButton(
                label: 'Add a New Case',
                icon: Icons.add_rounded,
                onPressed: () => context.read<HomeViewmodel>().onItemTapped(1),
              ),
            ),
            const SizedBox(height: 28),
            _DraftsSection(key: _draftsKey),
            const _SectionHeader(title: 'Upcoming Appointments'),
            const SizedBox(height: 10),
            _AppointmentsSection(vm: apptVM, formatDate: _formatApptDate),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Greeting hero
// =============================================================================
class _GreetingHero extends StatelessWidget {
  final String greeting;
  final String displayName;
  final String initials;
  final String clinicLevel;
  final String? avatarPath;

  const _GreetingHero({
    required this.greeting,
    required this.displayName,
    required this.initials,
    required this.clinicLevel,
    required this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_purpleLight, _purpleDeep],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: _purpleDeep.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 2),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            child: (avatarPath == null || !File(avatarPath!).existsSync())
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Roboto',
                      fontSize: 22,
                    ),
                  )
                : Image.file(
                    File(avatarPath!),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(
                      initials,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        fontSize: 22,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontFamily: 'Roboto',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                if (clinicLevel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _clinicianLabel(clinicLevel),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Stats row
// =============================================================================
class _StatsRow extends StatelessWidget {
  final int casesCompleted;
  final int upcomingAppointments;
  final String clinicLevel;

  const _StatsRow({
    required this.casesCompleted,
    required this.upcomingAppointments,
    required this.clinicLevel,
  });

  @override
  Widget build(BuildContext context) {
    final clinician = _clinicianLabel(clinicLevel);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.task_alt_rounded,
            label: 'Completed',
            value: casesCompleted.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.event_rounded,
            label: 'Upcoming',
            value: upcomingAppointments.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.workspace_premium_rounded,
            label: 'Status',
            value: clinician,
          ),
        ),
      ],
    );
  }
}

String _clinicianLabel(String level) {
  if (level.isEmpty) return '—';
  return level.replaceFirst('Level ', 'Clinic ');
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _primary, size: 18),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Text(
                value,
                key: ValueKey(value),
                maxLines: 1,
                style: const TextStyle(
                  color: _primary,
                  fontSize: 22,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontFamily: 'Roboto',
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Clinical cases panel
// =============================================================================
class _ClinicalCasesPanel extends StatelessWidget {
  final String clinicLevel;
  final int totalItems;
  final VoidCallback onTap;

  const _ClinicalCasesPanel({
    required this.clinicLevel,
    required this.totalItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final levelLabel = clinicLevel.isEmpty ? 'Not set' : clinicLevel;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_purpleLight, _purpleDeep],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinical Cases',
                      style: TextStyle(
                        color: _primary,
                        fontFamily: 'Roboto',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clinicLevel.isEmpty
                          ? 'Set your clinic level in your profile'
                          : '$levelLabel · $totalItems requirements',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _primary),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Primary action
// =============================================================================
class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purpleDeep.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Roboto',
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _purpleDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _gold, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Section header
// =============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _primary,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.6,
          ),
        ),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: _gold,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Appointments section
// =============================================================================
class _AppointmentsSection extends StatelessWidget {
  final AppointmentsViewModel vm;
  final String Function(DateTime, String?) formatDate;

  const _AppointmentsSection({required this.vm, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }
    if (vm.appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_busy_rounded,
                color: _primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No upcoming appointments',
              style: TextStyle(
                color: _primary,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'When you book one, it’ll show up here.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontFamily: 'Roboto',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        for (final a in vm.appointments)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AppointmentTile(
              title: a.title,
              notes: a.notes ?? '',
              date: a.date,
              time: a.time,
              formatted: formatDate(a.date, a.time),
            ),
          ),
      ],
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final String title;
  final String notes;
  final DateTime date;
  final String? time;
  final String formatted;

  const _AppointmentTile({
    required this.title,
    required this.notes,
    required this.date,
    required this.time,
    required this.formatted,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date block
          Container(
            width: 54,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_purpleLight, _purpleDeep],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  months[date.month - 1],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notes,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
                if (time != null && time!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: _primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time!,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _primary),
        ],
      ),
    );
  }
}

// =============================================================================
// Drafts section — in-progress PDF annotations the user saved for later.
// =============================================================================
class _DraftsSection extends StatefulWidget {
  const _DraftsSection({super.key});

  @override
  State<_DraftsSection> createState() => _DraftsSectionState();
}

class _DraftsSectionState extends State<_DraftsSection> {
  late Future<List<CaseDraft>> _future;

  @override
  void initState() {
    super.initState();
    _future = DraftStore.list();
  }

  void refresh() {
    if (!mounted) return;
    setState(() => _future = DraftStore.list());
  }

  Future<void> _openDraft(CaseDraft d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfAnnotatorView(
          title: d.title,
          editablePdfPath: d.editablePdfPath,
          companionPdfPaths: d.companionPdfPaths,
        ),
      ),
    );
    refresh();
  }

  Future<void> _confirmDelete(CaseDraft d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: Text('Delete the draft for "${d.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DraftStore.delete(d.filePath);
      refresh();
    }
  }

  String _formatSavedAt(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[t.month - 1]} ${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CaseDraft>>(
      future: _future,
      builder: (context, snap) {
        final drafts = snap.data ?? const <CaseDraft>[];
        if (drafts.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeader(title: 'Continue Drafts'),
            const SizedBox(height: 10),
            for (final d in drafts) ...[
              _DraftCard(
                draft: d,
                savedAtLabel: _formatSavedAt(d.savedAt),
                onTap: () => _openDraft(d),
                onDelete: () => _confirmDelete(d),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }
}

class _DraftCard extends StatelessWidget {
  final CaseDraft draft;
  final String savedAtLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.savedAtLabel,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bookmark_rounded,
                  color: _primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Saved $savedAtLabel',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Discard draft',
                onPressed: onDelete,
                icon: Icon(Icons.close_rounded, color: Colors.grey.shade500),
              ),
              const Icon(Icons.chevron_right_rounded, color: _primary),
            ],
          ),
        ),
      ),
    );
  }
}
