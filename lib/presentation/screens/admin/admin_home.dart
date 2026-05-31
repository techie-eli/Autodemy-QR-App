import 'package:flutter/material.dart';
import '../../../data/services/api_service.dart';
import '../../../data/app_data.dart';
import '../../../data/models/student_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../widgets/bottom_nav_shell.dart';
import '../auth/login_screen.dart';
import '../reports/report_module.dart';
import '../profile/profile_screen.dart';
import '../calendar/calendar_screen.dart';
import 'admin_stub_screens.dart';

enum _AdminLogTab { activity, audit }

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});
  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  void _showStatus(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavShell(
      header: const CustomHeader(
        title: 'ADMIN PANEL',
        subtitle: 'School Management System',
        userRole: 'ADMIN',
      ),
      labels: const ['Home', 'Reports', 'Concerns', 'Calendar', 'Profile'],
      icons: const [
        Icons.dashboard_rounded,
        Icons.assessment_rounded,
        Icons.support_agent_rounded,
        Icons.calendar_month_rounded,
        Icons.person_rounded,
      ],
      pages: [
        // ─── TAB 0: HOME ──────────────────────────────────────────────
        _buildHomePage(),
        // ─── TAB 1: REPORTS ───────────────────────────────────────────
        const ReportModuleScreen(embedded: true, userRole: 'ADMIN'),
        // ─── TAB 2: CONCERNS ──────────────────────────────────────────
        const AdminConcernsScreen(),
        // ─── TAB 3: CALENDAR ──────────────────────────────────────────
        const CalendarScreen(embedded: true, userRole: 'ADMIN'),
        // ─── TAB 4: PROFILE ───────────────────────────────────────────
        const ProfileScreen(
          userName: 'Administrator',
          userRole: 'Admin',
          embedded: true,
        ),
      ],
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
      children: [
        _buildSectionTitle('ACADEMIC MANAGEMENT'),
        ActionCard(
          icon: Icons.calendar_month_rounded,
          title: 'Academic Years',
          subtitle: 'Manage school years and terms',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AcademicYearsScreen())),
          iconColor: Colors.deepOrange,
        ),
        const SizedBox(height: 12),
        _buildSectionTitle('USER ACCOUNT MANAGEMENT'),
        ActionCard(
          icon: Icons.person_add_alt_1_rounded,
          title: 'Teacher Accounts',
          subtitle: 'Manage faculty credentials and roles',
          onTap: () => _manageAccounts("Teacher"),
        ),
        ActionCard(
          icon: Icons.group_add_rounded,
          title: 'Student Accounts',
          subtitle: 'Manage student profiles and enrollment',
          onTap: () => _manageAccounts("Student"),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('SYSTEM & CONFIGURATION'),
        ActionCard(
          icon: Icons.terminal_rounded,
          title: 'System Logs',
          subtitle: 'Monitor system changes and events',
          onTap: _viewSystemLogs,
          iconColor: Colors.blueGrey,
        ),
        ActionCard(
          icon: Icons.settings_rounded,
          title: 'Configuration',
          subtitle: 'Manage system-wide settings',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalConfigScreen())),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _manageAccounts(String type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AccountEntryScreen(userType: type)),
    );
  }

  Widget _buildDialogAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
    );
  }

  void _showAddAccountForm(String type) {
    // Use the modern reusable dialog from custom_widgets
    showAddAccountDialog(context, type, onSave: ApiService.addUser)
        .then((created) {
      if (created == true) {
        _showStatus('Account Created!');
      }
    });
  }

  void _viewSystemLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: const AdminLogsSheet(),
      ),
    );
  }
}

class AdminLogsSheet extends StatefulWidget {
  const AdminLogsSheet({super.key});

  @override
  State<AdminLogsSheet> createState() => _AdminLogsSheetState();
}

class _AdminLogsSheetState extends State<AdminLogsSheet> {
  _AdminLogTab _selectedTab = _AdminLogTab.activity;
  late Future<List<dynamic>> _activityLogsFuture;
  late Future<List<dynamic>> _auditLogsFuture;

  @override
  void initState() {
    super.initState();
    _activityLogsFuture = ApiService.getSystemLogs();
    _auditLogsFuture = ApiService.getAuditLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SYSTEM LOGS',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildTabButton('System Activity Logs', _AdminLogTab.activity),
              const SizedBox(width: 12),
              _buildTabButton('Audit Logs', _AdminLogTab.audit),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _selectedTab == _AdminLogTab.activity ? _buildActivityLogs() : _buildAuditLogs(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, _AdminLogTab tab) {
    final bool active = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: active ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? AppTheme.primary : Colors.grey.shade300),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityLogs() {
    return FutureBuilder<List<dynamic>>(
      future: _activityLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No activity logs found.'));
        }

        final logs = snapshot.data!;
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final bool isActive = log['isActive'] ?? false;
            final teacherName = (log['teacherName'] ?? log['teacherId']?['name'] ?? log['teacher'] ?? 'Unknown Teacher').toString();
            final sessionDate = log['startTime'] != null ? DateTime.parse(log['startTime']).toLocal() : null;
            final endDate = log['endTime'] != null ? DateTime.parse(log['endTime']).toLocal() : null;
            final dateText = sessionDate != null ? '${sessionDate.month}/${sessionDate.day}/${sessionDate.year}' : 'Date N/A';
            final endText = endDate != null ? ' • Ended ${endDate.hour.toString().padLeft(2, '0')}:${endDate.minute.toString().padLeft(2, '0')}' : '';

            return GestureDetector(
              onTap: () => _openAttendanceDetails(log),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.sensors_rounded : Icons.history_rounded,
                        color: isActive ? Colors.green : Colors.grey,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${log['subject'] ?? 'No subject'} • ${log['section'] ?? 'No section'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teacher: $teacherName • $dateText$endText',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isActive ? 'Currently Active Session' : 'Completed Session',
                            style: TextStyle(color: isActive ? Colors.green : AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${(log['records'] as List<dynamic>?)?.length ?? 0} attendance records',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditLogs() {
    return FutureBuilder<List<dynamic>>(
      future: _auditLogsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No audit logs found.'));
        }

        final logs = snapshot.data!;
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            final timestamp = log['createdAt'] != null ? DateTime.parse(log['createdAt']).toLocal() : null;
            final timeText = timestamp != null ? '${timestamp.month}/${timestamp.day}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}' : 'Time N/A';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          log['actionType'] ?? 'Audit Action',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Actor: ${log['actorName'] ?? 'Unknown'}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  Text('Target: ${log['targetType'] ?? 'System'}${log['targetId'] != null && log['targetId'].toString().isNotEmpty ? ' (${log['targetId']})' : ''}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  if ((log['details'] ?? '').toString().isNotEmpty)
                    Text(log['details'].toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(timeText, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAttendanceDetails(Map<String, dynamic> log) {
    final records = (log['records'] as List<dynamic>?) ?? [];
    final section = log['section']?.toString() ?? 'Unknown';
    final dateLabel = log['startTime'] != null ? DateTime.parse(log['startTime']).toLocal() : null;
    final formattedDate = dateLabel != null ? '${dateLabel.month}/${dateLabel.day}/${dateLabel.year}' : 'Session Details';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceDetailScreen(
          section: section,
          date: formattedDate,
          userRole: 'ADMIN',
          records: records,
        ),
      ),
    );
  }
}
