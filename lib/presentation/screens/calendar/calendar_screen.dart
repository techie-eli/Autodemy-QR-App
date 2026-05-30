import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/app_data.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/announcement_service.dart';
import '../teacher/create_event_screen.dart';

class CalendarScreen extends StatefulWidget {
  final bool embedded;
  final String userRole; // 'ADMIN', 'TEACHER', 'STUDENT'
  
  const CalendarScreen({
    super.key, 
    this.embedded = false, 
    this.userRole = 'STUDENT'
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class CalendarEvent {
  final String title;
  final String time;
  final String location;
  final String description;
  final String eventTypeLabel;
  final Color eventColor;

  CalendarEvent({
    required this.title,
    this.time = 'Whole Day',
    this.location = 'Main Campus',
    this.description = 'No description provided.',
    this.eventTypeLabel = '',
    this.eventColor = AppTheme.primary,
  });
}

class _CalendarEventEntry {
  final CalendarEvent event;
  final bool isCloudAnnouncement;
  final int? localIndex;
  final String? announcementId;
  final dynamic sourceData;

  _CalendarEventEntry({
    required this.event,
    this.isCloudAnnouncement = false,
    this.localIndex,
    this.announcementId,
    this.sourceData,
  });
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Persistent Controllers to prevent text loss on rebuild
  final _titleCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '08:00 AM');
  final _locCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _publishDate = DateTime.now();
  EventType _selectedEventType = EventType.schoolEvent;
  String _targetType = 'Overall News';
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _timeCtrl.dispose();
    _locCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<_CalendarEventEntry> _getEventsForDay(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);

    final localRaw = AppData.calendarEvents[normalizedDay] ?? [];
    final localEntries = localRaw.asMap().entries.map((entry) {
      final raw = entry.value;
      int colorValue = AppTheme.primary.value;
      if (raw['eventColor'] != null) {
        final rawColor = raw['eventColor'];
        colorValue = rawColor is int ? rawColor : int.tryParse(rawColor.toString()) ?? colorValue;
      }
      return _CalendarEventEntry(
        event: CalendarEvent(
          title: raw['title'] ?? 'Untitled Event',
          time: raw['time'] ?? 'Whole Day',
          location: raw['location'] ?? 'Main Campus',
          description: raw['description'] ?? 'No description provided.',
          eventTypeLabel: raw['eventTypeLabel'] ?? '',
          eventColor: Color(colorValue),
        ),
        localIndex: entry.key,
        sourceData: raw,
      );
    }).toList();

    final cloudEntries = _cloudAnnouncements.where((a) {
      if (a['dateTime'] == null) return false;
      final dt = (a['dateTime'] is DateTime) ? a['dateTime'] : DateTime.tryParse(a['dateTime'].toString());
      if (dt == null) return false;
      return dt.year == day.year && dt.month == day.month && dt.day == day.day;
    }).map((a) {
      int eventColorValue = AppTheme.primary.value;
      if (a['eventColor'] != null) {
        eventColorValue = int.tryParse(a['eventColor'].toString()) ?? eventColorValue;
      }
      return _CalendarEventEntry(
        event: CalendarEvent(
          title: a['title'] ?? 'Announcement',
          time: a['time'] ?? 'All Day',
          location: a['location'] ?? 'Campus',
          description: a['description'] ?? '',
          eventTypeLabel: a['eventTypeLabel'] ?? '',
          eventColor: Color(eventColorValue),
        ),
        isCloudAnnouncement: true,
        announcementId: a['_id']?.toString(),
        sourceData: a,
      );
    }).toList();

    return [...localEntries, ...cloudEntries];
  }

  List<dynamic> _cloudAnnouncements = [];
  bool _isLoadingCloud = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _publishDate = _focusedDay;
    _targetType = widget.userRole == 'ADMIN' ? 'Overall News' : 'Specific Section';
    _fetchCloudEvents();
  }

