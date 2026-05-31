import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../../data/app_data.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/announcement_service.dart';
import '../../../data/services/notification_service.dart';

// ─── Event Type Definition ───────────────────────────────────────────────────

enum EventType {
  schoolEvent,
  independentStudy,
  homeroom,
  classSession,
}

extension EventTypeExtension on EventType {
  String get label {
    switch (this) {
      case EventType.schoolEvent:
        return 'School Event';
      case EventType.independentStudy:
        return 'Independent Study Period';
      case EventType.homeroom:
        return 'Homeroom';
      case EventType.classSession:
        return 'Class Session';
    }
  }

  Color get color {
    switch (this) {
      case EventType.schoolEvent:
        return const Color(0xFFE53935); // Red
      case EventType.independentStudy:
        return const Color(0xFF1E88E5); // Blue
      case EventType.homeroom:
        return const Color(0xFF43A047); // Green
      case EventType.classSession:
        return const Color(0xFFFDD835); // Yellow
    }
  }

  Color get lightColor {
    switch (this) {
      case EventType.schoolEvent:
        return const Color(0xFFFFEBEE);
      case EventType.independentStudy:
        return const Color(0xFFE3F2FD);
      case EventType.homeroom:
        return const Color(0xFFE8F5E9);
      case EventType.classSession:
        return const Color(0xFFFFFDE7);
    }
  }

  Color get textColor {
    switch (this) {
      case EventType.classSession:
        return const Color(0xFF5D4E00); // Dark text for yellow bg
      default:
        return Colors.white;
    }
  }

