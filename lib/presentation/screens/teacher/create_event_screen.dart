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
  quiz,
  homeroom,
  classSession,
  examination,
  otherEvent,
}

extension EventTypeExtension on EventType {
  String get label {
    switch (this) {
      case EventType.schoolEvent:
        return 'School Event';
      case EventType.quiz:
        return 'Quiz';
      case EventType.homeroom:
        return 'Homeroom';
      case EventType.classSession:
        return 'Class Session';
      case EventType.examination:
        return 'Examination';
      case EventType.otherEvent:
        return 'Other Events';
    }
  }

  Color get color {
    switch (this) {
      case EventType.schoolEvent:
        return const Color(0xFFE53935); // Red
      case EventType.quiz:
        return const Color(0xFF1E88E5); // Blue
      case EventType.homeroom:
        return const Color(0xFF43A047); // Green
      case EventType.classSession:
        return const Color(0xFFFDD835); // Yellow
      case EventType.examination:
        return const Color(0xFFFB8C00); // Orange
      case EventType.otherEvent:
        return const Color(0xFF8E24AA); // Purple
    }
  }

  Color get lightColor {
    switch (this) {
      case EventType.schoolEvent:
        return const Color(0xFFFFEBEE);
      case EventType.quiz:
        return const Color(0xFFE3F2FD);
      case EventType.homeroom:
        return const Color(0xFFE8F5E9);
      case EventType.classSession:
        return const Color(0xFFFFFDE7);
      case EventType.examination:
        return const Color(0xFFFFF3E0);
      case EventType.otherEvent:
        return const Color(0xFFF3E5F5);
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
      case EventType.quiz:
        return Icons.quiz_rounded;
      case EventType.homeroom:
        return Icons.home_rounded;
      case EventType.classSession:
        return Icons.class_rounded;
      case EventType.examination:
        return Icons.pending_actions_rounded;
      case EventType.otherEvent:
        return Icons.tag_rounded;
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
        final timeStr = announcement['time'].toString().trim();
        final timeRegex = RegExp(r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\$');
        final match = timeRegex.firstMatch(timeStr);
        if (match != null) {
          try {
            var hour = int.parse(match.group(1)!);
            final minute = int.parse(match.group(2)!);
            final ampm = match.group(3)?.toUpperCase();
            if (ampm != null) {
              if (ampm == 'PM' && hour < 12) hour += 12;
              if (ampm == 'AM' && hour == 12) hour = 0;
            }
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

    try {
      final announcementId = await AnnouncementService.publishAnnouncement(
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

      // Store for prefill on next open — do NOT also write to AppData.calendarEvents.
      // The calendar fetches events from the cloud via AnnouncementService, so
      // writing locally here too is what caused every new event to appear twice.
      AppData.lastAnnouncement = {
        'title': _titleController.text,
        'description': _descController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'dateTime': _selectedDate,
        'invitedSections': _selectedSections.toList(),
        'targetType': 'Students',
        'eventType': _selectedEventType.name,
        'eventTypeLabel': _selectedEventType.label,
        'eventColor': _selectedEventType.color.value,
      };

      // Keep in a local variable only for the UNDO snackbar action below.
      final eventData = {
        'title': _titleController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'description': _descController.text,
        'invitedSections': _selectedSections.toList(),
        'eventType': _selectedEventType.name,
        'eventTypeLabel': _selectedEventType.label,
        'eventColor': _selectedEventType.color.value,
      };
      // NOTE: eventData is intentionally NOT added to AppData.calendarEvents here.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                    const Expanded(child: Text('Announcement Published & Synced!')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('DISMISS'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        if (announcementId != null) {
                          final result = await AnnouncementService.deleteAnnouncement(announcementId);
                          if (result) {
                            NotificationService.showLocalNotification(
                              'Announcement Withdrawn',
                              'Your recent announcement has been removed.',
                              type: 'announcement_undo',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Unable to undo announcement on server.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                        }
                        final dayEvents = AppData.calendarEvents[day];
                        dayEvents?.remove(eventData);
                        if (dayEvents != null && dayEvents.isEmpty) {
                          AppData.calendarEvents.remove(day);
                        }
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
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: const Text('UNDO'),
                    ),
                  ],
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        Future.delayed(const Duration(seconds: 7), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
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