  Future<void> _fetchCloudEvents() async {
    try {
      final user = await ApiService.getUserData();
      final section = user?['section'] ?? 'ALL';
      final events = await AnnouncementService.getAnnouncements(section);
      if (mounted) {
        setState(() {
          _cloudAnnouncements = events;
          _isLoadingCloud = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCloud = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canPublish = widget.userRole == 'ADMIN' || widget.userRole == 'TEACHER';

    if (!canPublish) {
      return Column(
        children: [
          _buildHeaderCap(),
          Expanded(child: _buildCalendarView()),
        ],
      );
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _buildHeaderCap(),
          Container(
            color: Colors.white,
            child: TabBar(
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
              tabs: const [
                Tab(text: 'VIEW CALENDAR', icon: Icon(Icons.calendar_month_rounded, size: 20)),
                Tab(text: 'PUBLISH EVENT', icon: Icon(Icons.post_add_rounded, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildCalendarView(),
                _buildPublishView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCap() {
    return Container(
      height: MediaQuery.of(context).padding.top + 32,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
    );
  }

  Widget _buildCalendarView() {
    return RefreshIndicator(
      onRefresh: _fetchCloudEvents,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_mosaic_rounded, color: AppTheme.primary, size: 20),
              SizedBox(width: 12),
              Text(
                'Academic Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: _calendarFormat,
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppTheme.primary),
                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
              ),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _publishDate = selectedDay; // Sync publish date for UX
                  });
                }
              },
              onFormatChanged: (format) {
                if (_calendarFormat != format) {
                  setState(() => _calendarFormat = format);
                }
              },
              onPageChanged: (focusedDay) => _focusedDay = focusedDay,
              eventLoader: _getEventsForDay,
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  final eventEntries = events.whereType<_CalendarEventEntry>().toList();
                  if (eventEntries.isEmpty) return const SizedBox.shrink();
                  final markers = eventEntries.take(3).map((entry) {
                    return Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        color: entry.event.eventColor,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: markers,
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.2), shape: BoxShape.circle),
                todayTextStyle: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                markerDecoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'EVENTS & ANNOUNCEMENTS',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.2),
          ),
          const SizedBox(height: 16),
          _buildEventList(),
        ],
      ),
    );
  }

  Widget _buildPublishView() {
    return Builder(
      builder: (innerContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish New Academic Event',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const Text(
              'Broadcast announcements or schedule new activities.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            
            _buildPublishField(controller: _titleCtrl, label: 'Event Title', icon: Icons.title_rounded),
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<EventType>(
                  value: _selectedEventType,
                  isExpanded: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  items: EventType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: type.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(type.label),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedEventType = value);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      AppData.preventLock = true;
                      try {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _publishDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: AppTheme.primary,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: AppTheme.textPrimary,
                                ),
                                dialogTheme: DialogThemeData(
                                  elevation: 24,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) setState(() => _publishDate = picked);
                      } finally {
                        Future.delayed(const Duration(seconds: 1), () {
                          AppData.preventLock = false;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "${_publishDate.month}/${_publishDate.day}/${_publishDate.year}",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildPublishField(controller: _timeCtrl, label: 'Time', icon: Icons.access_time_rounded)),
              ],
            ),
            const SizedBox(height: 20),
  
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _targetType,
                  isExpanded: true,
                  style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  items: (widget.userRole == 'ADMIN' 
                    ? ['Overall News', 'Only Teachers', 'Only Students'] 
                    : ['Specific Section', 'Whole Grade Level', 'All Handled Sections']
                  ).map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _targetType = v!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            _buildPublishField(controller: _locCtrl, label: 'Location', icon: Icons.location_on_rounded),
            const SizedBox(height: 20),
            
            _buildPublishField(controller: _descCtrl, label: 'Description', icon: Icons.description_rounded, maxLines: 4),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPublishing ? null : () => _handlePublish(innerContext),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                  shadowColor: AppTheme.accent.withOpacity(0.4),
                ),
                child: _isPublishing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rocket_launch_rounded),
                        SizedBox(width: 12),
                        Text('PUBLISH NOW', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
                      ],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePublish(BuildContext tabContext) async {
    if (_titleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    setState(() => _isPublishing = true);

    try {
      final userData = await ApiService.getUserData();
      final String authorName = userData?['name'] ?? 'Faculty';
      
      final day = DateTime(_publishDate.year, _publishDate.month, _publishDate.day);
      final List<String> invited = (_targetType == 'Specific Section' || _targetType.contains('Handled')) 
          ? [_locCtrl.text] 
          : ['ALL'];

      final String selectedLabel = _selectedEventType.label;
      final int selectedColorValue = _selectedEventType.color.value;

      // Store the announcement for undo functionality
      AppData.lastAnnouncement = {
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
        'time': _timeCtrl.text,
        'location': _locCtrl.text,
        'dateTime': day,
        'invitedSections': invited,
        'targetType': _targetType,
        'authorName': authorName,
        'authorRole': widget.userRole,
        'eventTypeLabel': selectedLabel,
        'eventColor': selectedColorValue,
        'eventType': _selectedEventType.name,
      };

      // 1. Sync to Cloud
      await AnnouncementService.publishAnnouncement(
        title: _titleCtrl.text,
        description: _descCtrl.text,
        time: _timeCtrl.text,
        location: _locCtrl.text,
        dateTime: day,
        invitedSections: invited,
        targetType: _targetType,
        authorName: authorName,
        authorRole: widget.userRole,
        eventType: _selectedEventType.name,
        eventTypeLabel: selectedLabel,
        eventColor: selectedColorValue,
      );

      // 2. Trigger a full refresh of cloud data immediately
      await _fetchCloudEvents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Event Published Successfully!'), 
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppTheme.accent,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        
        // Reset fields
        _titleCtrl.clear();
        _descCtrl.clear();
        _locCtrl.clear();
        
        // Navigate to calendar view and animate tab to 0 (VIEW CALENDAR)
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          DefaultTabController.of(tabContext)?.animateTo(0);
        }
      }
    } catch (e) {
      debugPrint('Cloud sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to publish event: $e'), 
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Widget _buildPublishField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  void _showEventDialog({
    CalendarEvent? eventToEdit,
    int? index,
    required DateTime day,
    bool isCloudAnnouncement = false,
    String? announcementId,
    dynamic sourceData,
  }) {
    final titleCtrl = TextEditingController(text: eventToEdit?.title ?? '');
    final locCtrl = TextEditingController(text: eventToEdit?.location ?? '');
    final timeCtrl = TextEditingController(text: eventToEdit?.time ?? '08:00 AM');
    final descCtrl = TextEditingController(text: eventToEdit?.description ?? '');
    EventType selectedType = EventType.schoolEvent;
    if (eventToEdit?.eventTypeLabel.isNotEmpty == true) {
      selectedType = EventType.values.firstWhere(
        (type) => type.label == eventToEdit!.eventTypeLabel,
        orElse: () => EventType.schoolEvent,
      );
    }
    bool isSaving = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(eventToEdit == null ? 'Create Event' : 'Edit Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locCtrl,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeCtrl,
                      decoration: const InputDecoration(labelText: 'Time'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<EventType>(
                          value: selectedType,
                          isExpanded: true,
                          items: EventType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(color: type.color, shape: BoxShape.circle),
                                  ),
                                  Text(type.label),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) setDialogState(() => selectedType = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Description'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCEL')),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (titleCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter a title for the event.')),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);
                          final normalizedDay = DateTime(day.year, day.month, day.day);
                          final eventData = {
                            'title': titleCtrl.text.trim(),
                            'time': timeCtrl.text.trim(),
                            'location': locCtrl.text.trim(),
                            'description': descCtrl.text.trim(),
                            'eventTypeLabel': selectedType.label,
                            'eventColor': selectedType.color.value,
                            'eventType': selectedType.name,
                          };

                          if (isCloudAnnouncement) {
                            if (announcementId != null) {
                              final updated = await AnnouncementService.updateAnnouncement(announcementId, eventData);
                              if (updated) {
                                await _fetchCloudEvents();
                                if (mounted) {
                                  setState(() {});
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Announcement updated successfully.')),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  setDialogState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Unable to update announcement.'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              }
                            }
                            return;
                          }

                          if (eventToEdit != null && index != null) {
                            final list = AppData.calendarEvents[normalizedDay];
                            if (list != null && index >= 0 && index < list.length) {
                              list[index] = eventData;
                            }
                          } else {
                            AppData.calendarEvents.putIfAbsent(normalizedDay, () => []).add(eventData);
                          }

                          if (mounted) {
                            setState(() {});
                            Navigator.pop(dialogContext);
                          }
                        },
                  child: Text(eventToEdit == null ? 'CREATE' : 'UPDATE'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      titleCtrl.dispose();
      locCtrl.dispose();
      timeCtrl.dispose();
      descCtrl.dispose();
    });
  }

  void _showAddEventDialog() {
    _showEventDialog(day: _selectedDay!);
  }

  Widget _buildEventList() {
    final day = DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final events = _getEventsForDay(day);

    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: const Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            const Text('No events scheduled for this day.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    
    return Column(
      children: List.generate(events.length, (index) {
        final event = events[index];
        return GestureDetector(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => EventDetailsScreen(
                  event: event.event,
                  canEdit: widget.userRole == 'ADMIN' || widget.userRole == 'TEACHER',
                  onEdit: () {
                    _showEventDialog(
                      eventToEdit: event.event,
                      index: event.localIndex,
                      day: day,
                      isCloudAnnouncement: event.isCloudAnnouncement,
                      announcementId: event.announcementId,
                      sourceData: event.sourceData,
                    );
                  },
                  onDelete: () async {
                    if (event.isCloudAnnouncement) {
                      final id = event.announcementId;
                      if (id == null) return false;
                      final deleted = await AnnouncementService.deleteAnnouncement(id);
                      if (deleted) {
                        await _fetchCloudEvents();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Announcement deleted successfully.')),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Unable to delete announcement.'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                      return deleted;
                    }

                    if (event.localIndex != null) {
                      setState(() {
                        AppData.calendarEvents[day]!.removeAt(event.localIndex!);
                      });
                      return true;
                    }
                    return false;
                  },
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: event.event.eventColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.event.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary, letterSpacing: -0.5),
                        ),
                        if (event.event.eventTypeLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: event.event.eventColor.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              event.event.eventTypeLabel,
                              style: TextStyle(color: event.event.eventColor, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: 14, color: AppTheme.primary.withOpacity(0.6)),
                            const SizedBox(width: 6),
                            Text(event.event.time, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            Icon(Icons.location_on_rounded, size: 14, color: AppTheme.primary.withOpacity(0.6)),
                            const SizedBox(width: 6),
                            Text(event.event.location, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class EventDetailsScreen extends StatelessWidget {
  final CalendarEvent event;
  final bool canEdit;
  final VoidCallback onEdit;
  final Future<bool> Function() onDelete;

  const EventDetailsScreen({
    super.key,
    required this.event,
    this.canEdit = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Event Details', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primary),
              onPressed: () {
                Navigator.pop(context);
                onEdit();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: () {
                _showDeleteDialog(context);
              },
            ),
          ]
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: AppTheme.accent, size: 32),
                  const SizedBox(height: 20),
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (event.eventTypeLabel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: event.eventColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        event.eventTypeLabel,
                        style: TextStyle(color: event.eventColor, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(event.time, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildDetailSection(Icons.location_on_rounded, 'LOCATION', event.location),
            const SizedBox(height: 32),
            _buildDetailSection(Icons.notes_rounded, 'DESCRIPTION', event.description),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(IconData icon, String label, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 16, height: 1.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: const Text('This action cannot be undone. Are you sure you want to remove this event?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              final deleted = await onDelete();
              if (deleted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