  IconData get icon {
    switch (this) {
      case EventType.schoolEvent:
        return Icons.school_rounded;
      case EventType.independentStudy:
        return Icons.menu_book_rounded;
      case EventType.homeroom:
        return Icons.home_rounded;
      case EventType.classSession:
        return Icons.class_rounded;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  int _currentStep = 0;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  EventType _selectedEventType = EventType.schoolEvent;

  List<String> _allSections = [];
  final List<String> _selectedSections = [];

  @override
  void initState() {
    super.initState();
    _loadSections();
    _prefillFromLastAnnouncement();
  }

  void _prefillFromLastAnnouncement() {
    if (AppData.lastAnnouncement != null) {
      final announcement = AppData.lastAnnouncement!;
      _titleController.text = announcement['title'] ?? '';
      _descController.text = announcement['description'] ?? '';
      _locationController.text = announcement['location'] ?? '';

      if (announcement['dateTime'] != null) {
        final dt = announcement['dateTime'] is DateTime
            ? announcement['dateTime'] as DateTime
            : DateTime.tryParse(announcement['dateTime'].toString());
        if (dt != null) _selectedDate = dt;
      }

      if (announcement['time'] != null) {
        final timeStr = announcement['time'].toString();
        final timeParts = timeStr.split(':');
        if (timeParts.length >= 2) {
          try {
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            _selectedTime = TimeOfDay(hour: hour, minute: minute);
          } catch (e) {
            debugPrint('Error parsing time: $e');
          }
        }
      }

      if (announcement['invitedSections'] != null) {
        _selectedSections.clear();
        final sections = announcement['invitedSections'] as List;
        _selectedSections.addAll(sections.cast<String>());
      }

      if (announcement['eventType'] != null) {
        final typeStr = announcement['eventType'].toString();
        _selectedEventType = EventType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => EventType.schoolEvent,
        );
      }
    }
  }

  void _loadSections() async {
    try {
      final data = await ApiService.getSections();
      if (mounted) {
        setState(() {
          _allSections = data.map((s) => s['sectionName'].toString()).toList();
          if (_allSections.isNotEmpty) {
            _allSections.insert(0, 'ALL');
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading sections: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          CustomHeader(
            title: 'MAKE NEW EVENT',
            subtitle: 'Step ${_currentStep + 1} of 2',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _currentStep == 0 ? _buildInfoStep() : _buildSectionsStep(),
            ),
          ),
          _buildNavigation(),
        ],
      ),
    );
  }

  // ─── Step 1: Event Info ─────────────────────────────────────────────────────

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EVENT INFORMATION',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField('Event Title', _titleController, Icons.title_rounded),
        const SizedBox(height: 16),
        _buildTextField('Description', _descController, Icons.description_rounded, maxLines: 3),
        const SizedBox(height: 16),
        _buildTextField('Location', _locationController, Icons.location_on_rounded),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildPickerTile(
                'Date',
                '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                Icons.calendar_today_rounded,
                () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPickerTile(
                'Time',
                _selectedTime.format(context),
                Icons.access_time_rounded,
                () async {
                  final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                  if (picked != null) setState(() => _selectedTime = picked);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildEventTypeSelector(),
      ],
    );
  }

  // ─── Event Type Selector ────────────────────────────────────────────────────

  Widget _buildEventTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EVENT TYPE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose a category for your event',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        ...EventType.values.map((type) => _buildEventTypeTile(type)),
      ],
    );
  }

  Widget _buildEventTypeTile(EventType type) {
    final isSelected = _selectedEventType == type;

    return GestureDetector(
      onTap: () => setState(() => _selectedEventType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? type.lightColor : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? type.color : Colors.grey.shade200,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: type.color.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Color dot + icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected ? type.color : type.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                type.icon,
                color: isSelected ? type.textColor : type.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Label
            Expanded(
              child: Text(
                type.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? type.color : AppTheme.textPrimary,
                ),
              ),
            ),
            // Color swatch pill
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: type.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(color: type.color.withOpacity(0.4), blurRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? type.color : Colors.grey.shade300,
                  width: 2,
                ),
                color: isSelected ? type.color : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2: Sections ───────────────────────────────────────────────────────

  Widget _buildSectionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Event type badge at the top of step 2 as a reminder
        _buildEventTypeBadge(),
        const SizedBox(height: 20),
        const Text(
          'TARGET AUDIENCE',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select specific sections to invite',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
        ),
        if (_allSections.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.layers_clear_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No sections available.',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text('Please ensure sections are created in Admin.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          )
        else
          ..._allSections.map((section) {
            final isSelected = _selectedSections.contains(section);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? _selectedEventType.color : Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true)
                      _selectedSections.add(section);
                    else
                      _selectedSections.remove(section);
                  });
                },
                title: Text(
                  section,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: AppTheme.textPrimary,
                  ),
                ),
                activeColor: _selectedEventType.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            );
          }),
      ],
    );
  }

  /// Small summary badge shown at the top of step 2
  Widget _buildEventTypeBadge() {
    final type = _selectedEventType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: type.lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: type.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Icon(type.icon, size: 16, color: type.color),
          const SizedBox(width: 6),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: type.color,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ─────────────────────────────────────────────────────────

  Widget _buildTextField(String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPickerTile(String label, String value, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  Widget _buildNavigation() {
    // Use the selected event type color for the POST button
    final actionColor = _selectedEventType.color;
    final actionTextColor = _selectedEventType.textColor;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: AppTheme.primary),
                ),
                child: const Text('BACK',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_currentStep < 1) {
                  setState(() => _currentStep++);
                } else {
                  _postEvent();
                }
              },
              style: ElevatedButton.styleFrom(
                // On step 2, reflect the chosen event type color
                backgroundColor: _currentStep == 1 ? actionColor : AppTheme.accent,
                foregroundColor: _currentStep == 1 ? actionTextColor : AppTheme.primary,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _currentStep == 0 ? 'NEXT STEP' : 'POST EVENT',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Post Event ─────────────────────────────────────────────────────────────

  void _postEvent() async {
    if (_titleController.text.isEmpty) return;

    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    String? announcementId;
    try {
      announcementId = await AnnouncementService.publishAnnouncement(
        title: _titleController.text,
        description: _descController.text,
        time: _selectedTime.format(context),
        location: _locationController.text,
        dateTime: _selectedDate,
        invitedSections: _selectedSections,
        targetType: 'Students',
        authorName: 'Teacher',
        authorRole: 'Teacher',
        eventType: _selectedEventType.name,
        eventTypeLabel: _selectedEventType.label,
        eventColor: _selectedEventType.color.value,
      );

      AppData.lastAnnouncement = {
        'announcementId': announcementId,
        'title': _titleController.text,
        'description': _descController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'dateTime': _selectedDate,
        'invitedSections': _selectedSections.toList(),
        'targetType': 'Students',
        'eventType': _selectedEventType.name,
      };

      // Write locally so the calendar shows the correct color immediately.
      // Also store targetType and ownership so the calendar can filter
      // by audience and gate the delete button correctly.
      final user = await ApiService.getUserData();
      final createdById = user?['_id']?.toString() ?? user?['id']?.toString() ?? '';
      const createdByRole = 'TEACHER';

      final eventData = {
        'title': _titleController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'description': _descController.text,
        'invitedSections': _selectedSections.toList(),
        'eventType': _selectedEventType.name,
        'eventTypeLabel': _selectedEventType.label,
        'eventColor': _selectedEventType.color.value,
        // Visibility: teacher events default to students only
        'targetType': 'Only Students',
        'createdById': createdById,
        'createdByRole': createdByRole,
      };
      AppData.calendarEvents.putIfAbsent(day, () => []).add(eventData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _selectedEventType.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Announcement Published & Synced!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () async {
                final dayEvents = AppData.calendarEvents[day];
                dayEvents?.remove(eventData);
                if (dayEvents != null && dayEvents.isEmpty) {
                  AppData.calendarEvents.remove(day);
                }

                if (announcementId != null && announcementId.isNotEmpty) {
                  final deleted = await AnnouncementService.deleteAnnouncement(announcementId);
                  if (!deleted && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to remove announcement from server.'),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }

                AppData.lastAnnouncement = null;
                NotificationService.showLocalNotification(
                  'Announcement Withdrawn',
                  'Your recent announcement has been removed.',
                  type: 'announcement_undo',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement undone.'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        );
        Navigator.pop(context, true); // signals calendar to rebuild
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}