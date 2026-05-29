import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_widgets.dart';
import '../../../data/app_data.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/announcement_service.dart';
import '../../../data/services/notification_service.dart';

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
        if (dt != null) {
          _selectedDate = dt;
        }
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
      // Fallback or handle error
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

  Widget _buildInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('EVENT INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1.2)),
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
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
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
      ],
    );
  }

  Widget _buildSectionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TARGET AUDIENCE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        const Text('Select specific sections to invite', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        if (_allSections.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 40),
                Icon(Icons.layers_clear_rounded, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('No sections available.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                const Text('Please ensure sections are created in Admin.', style: TextStyle(color: Colors.grey, fontSize: 12)),
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
                border: Border.all(color: isSelected ? AppTheme.primary : Colors.grey.shade200, width: 2),
              ),
              child: CheckboxListTile(
                value: isSelected,
                onChanged: (val) {
                  setState(() {
                    if (val == true) _selectedSections.add(section);
                    else _selectedSections.remove(section);
                  });
                },
                title: Text(section, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppTheme.textPrimary)),
                activeColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
            );
          }),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
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

  Widget _buildNavigation() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
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
                child: const Text('BACK', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
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
                backgroundColor: AppTheme.accent,
                foregroundColor: AppTheme.primary,
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

  void _postEvent() async {
    if (_titleController.text.isEmpty) return;

    final day = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    // 1. Sync to Firebase for Real-time Student Sync
    try {
      await AnnouncementService.publishAnnouncement(
        title: _titleController.text,
        description: _descController.text,
        time: _selectedTime.format(context),
        location: _locationController.text,
        dateTime: _selectedDate,
        invitedSections: _selectedSections,
        targetType: 'Students',
        authorName: 'Teacher', // Ideally get from Auth
        authorRole: 'Teacher',
      );

      // Store the announcement for undo functionality
      AppData.lastAnnouncement = {
        'title': _titleController.text,
        'description': _descController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'dateTime': _selectedDate,
        'invitedSections': _selectedSections.toList(),
        'targetType': 'Students',
      };

      // 2. Local Update
      final eventData = {
        'title': _titleController.text,
        'time': _selectedTime.format(context),
        'location': _locationController.text,
        'description': _descController.text,
        'invitedSections': _selectedSections.toList(),
      };
      if (AppData.calendarEvents[day] == null) AppData.calendarEvents[day] = [];
      AppData.calendarEvents[day]!.add(eventData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Announcement Published & Synced!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                final dayEvents = AppData.calendarEvents[day];
                dayEvents?.remove(eventData);
                if (dayEvents != null && dayEvents.isEmpty) {
                  AppData.calendarEvents.remove(day);
                }
                NotificationService.showLocalNotification(
                  'Announcement Withdrawn',
                  'Your recent announcement has been removed locally.',
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
        Navigator.pop(context);
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
