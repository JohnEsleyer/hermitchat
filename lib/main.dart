import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audioplayers/audioplayers.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> playNotificationSound() async {
    try {
      await _audioPlayer.play(AssetSource('notification.mp3'));
    } catch (e) {
      debugPrint('Error playing notification sound: $e');
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );
  }

  await ApiService().init();
  runApp(const HermitChatApp());
}

class ChatBackgroundPreferences {
  static const _prefix = 'chat_background_';

  static Future<String> resolve(String agentId, String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$agentId') ?? fallback;
  }

  static Future<void> save(String agentId, String backgroundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefix$agentId', backgroundId);
  }

  static Future<List<Agent>> applyToAgents(List<Agent> agents) async {
    final prefs = await SharedPreferences.getInstance();
    return agents
        .map(
          (agent) => Agent(
            id: agent.id,
            name: agent.name,
            role: agent.role,
            status: agent.status,
            model: agent.model,
            profilePic: agent.profilePic,
            platform: agent.platform,
            containerId: agent.containerId,
            personality: agent.personality,
            provider: agent.provider,
            background:
                prefs.getString('$_prefix${agent.id}') ?? agent.background,
          ),
        )
        .toList();
  }
}

class CalendarEventModel {
  final int id;
  final int agentId;
  final String agent;
  final String date;
  final String time;
  final String prompt;
  final bool executed;

  CalendarEventModel({
    required this.id,
    required this.agentId,
    required this.agent,
    required this.date,
    required this.time,
    required this.prompt,
    required this.executed,
  });

  factory CalendarEventModel.fromJson(Map<String, dynamic> json) {
    return CalendarEventModel(
      id: json['id'] as int,
      agentId: json['agentId'] as int,
      agent: json['agent'] as String? ?? 'Unknown',
      date: json['date'] as String? ?? '',
      time: json['time'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      executed: json['executed'] as bool? ?? false,
    );
  }

  DateTime? get startsAt {
    if (date.isEmpty) return null;
    final normalizedTime = time.isEmpty ? '00:00' : time;
    return DateTime.tryParse('${date}T$normalizedTime:00');
  }
}

const List<String> _calendarWeekdays = [
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

const List<String> _calendarMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final DateTime _today = DateTime.now();
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;
  List<CalendarEventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(_today.year, _today.month, _today.day);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final data = await ApiService().getCalendarEvents();
    if (!mounted) return;
    setState(() {
      _events = data.map((e) => CalendarEventModel.fromJson(e)).toList()
        ..sort((a, b) {
          final timeA = a.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final timeB = b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return timeA.compareTo(timeB);
        });
      _isLoading = false;
    });
  }

  Future<void> _deleteEvent(int id) async {
    final success = await ApiService().deleteCalendarEvent(id);
    if (success) {
      await _loadEvents();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<CalendarEventModel> _eventsForDay(DateTime day) {
    return _events.where((event) {
      final startsAt = event.startsAt;
      return startsAt != null && _isSameDay(startsAt, day);
    }).toList();
  }

  String _formatEventTime(String value) {
    if (value.isEmpty) return 'All day';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    final normalizedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$normalizedHour:$minute $suffix';
  }

  Color _getEventColor(int index) {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFFF97316),
    ];
    return colors[index % colors.length];
  }

  Widget _buildCompactCalendar() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final leadingEmpty = firstDay.weekday % 7;
    final totalSlots = ((leadingEmpty + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month - 1,
                  );
                }),
                child: const Icon(
                  LucideIcons.chevronLeft,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Text(
                '${_calendarMonths[_currentMonth.month - 1]} ${_currentMonth.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _currentMonth = DateTime(
                    _currentMonth.year,
                    _currentMonth.month + 1,
                  );
                }),
                child: const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _calendarWeekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: totalSlots,
            itemBuilder: (context, index) {
              final dayNum = index - leadingEmpty + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final day = DateTime(
                _currentMonth.year,
                _currentMonth.month,
                dayNum,
              );
              final dayEvents = _eventsForDay(day);
              final isToday = _isSameDay(day, _today);
              final isSelected =
                  _selectedDate != null && _isSameDay(day, _selectedDate!);
              final hasEvents = dayEvents.isNotEmpty;

              return GestureDetector(
                onTap: () => setState(() => _selectedDate = day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.3)
                        : isToday
                        ? const Color(0xFF1F2937)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isToday
                        ? Border.all(color: const Color(0xFF3B82F6), width: 1.5)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$dayNum',
                        style: TextStyle(
                          color: isToday
                              ? const Color(0xFF3B82F6)
                              : Colors.white,
                          fontSize: 13,
                          fontWeight: isToday || isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (hasEvents)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: dayEvents
                              .take(3)
                              .toList()
                              .asMap()
                              .entries
                              .map((entry) {
                                return Container(
                                  margin: const EdgeInsets.only(
                                    top: 2,
                                    right: 2,
                                  ),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: _getEventColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                );
                              })
                              .toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEventModel event, int index) {
    final eventColor = _getEventColor(index);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: eventColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 70,
            decoration: BoxDecoration(
              color: eventColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: eventColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatEventTime(event.time),
                          style: TextStyle(
                            color: eventColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (event.executed)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.check,
                                size: 10,
                                color: Color(0xFF10B981),
                              ),
                              SizedBox(width: 2),
                              Text(
                                'Done',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _deleteEvent(event.id),
                        child: const Icon(
                          LucideIcons.x,
                          size: 16,
                          color: Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.prompt,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.user,
                        size: 10,
                        color: Color(0xFF71717A),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        event.agent,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'calendar',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCompactCalendar(),
            const SizedBox(height: 16),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F0F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        const Text(
                          'Events',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _selectedDate = null),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF3B82F6,
                                ).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${_selectedDate!.day}/${_selectedDate!.month}',
                                    style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    LucideIcons.x,
                                    size: 12,
                                    color: Color(0xFF3B82F6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildEventsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    final visibleEvents = _selectedDate == null
        ? _events
        : _eventsForDay(_selectedDate!);

    if (visibleEvents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No calendar events yet',
            style: TextStyle(color: Color(0xFF71717A)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: visibleEvents.length,
      itemBuilder: (context, index) {
        final event = visibleEvents[index];
        return _buildEventCard(event, index);
      },
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble> {
  late final Timer _timer;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _step = _step == 3 ? 1 : _step + 1;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF111113),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bot, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F0F0F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Text(
              '.${'.' * (_step - 1)}',
              style: const TextStyle(
                color: Color(0xFFE4E4E7),
                fontSize: 22,
                letterSpacing: 3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypewriterText extends StatefulWidget {
  final String fullText;
  final TextStyle style;
  final int charDelayMs;
  final bool shouldAnimate;
  final VoidCallback? onAnimationComplete;

  const _TypewriterText({
    required this.fullText,
    required this.style,
    this.charDelayMs = 10,
    this.shouldAnimate = true,
    this.onAnimationComplete,
  });

  @override
  State<_TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<_TypewriterText> {
  String _displayedText = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.shouldAnimate) {
      _startTyping();
    } else {
      _displayedText = widget.fullText;
    }
  }

  @override
  void didUpdateWidget(_TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fullText != widget.fullText) {
      _timer?.cancel();
      if (widget.shouldAnimate) {
        _displayedText = '';
        _startTyping();
      } else {
        _displayedText = widget.fullText;
      }
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(Duration(milliseconds: widget.charDelayMs), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_displayedText.length >= widget.fullText.length) {
        timer.cancel();
        widget.onAnimationComplete?.call();
      } else {
        setState(() {
          _displayedText = widget.fullText.substring(
            0,
            _displayedText.length + 1,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(_displayedText, style: widget.style);
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String token;
  final bool isDirectUrl;
  const _VideoPlayerWidget({
    required this.url,
    required this.token,
    this.isDirectUrl = false,
  });

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _hasError = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      if (widget.isDirectUrl) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize()
              .then((_) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              })
              .catchError((e) {
                if (mounted) {
                  setState(() {
                    _hasError = true;
                    _isLoading = false;
                  });
                }
              });
      } else {
        _controller =
            VideoPlayerController.networkUrl(
                Uri.parse(widget.url),
                httpHeaders: {'Authorization': 'Bearer ${widget.token}'},
              )
              ..initialize()
                  .then((_) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  })
                  .catchError((e) {
                    if (mounted) {
                      setState(() {
                        _hasError = true;
                        _isLoading = false;
                      });
                    }
                  });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.videoOff, color: Colors.grey, size: 32),
              SizedBox(height: 8),
              Text(
                'Video unavailable',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading || !_controller.value.isInitialized) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_controller),
            VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              colors: const VideoProgressColors(playedColor: Color(0xFF10B981)),
            ),
            Center(
              child: IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 50,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class HermitChatApp extends StatelessWidget {
  const HermitChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HermitChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFF10B981),
          surface: Color(0xFF09090B),
          error: Color(0xFFEF4444),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class Agent {
  final String id;
  final String name;
  final String role;
  final String status;
  final String model;
  final String? profilePic;
  final String platform;
  final String containerId;
  final String personality;
  final String provider;
  final String background;

  Agent({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.model,
    this.profilePic,
    required this.platform,
    required this.containerId,
    required this.personality,
    this.provider = 'openrouter',
    this.background = 'doodle',
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unknown',
      role: json['role']?.toString() ?? 'assistant',
      status: json['status']?.toString() ?? 'standby',
      model: json['model']?.toString() ?? 'unknown',
      profilePic: json['profilePic']?.toString(),
      platform: json['platform']?.toString() ?? 'hermitchat',
      containerId: json['container_id']?.toString() ?? '',
      personality: json['personality']?.toString() ?? '',
      provider: json['provider']?.toString() ?? 'openrouter',
      background: json['background']?.toString() ?? 'doodle',
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final List<String>? files;
  final String? id;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.files,
    this.id,
  });
}

final List<Agent> mockAgents = [
  Agent(
    id: '1',
    name: 'Ralph',
    role: 'code assistant',
    status: 'running',
    model: 'openai/gpt-4o',
    platform: 'hermitchat',
    containerId: '123',
    personality: 'helpful',
  ),
  Agent(
    id: '2',
    name: 'Ava',
    role: 'data analyst',
    status: 'standby',
    model: 'anthropic/claude-3.5',
    platform: 'hermitchat',
    containerId: '456',
    personality: 'analytical',
  ),
  Agent(
    id: '3',
    name: 'System',
    role: 'orchestrator',
    status: 'running',
    model: 'internal',
    platform: 'hermitchat',
    containerId: '789',
    personality: 'neutral',
  ),
];

class HermitMascot extends StatelessWidget {
  final double size;
  final Color color;
  final bool showGlow;

  const HermitMascot({
    super.key,
    this.size = 100.0,
    this.color = Colors.white,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MascotPainter(color: color, showGlow: showGlow),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  final Color color;
  final bool showGlow;

  _MascotPainter({required this.color, required this.showGlow});

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 100.0;
    canvas.scale(scaleX, scaleY);

    void drawMascot(Paint linePaint, Paint bodyPaint, Paint eyePaint) {
      canvas.drawLine(const Offset(25, 45), const Offset(5, 40), linePaint);
      canvas.drawLine(const Offset(23, 55), const Offset(5, 55), linePaint);
      canvas.drawLine(const Offset(28, 65), const Offset(10, 75), linePaint);

      canvas.drawLine(const Offset(75, 45), const Offset(95, 40), linePaint);
      canvas.drawLine(const Offset(77, 55), const Offset(95, 55), linePaint);
      canvas.drawLine(const Offset(72, 65), const Offset(90, 75), linePaint);

      canvas.drawCircle(const Offset(50, 50), 30, bodyPaint);

      canvas.drawCircle(const Offset(42, 45), 5, eyePaint);
      canvas.drawCircle(const Offset(60, 45), 5, eyePaint);
    }

    if (showGlow) {
      final glowLinePaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      final glowBodyPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

      final transparentEyePaint = Paint()..color = Colors.transparent;

      drawMascot(glowLinePaint, glowBodyPaint, transparentEyePaint);
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()..color = color;
    final eyePaint = Paint()..color = Colors.black;

    drawMascot(linePaint, bodyPaint, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.showGlow != showGlow;
  }
}

final List<ChatMessage> mockChatHistory = [
  ChatMessage(
    role: 'system',
    content: 'Container started. Agent online.',
    timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: true,
  ),
  ChatMessage(
    role: 'user',
    content: 'Can you write a simple Python script to fetch the weather?',
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 58)),
    isRead: true,
  ),
  ChatMessage(
    role: 'assistant',
    content: 'I\'ll write a weather fetch script for you.',
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 57)),
    isRead: true,
  ),
  ChatMessage(
    role: 'system',
    content: 'pip install requests\nDone.',
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 56)),
    isRead: true,
  ),
  ChatMessage(
    role: 'assistant',
    content:
        '```python\nimport requests\n\ndef get_weather(city):\n    api_key = "YOUR_API_KEY"\n    url = f"http://api.weatherapi.com/v1/current.json?key={api_key}&q={city}"\n    response = requests.get(url)\n    return response.json()\n```',
    timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 55)),
    isRead: true,
  ),
  ChatMessage(
    role: 'user',
    content: 'Nice! Can you add error handling?',
    timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
    isRead: true,
  ),
  ChatMessage(
    role: 'assistant',
    content: 'Sure thing! Adding try-except blocks for better error handling.',
    timestamp: DateTime.now().subtract(const Duration(minutes: 28)),
    isRead: false,
  ),
];

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  final _ipCtrl = TextEditingController(text: ApiService().baseUrl ?? '');
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  void _handleLogin() async {
    setState(() => _isLoading = true);
    final success = await ApiService().login(
      _ipCtrl.text.trim(),
      _userCtrl.text.trim(),
      _passCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainLayout()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Check server URL and credentials.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HermitMascot(size: 100, showGlow: true),
                const SizedBox(height: 32),
                const Text(
                  'hermitchat',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'agent orchestration client',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
                const SizedBox(height: 60),
                _buildTextField(
                  'Server IP / URL',
                  'e.g., http://192.168.1.5:3000',
                  false,
                  _ipCtrl,
                ),
                const SizedBox(height: 20),
                _buildTextField('Username', 'admin', false, _userCtrl),
                const SizedBox(height: 20),
                _buildTextField('Password', '••••••••', true, _passCtrl),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Connect to OS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    bool isPassword,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF52525B)),
            filled: true,
            fillColor: const Color(0xFF18181B),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF3F3F46)),
            ),
          ),
        ),
      ],
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  void _handleLogout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  late final List<Widget> _screens = [
    const AgentsMainScreen(),
    const DashboardScreen(),
    const AppsScreen(),
    const CalendarScreen(),
    SettingsScreen(onLogout: _handleLogout),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _screens[_currentIndex],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF27272A))),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.black,
          selectedItemColor: Colors.white,
          unselectedItemColor: const Color(0xFF52525B),
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageSquare),
              label: 'chat',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.activity),
              label: 'system',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.layoutGrid),
              label: 'apps',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.calendar),
              label: 'calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(LucideIcons.settings),
              label: 'settings',
            ),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateAgentScreen()),
              ).then((_) => setState(() {})),
              backgroundColor: Colors.white,
              child: const Icon(LucideIcons.plus, color: Colors.black),
            )
          : null,
    );
  }
}

class AgentsMainScreen extends StatefulWidget {
  const AgentsMainScreen({super.key});

  @override
  State<AgentsMainScreen> createState() => _AgentsMainScreenState();
}

class _AgentsMainScreenState extends State<AgentsMainScreen> {
  List<Agent> _agents = [];
  List<Agent> _filteredAgents = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _unreadCounts = {};
  final Map<String, String> _lastMessages = {};
  StreamSubscription? _wsSubscription;

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _loadUnreadCounts();
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = ApiService().messageStream.listen((data) {
      if (!mounted) return;
      final agentId = data['agent_id']?.toString();
      if (agentId == null) return;

      setState(() {
        final currentUnread = _unreadCounts[agentId] ?? 0;
        _unreadCounts[agentId] = currentUnread + 1;

        final content = data['content']?.toString();
        if (content != null && content.isNotEmpty) {
          _lastMessages[agentId] = content;
        }
      });
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final agentIds = prefs.getStringList('agent_ids') ?? [];
      final Map<String, int> unread = {};
      final Map<String, String> lastMsg = {};

      for (final agentId in agentIds) {
        unread[agentId] = 0;
        lastMsg[agentId] = '';
      }

      if (mounted) {
        setState(() {
          _unreadCounts.clear();
          _unreadCounts.addAll(unread);
          _lastMessages.clear();
          _lastMessages.addAll(lastMsg);
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filteredAgents = _agents
          .where((a) => a.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredAgents = _agents;
      }
    });
  }

  Future<void> _loadAgents() async {
    final data = await ApiService().getAgents();
    if (mounted) {
      final agents = await ChatBackgroundPreferences.applyToAgents(
        data.map((json) => Agent.fromJson(json)).toList(),
      );

      final prefs = await SharedPreferences.getInstance();
      final agentIds = agents.map((a) => a.id).toList();
      await prefs.setStringList('agent_ids', agentIds);

      for (final agent in agents) {
        _fetchLastMessage(agent.id);
      }

      if (!mounted) return;
      setState(() {
        _agents = agents;
        _filteredAgents = _agents;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchLastMessage(String agentId) async {
    try {
      final lastMsg = await ApiService().getLastMessage(agentId);
      if (mounted && lastMsg != null) {
        setState(() {
          _lastMessages[agentId] = lastMsg;
        });
      }
    } catch (_) {}
  }

  String _truncateMessage(String message, int maxLength) {
    if (message.length <= maxLength) return message;
    return '${message.substring(0, maxLength)}...';
  }

  void _clearUnreadForAgent(String agentId) {
    setState(() {
      _unreadCounts[agentId] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isSearching ? _buildSearchBar() : _buildHeaderTitle(),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : _filteredAgents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSearching
                            ? LucideIcons.searchX
                            : LucideIcons.messageSquare,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching
                            ? 'no agents found for "${_searchController.text}"'
                            : 'no agents created yet',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _filteredAgents.length,
                  itemBuilder: (context, index) {
                    final agent = _filteredAgents[index];
                    final isRunning = agent.status == 'running';
                    final isTelegram = agent.platform == 'telegram';
                    final unreadCount = _unreadCounts[agent.id] ?? 0;
                    final lastMsgContent = _lastMessages[agent.id];
                    final displayMessage = isTelegram
                        ? 'Limited: Telegram Mode'
                        : (lastMsgContent != null && lastMsgContent.isNotEmpty
                              ? _truncateMessage(lastMsgContent, 50)
                              : 'Active connection to OS');

                    return GestureDetector(
                      onTap: isTelegram
                          ? null
                          : () {
                              _clearUnreadForAgent(agent.id);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(agent: agent),
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Color(0xFF1A1A1A),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Opacity(
                          opacity: isTelegram ? 0.6 : 1.0,
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF09090B),
                                      borderRadius: BorderRadius.circular(26),
                                      border: Border.all(
                                        color: const Color(0xFF27272A),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child:
                                        agent.profilePic != null &&
                                            agent.profilePic!.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            child: Image.network(
                                              '${ApiService().baseUrl}${agent.profilePic}',
                                              fit: BoxFit.cover,
                                              width: 52,
                                              height: 52,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Text(agent.name[0]),
                                            ),
                                          )
                                        : Text(
                                            agent.name[0],
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                  if (isRunning)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: isTelegram
                                              ? Colors.blueAccent
                                              : const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.black,
                                            width: 1.5,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Center(
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : unreadCount.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          agent.name +
                                              (isTelegram ? " (Bot)" : ""),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Text(
                                          'just now',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF71717A),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayMessage,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isTelegram
                                                  ? Colors.blueGrey
                                                  : const Color(0xFF71717A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  LucideIcons.settings,
                                  size: 20,
                                  color: Color(0xFF71717A),
                                ),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CreateAgentScreen(existingAgent: agent),
                                  ),
                                ).then((_) => _loadAgents()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderTitle() {
    return Row(
      key: const ValueKey('header_title'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'chats',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 4),
            Row(
              children: [
                HermitMascot(size: 16, showGlow: false),
                SizedBox(width: 6),
                Text(
                  'connected',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: _toggleSearch,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: const Icon(LucideIcons.search, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search_bar'),
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.search, size: 20, color: Color(0xFF71717A)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              cursorColor: Colors.white,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'Search agents...',
                hintStyle: TextStyle(color: Color(0xFF71717A)),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF71717A)),
            onPressed: _toggleSearch,
          ),
        ],
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Agent agent;
  const ChatScreen({super.key, required this.agent});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _takeoverMode = false;
  bool _isSending = false;
  bool _showCommands = false;
  bool _showSystemResponses = true;

  // Track which message indices should animate (typewriter effect)
  // Only new messages received via WebSocket should animate, not loaded from history
  final Set<int> _animateMessages = {};

  // Offline message store — persisted locally and synced with server
  // Ref: docs/chat_persistence.md
  final List<ChatMessage> _messages = [];
  StreamSubscription? _wsSubscription;

  // Mutable background ID so it can be refreshed after the user saves config
  late String _backgroundId;

  static final RegExp _tagPattern = RegExp(
    r'<([a-zA-Z_][a-zA-Z0-9_]*)>.*?</\1>',
    multiLine: true,
  );

  // Available slash commands with descriptions shown in the palette
  // Ref: docs/commands.md
  static const List<Map<String, String>> _commands = [
    {
      'command': '/status',
      'description': 'Show server reachability & LLM config — no AI needed',
    },
    {'command': '/reset', 'description': 'Restart the agent Docker container'},
    {
      'command': '/clear',
      'description': 'Clear full conversation & context window',
    },
  ];

  /// Returns the subset of commands that match the current input (search filter).
  List<Map<String, String>> get _filteredCommands {
    final query = _controller.text.toLowerCase();
    if (query == '/') return _commands;
    return _commands
        .where((c) => c['command']!.toLowerCase().startsWith(query))
        .toList();
  }

  List<ChatMessage> get _visibleMessages {
    if (_showSystemResponses) return _messages;
    return _messages.where((message) => message.role != 'system').toList();
  }

  bool _containsTags(String text) {
    return _tagPattern.hasMatch(text);
  }

  /// Rejects tags and displays system message when user tries to use tags in non-takeover mode.
  /// Tags like <terminal>, <action> etc. are only allowed in takeover mode.
  /// Ref: docs/xml-tags.md
  void _rejectTagsWithEnd(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'system',
          content:
              'System: Tag rejected. Tags are not allowed in current mode.',
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
      _messages.add(
        ChatMessage(
          role: 'system',
          content: '<end>',
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _persistMessages();
    _scrollToBottom();
  }

  /// Handles slash commands through the server so command execution is
  /// persisted in shared history and mirrored through websocket updates.
  /// Ref: docs/slash-commands.md
  void _sendCommand(String command) async {
    final commandName = command.split(' ')[0];

    setState(() {
      _showCommands = false;
      _messages.add(
        ChatMessage(
          role: 'user',
          content: command,
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _persistMessages();
    _scrollToBottom();

    // /status command: works offline with local info
    if (commandName == '/status') {
      await _handleStatusCommand();
      return;
    }

    // /clear command: clears conversation locally, sends to server if online
    if (commandName == '/clear') {
      await _handleClearCommand();
      return;
    }

    // Other slash commands: expect a response from server
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'system',
          content: 'Processing $commandName...',
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _persistMessages();
    _scrollToBottom();

    final response = await ApiService().sendMessage(
      widget.agent.id.toString(),
      command,
    );
    if (!mounted) return;

    setState(() {
      if (response != null) {
        final message =
            response['message'] as String? ??
            response['response'] as String? ??
            '';
        if (message.isNotEmpty) {
          _messages.add(
            ChatMessage(
              role: 'system',
              content: message,
              timestamp: DateTime.now(),
              isRead: true,
            ),
          );
        }
      } else {
        _messages.add(
          ChatMessage(
            role: 'system',
            content:
                'System: command was sent, but the server did not return a live update.',
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      }
    });
    _persistMessages();
    _scrollToBottom();
  }

  /// Handles /status command - works offline with local info
  Future<void> _handleStatusCommand() async {
    final api = ApiService();
    final isOnline = await api.checkServerConnection();
    final agent = widget.agent;

    String statusMessage = '🤖 *Agent Status: ${agent.name}*\n\n';

    // Server connection
    statusMessage += '📡 *Connection*\n';
    statusMessage += '• Server: ${isOnline ? 'Connected ✅' : 'Offline ❌'}\n';
    statusMessage += '• URL: ${api.baseUrl ?? 'Not configured'}\n';

    // API Key status
    statusMessage += '\n🔑 *API Configuration*\n';
    final hasApiKey = api.token != null && api.token!.isNotEmpty;
    statusMessage +=
        '• API Key: ${hasApiKey ? 'Configured ✅' : 'Not configured ❌'}\n';

    // LLM Settings from agent config
    statusMessage += '\n🤖 *LLM Configuration*\n';
    statusMessage +=
        '• Provider: ${agent.provider.isNotEmpty ? agent.provider : 'N/A'}\n';
    statusMessage +=
        '• Model: ${agent.model.isNotEmpty ? agent.model : 'N/A'}\n';
    statusMessage +=
        '• LLM Ready: ${hasApiKey && agent.model.isNotEmpty ? 'Yes ✅' : 'No ❌'}\n';

    // Container info
    statusMessage += '\n🐳 *Container*\n';
    statusMessage +=
        '• Container ID: ${agent.containerId.isNotEmpty ? agent.containerId : 'N/A'}\n';
    statusMessage +=
        '• Status: ${agent.containerId.isNotEmpty ? agent.status : 'N/A'}\n';

    // Try to get more info from server if online
    if (isOnline) {
      final settings = await api.getLocalSettings();
      if (settings != null) {
        // Server returns boolean values for key existence
        final hasOpenrouter =
            settings['openrouterKey'] == true ||
            settings['openrouterKey'] == 'true';
        final hasOpenai =
            settings['openaiKey'] == true || settings['openaiKey'] == 'true';
        final hasAnthropic =
            settings['anthropicKey'] == true ||
            settings['anthropicKey'] == 'true';
        final hasGemini =
            settings['geminiKey'] == true || settings['geminiKey'] == 'true';

        statusMessage += '\n🔐 *API Keys*\n';
        statusMessage +=
            '• OpenRouter: ${hasOpenrouter ? 'Configured ✅' : 'Not set'}\n';
        statusMessage +=
            '• OpenAI: ${hasOpenai ? 'Configured ✅' : 'Not set'}\n';
        statusMessage +=
            '• Anthropic: ${hasAnthropic ? 'Configured ✅' : 'Not set'}\n';
        statusMessage +=
            '• Gemini: ${hasGemini ? 'Configured ✅' : 'Not set'}\n';
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'system',
          content: statusMessage,
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _persistMessages();
    _scrollToBottom();
  }

  /// Handles /clear command - clears locally, syncs with server if online
  Future<void> _handleClearCommand() async {
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'system',
          content: 'Clearing conversation...',
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _persistMessages();
    _scrollToBottom();

    // Try to send to server, but clear locally regardless
    await ApiService().sendMessage(widget.agent.id.toString(), '/clear');

    if (!mounted) return;

    // Clear locally
    await Future.delayed(const Duration(milliseconds: 200));

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.add(
          ChatMessage(
            role: 'system',
            content: '✅ Conversation cleared. Context window reset.',
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      });
      _persistMessages();
    }
  }

  String _encodeStoredMessage(ChatMessage message) {
    return jsonEncode({
      'role': message.role,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'isRead': message.isRead,
      'files': message.files ?? <String>[],
    });
  }

  ChatMessage? _decodeStoredMessage(String raw) {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final filesDynamic = decoded['files'] as List<dynamic>? ?? [];
      final files = filesDynamic.map((file) => file.toString()).toList();
      return ChatMessage(
        role: decoded['role']?.toString() ?? 'system',
        content: decoded['content']?.toString() ?? '',
        timestamp:
            DateTime.tryParse(decoded['timestamp']?.toString() ?? '') ??
            DateTime.now(),
        isRead: decoded['isRead'] as bool? ?? true,
        files: files.isEmpty ? null : files,
      );
    } catch (_) {
      final parts = raw.split('|||');
      if (parts.length < 3) return null;
      return ChatMessage(
        role: parts[0],
        content: parts[1],
        timestamp: DateTime.tryParse(parts[2]) ?? DateTime.now(),
        isRead: true,
      );
    }
  }

  List<String> _extractFiles(dynamic rawFiles) {
    final filesDynamic = rawFiles as List<dynamic>? ?? [];
    return filesDynamic.map((file) => file.toString()).toList();
  }

  String _messageSignature(String role, String content, List<String> files) {
    final normalizedFiles = [...files]..sort();
    return '$role|||$content|||${normalizedFiles.join(',')}';
  }

  /// Builds an image widget with error handling.
  /// Supports both authenticated URLs and direct URLs from the server.
  Widget _buildImageWidget(String url, String fileName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        headers: {'Authorization': 'Bearer ${ApiService().token}'},
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.imageOff, color: Colors.grey, size: 32),
                  SizedBox(height: 8),
                  Text(
                    'Image unavailable',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds a file card widget with download button.
  /// Supports images, videos, and other file types.
  Widget _buildFileCard(
    String url,
    String fileName,
    String fileType,
    bool isSystem,
  ) {
    final bgColor = isSystem
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFE4E4E7);
    final textColor = isSystem ? Colors.white : Colors.black;
    final iconColor = isSystem
        ? const Color(0xFF10B981)
        : const Color(0xFF10B981);

    IconData icon;
    switch (fileType) {
      case 'image':
        icon = LucideIcons.image;
        break;
      case 'video':
        icon = LucideIcons.video;
        break;
      default:
        icon = LucideIcons.fileText;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSystem ? const Color(0xFF27272A) : const Color(0xFFD4D4D8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileType == 'image')
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: _buildImageWidget(url, fileName),
            )
          else if (fileType == 'video')
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              child: _VideoPlayerWidget(
                url: url,
                token: ApiService().token ?? '',
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(LucideIcons.download, size: 18, color: iconColor),
                  onPressed: () {
                    _downloadFile(url, fileName);
                  },
                  tooltip: 'Download',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Downloads a file from the given URL.
  void _downloadFile(String url, String fileName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $fileName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Copies the full context window including skills and conversation history.
  /// Ref: docs/context-window.md
  void _copyContextWindow() async {
    try {
      final contextData = await ApiService().getAgentContextWindow(
        widget.agent.id.toString(),
      );

      if (!mounted) return;

      if (contextData != null) {
        final buffer = StringBuffer();

        if (contextData['systemPrompt'] != null) {
          buffer.writeln('=== SYSTEM PROMPT ===');
          buffer.writeln(contextData['systemPrompt']);
          buffer.writeln();
        }

        if (contextData['skills'] != null) {
          buffer.writeln('=== SKILLS ===');
          final skills = contextData['skills'] as List<dynamic>;
          for (final skill in skills) {
            buffer.writeln('--- ${skill['title']} ---');
            buffer.writeln(skill['content']);
            buffer.writeln();
          }
        }

        if (contextData['history'] != null) {
          buffer.writeln('=== CONVERSATION HISTORY ===');
          final history = contextData['history'] as List<dynamic>;
          final reversedHistory = history.reversed.toList();
          for (final entry in reversedHistory) {
            final role = entry['role'] ?? 'unknown';
            final content = entry['content'] ?? '';
            final timestamp = entry['timestamp'] ?? '';
            // Format timestamp (e.g., "2026-03-22 15:30:00")
            String timestampStr = '';
            if (timestamp.isNotEmpty && timestamp != 'null') {
              try {
                final dt = DateTime.parse(timestamp.toString());
                timestampStr =
                    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              } catch (_) {
                timestampStr = timestamp.toString();
              }
            }
            buffer.writeln('[$timestampStr $role]: $content');
          }
          buffer.writeln();
        }

        await Clipboard.setData(ClipboardData(text: buffer.toString()));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Context window copied to clipboard'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch context window'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying context: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _showMetrics() async {
    final metrics = await ApiService().getAgentStats(
      widget.agent.id.toString(),
    );
    if (!mounted) return;

    String content = 'Agent Metrics\n\n';
    if (metrics != null) {
      content += 'Tokens: ${metrics['tokenEstimate'] ?? 'N/A'}\n';
      content += 'Words: ${metrics['wordCount'] ?? 'N/A'}\n';
      content += 'API Calls: ${metrics['llmApiCalls'] ?? 'N/A'}\n';
      content += 'Context Window: ${metrics['contextWindow'] ?? 'N/A'}';
    } else {
      content += 'Unable to load metrics';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Agent Metrics',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          content,
          style: const TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _backgroundId = widget.agent.background;
    _loadBackgroundPreference();
    _loadSystemVisibilityPreference();
    _loadMessages();

    // Mark messages as seen when conversation is opened
    ApiService().markMessagesSeen(widget.agent.id.toString());

    // Reference: HermitShell/docs/frontend-backend-communication.md.
    _wsSubscription = ApiService().messageStream.listen((data) {
      if (!mounted) return;
      if (data['agent_id'].toString() != widget.agent.id.toString()) {
        return;
      }

      final eventType = data['type']?.toString() ?? '';
      if (eventType == 'conversation_cleared') {
        setState(() {
          _messages
            ..clear()
            ..add(
              ChatMessage(
                role: 'system',
                content: '✅ Conversation cleared. Context window reset.',
                timestamp: DateTime.now(),
                isRead: true,
              ),
            );
        });
        _persistMessages();
        _scrollToBottom();
        return;
      }

      if (eventType == 'new_message') {
        final files = _extractFiles(data['files']);
        final content = data['content']?.toString() ?? '';
        final role = data['role']?.toString() ?? 'assistant';
        final signature = _messageSignature(role, content, files);

        final isAssistant = role == 'assistant';

        setState(() {
          if (!_messages.any(
            (message) =>
                _messageSignature(
                  message.role,
                  message.content,
                  message.files ?? const <String>[],
                ) ==
                signature,
          )) {
            final messageIndex = _messages.length;
            final shouldAnimate = isAssistant && content.isNotEmpty;
            if (shouldAnimate) {
              _animateMessages.add(messageIndex);
            }

            final newMessage = ChatMessage(
              role: role,
              content: content,
              timestamp: DateTime.now(),
              isRead: true,
              files: files.isEmpty ? null : files,
            );
            _messages.add(newMessage);
            _persistMessages();
            _scrollToBottom();
          }
        });

        if (isAssistant && content.isNotEmpty) {
          _showNotification(content);
        }
      }
    });
  }

  Future<void> _loadBackgroundPreference() async {
    final backgroundId = await ChatBackgroundPreferences.resolve(
      widget.agent.id,
      widget.agent.background,
    );
    if (!mounted) return;
    setState(() => _backgroundId = backgroundId);
  }

  Future<void> _loadSystemVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool('show_system_responses');
    if (!mounted || value == null) return;
    setState(() => _showSystemResponses = value);
  }

  Future<void> _setShowSystemResponses(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_system_responses', value);
    if (!mounted) return;
    setState(() => _showSystemResponses = value);
  }

  /// Loads persisted messages from SharedPreferences (offline copy).
  /// This ensures the conversation survives app restarts and network outages.
  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_messages_${widget.agent.id}';
      final raw = prefs.getStringList(key) ?? [];
      final loaded = raw
          .map(_decodeStoredMessage)
          .whereType<ChatMessage>()
          .toList();

      if (loaded.isNotEmpty && mounted) {
        setState(() => _messages.addAll(loaded));
        _scrollToBottom();
      }
    } catch (_) {
      // If loading fails, start with clean slate.
    }
  }

  Future<void> _persistMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'chat_messages_${widget.agent.id}';
      final toStore = _messages.length > 200
          ? _messages.sublist(_messages.length - 200)
          : _messages;
      final raw = toStore.map(_encodeStoredMessage).toList();
      await prefs.setStringList(key, raw);
    } catch (_) {
      // Silently ignore persistence errors.
    }
  }

  Future<void> _showNotification(String body) async {
    NotificationService().playNotificationSound();
    if (kIsWeb) return;
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'hermit_chat',
          'Agent Messages',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: 'Hermit Agent',
      body: body.length > 50 ? '${body.substring(0, 50)}...' : body,
      notificationDetails: platformChannelSpecifics,
    );
  }

  /// Sends a user message or dispatches a slash-command.
  /// Closes the command palette and persists messages for offline availability.
  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    // Close the command palette whenever send is pressed
    setState(() => _showCommands = false);

    // Dispatch slash commands through the server so they land in shared history.
    if (text.startsWith('/')) {
      _controller.clear();
      _sendCommand(text);
      return;
    }

    if (!_takeoverMode && _containsTags(text)) {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'user',
            content: text,
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      });
      _rejectTagsWithEnd(text);
      _controller.clear();
      return;
    }

    final isSystemExecution = _containsTags(text);

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          role: 'user',
          content: text,
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
      if (isSystemExecution) {
        _messages.add(
          ChatMessage(
            role: 'system',
            content: 'System: Executing system commands...',
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      }
      _controller.clear();
    });
    _persistMessages();
    _scrollToBottom();

    final response = await ApiService().sendMessage(
      widget.agent.id.toString(),
      text,
      takeover: _takeoverMode,
    );
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (response != null) {
        // Check for error responses from the server
        final errorMsg = response['error'] as String?;
        if (errorMsg != null) {
          _messages.add(
            ChatMessage(
              role: 'system',
              content: 'Error: $errorMsg',
              timestamp: DateTime.now(),
              isRead: true,
            ),
          );
          _persistMessages();
          _scrollToBottom();
          return;
        }

        // Assistant messages are received via WebSocket broadcast (new_message event)
        // Only handle non-assistant responses here (system messages, etc.)
        final role = response['role'] as String?;
        if (role != 'assistant' && !isSystemExecution) {
          String message =
              response['message'] as String? ??
              response['response'] as String? ??
              '';

          if (message.isNotEmpty) {
            _messages.add(
              ChatMessage(
                role: role ?? 'system',
                content: message,
                timestamp: DateTime.now(),
                isRead: true,
              ),
            );
          }
        }
      } else {
        // In takeover mode the user is pretending to be the agent.
        // A network failure does not mean the agent failed — surface a clearer message.
        final errMsg = _takeoverMode
            ? 'System: Could not reach the server. Your message was saved locally.'
            : 'Error: Failed to reach the agent. Message kept locally — will retry when online.';
        _messages.add(
          ChatMessage(
            role: 'system',
            content: errMsg,
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      }
    });
    _persistMessages();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _pickAndUploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      final xfile = result.files.single.xFile;

      setState(() => _isSending = true);

      final containerId = widget.agent.containerId.isEmpty
          ? "agent-${widget.agent.name.toLowerCase()}"
          : widget.agent.containerId;

      bool success = await ApiService().uploadFileToContainer(
        containerId,
        xfile,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (success) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: 'system',
              content:
                  'File uploaded to workspace/in: ${result.files.single.name}',
              timestamp: DateTime.now(),
              isRead: true,
            ),
          );
        });
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File upload failed')));
      }
    }
  }

  /// Returns the background painter based on the mutable _backgroundId.
  /// This updates after the user saves changes in the config screen.
  CustomPainter _resolveBackgroundPainter() {
    return ChatBackgroundPainter.forId(_backgroundId);
  }

  // Deleted duplicate _buildInputArea
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(18),
              ),
              child: ClipOval(
                child:
                    widget.agent.profilePic != null &&
                        widget.agent.profilePic!.isNotEmpty
                    ? Image.network(
                        '${ApiService().baseUrl}${widget.agent.profilePic}',
                        fit: BoxFit.cover,
                        width: 36,
                        height: 36,
                        errorBuilder: (context, error, stackTrace) => Text(
                          widget.agent.name[0],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : Text(
                        widget.agent.name[0],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.agent.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'online',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy, size: 20),
            tooltip: 'Copy Context Window',
            onPressed: _copyContextWindow,
          ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.moreVertical, size: 20),
            color: const Color(0xFF18181B),
            onSelected: (value) {
              switch (value) {
                case 'status':
                  _sendCommand('/status');
                  break;
                case 'reset':
                  _sendCommand('/reset');
                  break;
                case 'clear':
                  _sendCommand('/clear');
                  break;
                case 'show_system':
                  _setShowSystemResponses(!_showSystemResponses);
                  break;
                case 'metrics':
                  _showMetrics();
                  break;
                case 'config':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreateAgentScreen(existingAgent: widget.agent),
                    ),
                  ).then((_) async {
                    if (!mounted) return;
                    final updatedBackground =
                        await ChatBackgroundPreferences.resolve(
                          widget.agent.id,
                          _backgroundId,
                        );
                    if (!mounted) return;
                    setState(() => _backgroundId = updatedBackground);
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'status',
                child: Row(
                  children: [
                    Icon(LucideIcons.activity, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Status', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(LucideIcons.rotateCcw, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Reset', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(LucideIcons.trash2, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Clear', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'metrics',
                child: Row(
                  children: [
                    Icon(LucideIcons.barChart2, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Metrics', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'config',
                child: Row(
                  children: [
                    Icon(LucideIcons.settings, size: 18, color: Colors.white),
                    SizedBox(width: 12),
                    Text('Config', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: _resolveBackgroundPainter(),
            size: Size.infinite,
          ),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _visibleMessages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isSending && index == _visibleMessages.length) {
                      return const _ThinkingBubble();
                    }
                    final msg = _visibleMessages[index];
                    final isUser = msg.role == 'user';
                    final isSystem = msg.role == 'system';
                    final isFirst =
                        index == 0 ||
                        _visibleMessages[index - 1].role != msg.role;
                    return _buildMessageBubble(
                      msg,
                      isUser,
                      isSystem,
                      isFirst,
                      index,
                    );
                  },
                ),
              ),
              _buildInputArea(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    bool isUser,
    bool isSystem,
    bool isFirst, [
    int? messageIndex,
  ]) {
    Color bgColor;
    Color textColor;

    if (isUser) {
      // User bubble: Green
      bgColor = const Color(0xFF10B981);
      textColor = Colors.white;
    } else if (isSystem) {
      // System bubble: Gray/Blackish
      bgColor = const Color(0xFF1A1A1A);
      textColor = const Color(0xFF9CA3AF);
    } else {
      // AI Agent bubble: White with black text
      bgColor = const Color(0xFFF4F4F5);
      textColor = Colors.black;
    }

    final baseUrl = ApiService().baseUrl ?? '';
    final avatarUrl = widget.agent.profilePic != null
        ? '$baseUrl${widget.agent.profilePic}'
        : null;

    Widget bubbleContent = GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: msg.content));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser
                ? const Radius.circular(18)
                : const Radius.circular(4),
            bottomRight: isUser
                ? const Radius.circular(4)
                : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSystem)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.bot,
                      size: 12,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'system',
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            if (msg.content.isNotEmpty)
              (!isUser && !isSystem)
                  ? _TypewriterText(
                      fullText: msg.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                      ),
                      shouldAnimate:
                          messageIndex != null &&
                          _animateMessages.contains(messageIndex),
                      onAnimationComplete: messageIndex != null
                          ? () {
                              _animateMessages.remove(messageIndex);
                            }
                          : null,
                    )
                  : Text(
                      msg.content,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.5),
                  ),
                ),
                if (isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (msg.files != null && msg.files!.isNotEmpty) {
      List<Widget> fileWidgets = [];
      for (final file in msg.files!) {
        final containerId = widget.agent.containerId.isEmpty
            ? 'agent-${widget.agent.name.toLowerCase()}'
            : widget.agent.containerId;
        final fileUrl =
            '$baseUrl/api/containers/$containerId/download?file=$file';
        final ext = file.split('.').last.toLowerCase();

        if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildFileCard(fileUrl, file, 'image', isSystem),
            ),
          );
        } else if (['mp4', 'webm', 'mov'].contains(ext)) {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildFileCard(fileUrl, file, 'video', isSystem),
            ),
          );
        } else {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: _buildFileCard(fileUrl, file, 'file', isSystem),
            ),
          );
        }
      }

      bubbleContent = Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [bubbleContent, ...fileWidgets],
      );
    }

    // System messages have their own avatar (mascot)
    if (isSystem) {
      return Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 60,
          top: isFirst ? 8 : 2,
          bottom: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isFirst)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF27272A),
                ),
                child: const ClipOval(
                  child: Center(
                    child: Icon(
                      LucideIcons.bot,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: bubbleContent,
              ),
            ),
          ],
        ),
      );
    }

    if (!isUser) {
      return Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 60,
          top: isFirst ? 8 : 2,
          bottom: 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isFirst)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE4E4E7),
                ),
                child: ClipOval(
                  child: avatarUrl != null
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          width: 28,
                          height: 28,
                          headers: {
                            'Authorization': 'Bearer ${ApiService().token}',
                          },
                          errorBuilder: (context, error, stackTrace) => Text(
                            widget.agent.name[0],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            widget.agent.name[0],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                            ),
                          ),
                        ),
                ),
              )
            else
              const SizedBox(width: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: bubbleContent,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 60,
        right: 12,
        top: isFirst ? 8 : 2,
        bottom: 2,
      ),
      child: Align(alignment: Alignment.centerRight, child: bubbleContent),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A1A))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'takeover',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF52525B),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF18181B),
                        title: const Text(
                          'Takeover Mode',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: const Text(
                          'When takeover mode is ON, you can directly control the system with commands like <terminal>ls -la</terminal>. The AI agent can not issue commands.\n\nWhen OFF (default), only the AI agent can issue commands.',
                          style: TextStyle(color: Color(0xFFA1A1AA)),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Got it',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(
                    LucideIcons.helpCircle,
                    size: 14,
                    color: Color(0xFF52525B),
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _takeoverMode,
                  onChanged: (val) => setState(() => _takeoverMode = val),
                  activeTrackColor: const Color(
                    0xFFEF4444,
                  ).withValues(alpha: 0.5),
                  inactiveTrackColor: const Color(0xFF1A1A1A),
                  thumbColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFFEF4444);
                    }
                    return const Color(0xFF52525B);
                  }),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'System',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF52525B),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF18181B),
                            title: const Text(
                              'System Messages',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Toggle to show/hide system messages in the chat. System messages include internal events, calendar actions, and execution feedback.',
                              style: TextStyle(color: Color(0xFFA1A1AA)),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Got it',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Icon(
                        LucideIcons.helpCircle,
                        size: 14,
                        color: Color(0xFF52525B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _showSystemResponses,
                      onChanged: (val) =>
                          setState(() => _showSystemResponses = val),
                      activeTrackColor: const Color(
                        0xFF10B981,
                      ).withValues(alpha: 0.5),
                      inactiveTrackColor: const Color(0xFF1A1A1A),
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF10B981);
                        }
                        return const Color(0xFF52525B);
                      }),
                    ),
                  ],
                ),
                const Spacer(),
                if (_takeoverMode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '<terminal>',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    LucideIcons.paperclip,
                    size: 20,
                    color: Color(0xFF52525B),
                  ),
                  onPressed: _isSending ? null : _pickAndUploadFile,
                ),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      onChanged: (value) {
                        // Show palette on '/' and keep it open for search filtering.
                        // Hide when the text is empty or no longer starts with '/'
                        setState(() {
                          _showCommands = value.startsWith('/');
                        });
                      },
                      style: TextStyle(
                        fontFamily: _takeoverMode ? 'monospace' : null,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _takeoverMode
                            ? 'Enter command (e.g., <terminal>ls</terminal>)'
                            : 'Message... or type / for commands',
                        hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
                        filled: true,
                        fillColor: const Color(0xFF1A1A1A),
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      LucideIcons.send,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            if (_showCommands && _filteredCommands.isNotEmpty)
              _buildCommandPalette(),
          ],
        ),
      ),
    );
  }

  /// Command palette widget shown when user types '/'.
  /// Acts as a real-time search filter — e.g. '/re' shows only /reset.
  Widget _buildCommandPalette() {
    final cmds = _filteredCommands;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'COMMANDS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF52525B),
                letterSpacing: 1,
              ),
            ),
          ),
          ...List.generate(cmds.length, (index) {
            final cmd = cmds[index];
            return InkWell(
              onTap: () {
                // Selecting a command executes it immediately
                _controller.clear();
                setState(() => _showCommands = false);
                _sendCommand(cmd['command']!);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cmd['command']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cmd['description']!,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Factory for all available chat background painters (dark mode).
/// Ref: docs/chat_backgrounds.md
class ChatBackgroundPainter {
  /// Returns the appropriate CustomPainter for the given background ID.
  static CustomPainter forId(String id) {
    switch (id) {
      case 'minimal':
        return _MinimalBackgroundPainter();
      case 'gradient':
        return _GradientBackgroundPainter();
      case 'grid':
        return _GridBackgroundPainter();
      case 'dots':
        return _DotsBackgroundPainter();
      case 'waves':
        return _WavesBackgroundPainter();
      case 'hexagon':
        return _HexagonBackgroundPainter();
      case 'circuit':
        return _CircuitBackgroundPainter();
      case 'aurora':
        return _AuroraBackgroundPainter();
      case 'doodle':
      default:
        return _DoodleBackgroundPainter();
    }
  }
}

// ─── Doodle (Telegram/WhatsApp-inspired, but distinct) ──────────────────────
class _DoodleBackgroundPainter extends CustomPainter {
  void _drawRoundedDiamond(
    Canvas canvas,
    Paint paint,
    Offset center,
    double radius,
  ) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * 0.9,
        center.dy - radius * 0.9,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.9,
        center.dy + radius * 0.9,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.9,
        center.dy + radius * 0.9,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.9,
        center.dy - radius * 0.9,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawPaperPlane(Canvas canvas, Paint paint, Offset center, double size) {
    final path = Path()
      ..moveTo(center.dx - size * 0.95, center.dy + size * 0.15)
      ..lineTo(center.dx + size, center.dy - size * 0.1)
      ..lineTo(center.dx - size * 0.15, center.dy + size * 0.95)
      ..lineTo(center.dx + size * 0.05, center.dy + size * 0.28)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(center.dx + size * 0.05, center.dy + size * 0.28),
      Offset(center.dx - size * 0.48, center.dy + size * 0.02),
      paint,
    );
  }

  void _drawCrescent(Canvas canvas, Paint paint, Offset center, double radius) {
    final outer = Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius));
    final inner = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(center.dx + radius * 0.42, center.dy - radius * 0.08),
          radius: radius * 0.82,
        ),
      );
    final path = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(path, paint);
  }

  void _drawSpark(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.28, center.dy - radius * 0.28)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.28, center.dy + radius * 0.28)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.28, center.dy - radius * 0.28)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawArcWave(Canvas canvas, Paint paint, Offset start, double width) {
    final path = Path()..moveTo(start.dx, start.dy);
    final segment = width / 3;
    for (int i = 0; i < 3; i++) {
      final x0 = start.dx + segment * i;
      final x1 = x0 + segment;
      path.quadraticBezierTo(
        x0 + segment / 2,
        start.dy - (i.isEven ? 10 : 7),
        x1,
        start.dy,
      );
    }
    canvas.drawPath(path, paint);
  }

  void _drawLoop(Canvas canvas, Paint paint, Offset center, Size size) {
    final path = Path()
      ..addOval(
        Rect.fromCenter(center: center, width: size.width, height: size.height),
      );
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );

    for (final (center, color, radius) in [
      (
        Offset(size.width * 0.18, size.height * 0.2),
        const Color(0x06BFE9FF),
        size.width * 0.42,
      ),
      (
        Offset(size.width * 0.84, size.height * 0.74),
        const Color(0x051EE3CF),
        size.width * 0.46,
      ),
    ]) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 110),
      );
    }

    final paint = Paint()
      ..color = const Color(0x12F4FBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    _drawPaperPlane(canvas, paint, Offset(w * 0.16, h * 0.13), w * 0.036);
    _drawPaperPlane(canvas, paint, Offset(w * 0.82, h * 0.27), w * 0.028);
    _drawPaperPlane(canvas, paint, Offset(w * 0.26, h * 0.82), w * 0.03);

    _drawCrescent(canvas, paint, Offset(w * 0.83, h * 0.13), w * 0.034);
    _drawCrescent(canvas, paint, Offset(w * 0.13, h * 0.63), w * 0.026);

    _drawRoundedDiamond(canvas, paint, Offset(w * 0.44, h * 0.16), w * 0.026);
    _drawRoundedDiamond(canvas, paint, Offset(w * 0.72, h * 0.58), w * 0.022);
    _drawRoundedDiamond(canvas, paint, Offset(w * 0.28, h * 0.4), w * 0.019);

    _drawSpark(canvas, paint, Offset(w * 0.62, h * 0.12), w * 0.024);
    _drawSpark(canvas, paint, Offset(w * 0.9, h * 0.72), w * 0.018);
    _drawSpark(canvas, paint, Offset(w * 0.18, h * 0.92), w * 0.018);

    _drawArcWave(canvas, paint, Offset(w * 0.08, h * 0.26), w * 0.26);
    _drawArcWave(canvas, paint, Offset(w * 0.58, h * 0.42), w * 0.2);
    _drawArcWave(canvas, paint, Offset(w * 0.3, h * 0.72), w * 0.24);

    _drawLoop(
      canvas,
      paint,
      Offset(w * 0.52, h * 0.3),
      Size(w * 0.11, h * 0.045),
    );
    _drawLoop(
      canvas,
      paint,
      Offset(w * 0.76, h * 0.87),
      Size(w * 0.13, h * 0.05),
    );
    _drawLoop(
      canvas,
      paint,
      Offset(w * 0.18, h * 0.5),
      Size(w * 0.09, h * 0.038),
    );

    final dotPaint = Paint()..color = const Color(0x14F8FDFF);
    for (final offset in [
      Offset(w * 0.34, h * 0.08),
      Offset(w * 0.69, h * 0.2),
      Offset(w * 0.49, h * 0.49),
      Offset(w * 0.11, h * 0.78),
      Offset(w * 0.59, h * 0.95),
      Offset(w * 0.87, h * 0.52),
    ]) {
      canvas.drawCircle(offset, 2.1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Minimal (subtle diagonal lines on pure black) ────────────────────────────
class _MinimalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF050505),
    );
    final p = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    const step = 28.0;
    for (double i = -size.height; i < size.width + size.height; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Gradient (dark purple-to-teal soft gradient) ─────────────────────────────
class _GradientBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF0D0D1A), Color(0xFF0A1628), Color(0xFF091A1A)],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // Soft luminous orbs
    for (final (pos, color, radius) in [
      (
        Offset(size.width * 0.15, size.height * 0.25),
        const Color(0x18673AB7),
        size.width * 0.5,
      ),
      (
        Offset(size.width * 0.85, size.height * 0.75),
        const Color(0x1200BCD4),
        size.width * 0.55,
      ),
    ]) {
      canvas.drawCircle(
        pos,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Grid (subtle dot-grid on near-black) ────────────────────────────────────
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF080808),
    );
    final p = Paint()..color = const Color(0x1AFFFFFF);
    const gap = 24.0;
    for (double x = 0; x < size.width; x += gap) {
      for (double y = 0; y < size.height; y += gap) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Dots (polka-dot pattern inspired by Telegram) ───────────────────────────
class _DotsBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A0A0A),
    );
    final p = Paint()..color = const Color(0x20FFFFFF);
    const gap = 20.0;
    bool offset = false;
    for (double y = 0; y < size.height + gap; y += gap) {
      for (double x = offset ? gap / 2 : 0.0; x < size.width + gap; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.5, p);
      }
      offset = !offset;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Waves (horizontal wave lines, Telegram-inspired) ────────────────────────
class _WavesBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF080810),
    );
    final p = Paint()
      ..color = const Color(0x12FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const waveHeight = 14.0;
    const waveLength = 60.0;
    const rowGap = 30.0;
    for (double y = 0; y < size.height + rowGap; y += rowGap) {
      final path = Path();
      path.moveTo(0, y);
      double x = 0;
      bool up = true;
      while (x < size.width) {
        path.quadraticBezierTo(
          x + waveLength / 2,
          y + (up ? -waveHeight : waveHeight),
          x + waveLength,
          y,
        );
        x += waveLength;
        up = !up;
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Hexagon (honeycomb grid) ─────────────────────────────────────────────────
class _HexagonBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF060608),
    );
    final p = Paint()
      ..color = const Color(0x12FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    const r = 22.0;
    final h = r * 1.732; // sqrt(3) * r
    final colSpacing = r * 3;
    final rowSpacing = h;
    for (double row = 0; row * rowSpacing < size.height + h; row++) {
      for (double col = 0; col * colSpacing < size.width + colSpacing; col++) {
        final cx = col * colSpacing + (row.toInt().isOdd ? r * 1.5 : 0);
        final cy = row * rowSpacing;
        _drawHex(canvas, Offset(cx, cy), r, p);
      }
    }
  }

  void _drawHex(Canvas canvas, Offset center, double r, Paint p) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (60 * i - 30) * 3.14159 / 180;
      final x = center.dx + r * (angle == 0 ? 1 : (Math_cos(angle)));
      final y = center.dy + r * Math_sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  // Inline trig helpers to avoid dart:math import collision in scope
  static double Math_sin(double a) => _sin(a);
  static double Math_cos(double a) => _cos(a);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double _sin(double a) => math.sin(a);
double _cos(double a) => math.cos(a);

// ─── Circuit (PCB trace lines) ────────────────────────────────────────────────
class _CircuitBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF040A08),
    );
    final p = Paint()
      ..color = const Color(0x1810B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final nodePaint = Paint()..color = const Color(0x2510B981);

    // Draw horizontal and vertical trace lines
    final segs = [
      [0.1, 0.2, 0.5, 0.2],
      [0.5, 0.2, 0.5, 0.5],
      [0.5, 0.5, 0.9, 0.5],
      [0.2, 0.4, 0.2, 0.7],
      [0.2, 0.7, 0.6, 0.7],
      [0.6, 0.7, 0.6, 0.9],
      [0.7, 0.1, 0.7, 0.35],
      [0.7, 0.35, 0.95, 0.35],
      [0.05, 0.6, 0.35, 0.6],
      [0.35, 0.6, 0.35, 0.85],
      [0.4, 0.15, 0.4, 0.4],
      [0.4, 0.4, 0.65, 0.4],
      [0.8, 0.55, 0.8, 0.8],
      [0.15, 0.9, 0.55, 0.9],
    ];
    for (final s in segs) {
      canvas.drawLine(
        Offset(size.width * s[0], size.height * s[1]),
        Offset(size.width * s[2], size.height * s[3]),
        p,
      );
    }
    // Draw circuit nodes
    for (final n in [
      [0.5, 0.2],
      [0.5, 0.5],
      [0.2, 0.7],
      [0.6, 0.7],
      [0.7, 0.35],
      [0.35, 0.6],
      [0.4, 0.4],
      [0.8, 0.55],
    ]) {
      canvas.drawCircle(
        Offset(size.width * n[0], size.height * n[1]),
        3,
        nodePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Aurora (animated-look northern lights gradient) ─────────────────────────
class _AuroraBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF05080F),
    );
    // Aurora bands
    final bands = [
      (
        Offset(size.width * 0.0, size.height * 0.35),
        const Color(0x18006064),
        size.width * 0.8,
      ),
      (
        Offset(size.width * 0.3, size.height * 0.5),
        const Color(0x12004D40),
        size.width * 0.9,
      ),
      (
        Offset(size.width * 0.6, size.height * 0.25),
        const Color(0x151A237E),
        size.width * 0.7,
      ),
    ];
    for (final (center, color, radius) in bands) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
      );
    }
    // Subtle star dots
    final starPaint = Paint()..color = const Color(0x25FFFFFF);
    for (final pos in [
      Offset(size.width * 0.1, size.height * 0.08),
      Offset(size.width * 0.3, size.height * 0.15),
      Offset(size.width * 0.55, size.height * 0.06),
      Offset(size.width * 0.75, size.height * 0.12),
      Offset(size.width * 0.9, size.height * 0.07),
      Offset(size.width * 0.45, size.height * 0.2),
      Offset(size.width * 0.85, size.height * 0.25),
      Offset(size.width * 0.15, size.height * 0.3),
    ]) {
      canvas.drawCircle(pos, 1.0, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;
  StreamSubscription? _healthSubscription;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
    _healthSubscription = ApiService().healthStream.listen((data) {
      if (mounted) {
        setState(() {
          _metrics = data;
        });
      }
    });
  }

  @override
  void dispose() {
    _healthSubscription?.cancel();
    super.dispose();
  }

  Color _getUsageColor(double value) {
    if (value < 50) return const Color(0xFF10B981);
    if (value < 80) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Future<void> _loadMetrics() async {
    final data = await ApiService().getMetrics();
    if (mounted) {
      setState(() {
        _metrics = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = _metrics?['host'] ?? {};
    final containers = _metrics?['containers'] as List<dynamic>? ?? [];

    final cpuVal = host['cpuPercent'] ?? host['cpu'] ?? 0.0;
    final memVal = host['memUsageMB'] ?? host['memory'] ?? 0.0;

    final cpuStr = (cpuVal is num) ? cpuVal.toStringAsFixed(1) : '0.0';
    final memStr = (memVal is num) ? (memVal / 1024).toStringAsFixed(1) : '0.0';

    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Colors.white))
        : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'system health',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'CPU',
                        cpuStr,
                        '%',
                        LucideIcons.cpu,
                        _getUsageColor(cpuVal.toDouble()),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricCard(
                        'RAM',
                        memStr,
                        'gb',
                        LucideIcons.memoryStick,
                        _getUsageColor(
                          (memVal.toDouble() / 16000.0) * 100,
                        ), // Assuming 16GB total for color scaling
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMetricCard(
                  'STORAGE',
                  '45.1',
                  'gb',
                  LucideIcons.hardDrive,
                  Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  'active containers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: containers.length,
                    itemBuilder: (context, index) {
                      final container = containers[index];
                      final name = container['name'] ?? 'Unknown';
                      final cCpu = container['cpuPercent'] ?? 0.0;
                      final cMem = container['memUsageMB'] ?? 0.0;

                      final cCpuStr = (cCpu is num)
                          ? cCpu.toStringAsFixed(1)
                          : '0.0';
                      final cMemStr = (cMem is num)
                          ? (cMem / 1024).toStringAsFixed(1)
                          : '0.0'; // Assuming cMem is in MB, convert to GB.

                      return _buildContainerRow(
                        name,
                        cCpuStr,
                        cMemStr,
                        _getUsageColor(cCpu.toDouble()),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title.toLowerCase(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContainerRow(String name, String cpu, String ram, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(LucideIcons.box, size: 16, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'cpu $cpu',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'mem $ram',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(LucideIcons.activity, size: 16, color: color),
        ],
      ),
    );
  }
}

class CreateAgentScreen extends StatefulWidget {
  final Agent? existingAgent;
  const CreateAgentScreen({super.key, this.existingAgent});

  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _roleCtrl;
  late TextEditingController _personalityCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _tokenCtrl;
  String _provider = 'openrouter';
  String _platform = 'hermitchat';
  String _background = 'doodle';
  String? _profilePicUrl;
  String? _bannerUrl;
  bool _isDeploying = false;
  bool _isResetting = false;
  bool _isDeleting = false;
  final ImagePicker _picker = ImagePicker();

  static const List<Map<String, String>> _backgrounds = [
    {'id': 'doodle', 'name': 'Doodle', 'desc': 'Planes, crescents & waves'},
    {'id': 'minimal', 'name': 'Minimal', 'desc': 'Subtle diagonal lines'},
    {'id': 'gradient', 'name': 'Gradient', 'desc': 'Dark purple-teal glow'},
    {'id': 'grid', 'name': 'Grid', 'desc': 'Dot-grid pattern'},
    {'id': 'dots', 'name': 'Dots', 'desc': 'Staggered polka dots'},
    {'id': 'waves', 'name': 'Waves', 'desc': 'Horizontal wave lines'},
    {'id': 'hexagon', 'name': 'Hexagon', 'desc': 'Honeycomb grid'},
    {'id': 'circuit', 'name': 'Circuit', 'desc': 'PCB trace lines'},
    {'id': 'aurora', 'name': 'Aurora', 'desc': 'Northern lights'},
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingAgent?.name ?? '');
    _roleCtrl = TextEditingController(text: widget.existingAgent?.role ?? '');
    _personalityCtrl = TextEditingController(
      text: widget.existingAgent?.personality ?? '',
    );
    _modelCtrl = TextEditingController(text: widget.existingAgent?.model ?? '');
    _tokenCtrl =
        TextEditingController(); // Token usually not returned for security
    _provider = widget.existingAgent?.provider ?? 'openrouter';
    _platform = widget.existingAgent?.platform ?? 'hermitchat';
    _background = widget.existingAgent?.background ?? 'doodle';
    _profilePicUrl = widget.existingAgent?.profilePic;
    _loadSavedBackground();
  }

  Future<void> _loadSavedBackground() async {
    final existingAgent = widget.existingAgent;
    if (existingAgent == null) return;
    final background = await ChatBackgroundPreferences.resolve(
      existingAgent.id,
      existingAgent.background,
    );
    if (!mounted) return;
    setState(() => _background = background);
  }

  Future<void> _pickImage(bool isProfile) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final url = await ApiService().uploadImage(image);
      if (url != null) {
        setState(() {
          if (isProfile) {
            _profilePicUrl = url;
          } else {
            _bannerUrl = url;
          }
        });
      }
    }
  }

  void _handleDeploy() async {
    if (_nameCtrl.text.isEmpty || _roleCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Role are required')),
      );
      return;
    }

    setState(() => _isDeploying = true);

    final payload = {
      'name': _nameCtrl.text.trim(),
      'role': _roleCtrl.text.trim(),
      'personality': _personalityCtrl.text.trim(),
      'provider': _provider,
      'model': _modelCtrl.text.trim(),
      'platform': _platform,
      'profilePic': _profilePicUrl ?? '',
      'bannerUrl': _bannerUrl ?? '',
      'background': _background,
    };

    if (_platform == 'telegram') {
      payload['telegramToken'] = _tokenCtrl.text.trim();
    }

    bool success = false;
    String? savedAgentId;
    if (widget.existingAgent != null) {
      success = await ApiService().updateAgent(
        widget.existingAgent!.id,
        payload,
      );
      if (success) {
        savedAgentId = widget.existingAgent!.id;
      }
    } else {
      final result = await ApiService().createAgent(payload);
      success = result != null && result['success'] == true;
      if (success && result['id'] != null) {
        savedAgentId = result['id'].toString();
      }
    }

    if (!mounted) return;
    setState(() => _isDeploying = false);

    if (success) {
      if (savedAgentId != null) {
        await ChatBackgroundPreferences.save(savedAgentId, _background);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deployment/Update failed')));
    }
  }

  void _handleResetContainer() async {
    if (widget.existingAgent == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Reset Container',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to reset the container? This will restart the agent\'s workspace.',
          style: TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isResetting = true);

    final containerId = widget.existingAgent!.containerId.isEmpty
        ? 'agent-${widget.existingAgent!.name.toLowerCase()}'
        : widget.existingAgent!.containerId;

    final success = await ApiService().resetContainer(containerId);

    if (!mounted) return;
    setState(() => _isResetting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Container reset successfully'
              : 'Failed to reset container',
        ),
      ),
    );
  }

  void _handleDeleteAgent() async {
    if (widget.existingAgent == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Agent',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this agent? This action cannot be undone.',
          style: TextStyle(color: Color(0xFFA1A1AA)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    final success = await ApiService().deleteAgent(widget.existingAgent!.id);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent deleted successfully')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete agent')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          widget.existingAgent != null ? 'configure agent' : 'new deployment',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: () => _pickImage(true),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1A1A1A),
                  backgroundImage: _profilePicUrl != null
                      ? NetworkImage('${ApiService().baseUrl}$_profilePicUrl')
                      : null,
                  child: _profilePicUrl == null
                      ? const Icon(LucideIcons.camera, color: Colors.white)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'tap to change profile pic',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),

            _buildSectionTitle('identity'),
            _buildTextField(_nameCtrl, 'Agent Name', 'e.g. Ralph'),
            _buildTextField(_roleCtrl, 'Role', 'e.g. Code Assistant'),
            _buildTextField(
              _personalityCtrl,
              'Personality',
              'e.g. Concise and helpful',
            ),

            _buildSectionTitle('provider'),
            _buildChoiceChip('openrouter', 'OpenRouter (Free)'),
            _buildChoiceChip('openai', 'OpenAI'),
            _buildChoiceChip('anthropic', 'Anthropic'),
            _buildChoiceChip('gemini', 'Google Gemini'),
            _buildTextField(
              _modelCtrl,
              'Specific Model',
              'e.g. gemini-2.0-flash-exp',
            ),

            _buildSectionTitle('platform'),
            Row(
              children: [
                Expanded(
                  child: _buildPlatformChip(
                    'hermitchat',
                    'HermitChat',
                    LucideIcons.messageSquare,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPlatformChip(
                    'telegram',
                    'Telegram',
                    LucideIcons.send,
                  ),
                ),
              ],
            ),

            if (_platform == 'telegram') ...[
              const SizedBox(height: 16),
              _buildTextField(_tokenCtrl, 'Bot Token', '123456:BC...'),
            ],

            _buildSectionTitle('chat background'),
            _buildBackgroundPicker(),

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isDeploying ? null : _handleDeploy,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isDeploying
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        widget.existingAgent != null
                            ? 'save changes'
                            : 'deploy agent',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            if (widget.existingAgent != null) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isResetting ? null : _handleResetContainer,
                      icon: _isResetting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(LucideIcons.rotateCcw, size: 16),
                      label: const Text('Reset Container'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF27272A)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isDeleting ? null : _handleDeleteAgent,
                      icon: _isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.red,
                              ),
                            )
                          : const Icon(
                              LucideIcons.trash2,
                              size: 16,
                              color: Colors.redAccent,
                            ),
                      label: const Text(
                        'Delete Agent',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toLowerCase(),
        style: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String label,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Colors.grey),
          hintStyle: const TextStyle(color: Color(0xFF27272A)),
          filled: true,
          fillColor: const Color(0xFF09090B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF27272A)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF27272A)),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip(String val, String label) {
    final isSelected = _provider == val;
    return GestureDetector(
      onTap: () => setState(() => _provider = val),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF27272A),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformChip(String val, String label, IconData icon) {
    final isSelected = _platform == val;
    return GestureDetector(
      onTap: () => setState(() => _platform = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF27272A),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Background picker for the chat screen.
  /// Shows a scrollable grid of labelled previews.
  /// Ref: docs/chat_backgrounds.md
  Widget _buildBackgroundPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        // Preview box of selected background
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            child: CustomPaint(
              painter: ChatBackgroundPainter.forId(_background),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _backgrounds.length,
          itemBuilder: (context, index) {
            final bg = _backgrounds[index];
            final isSelected = _background == bg['id'];
            return GestureDetector(
              onTap: () => setState(() => _background = bg['id']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0xFF27272A),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: ChatBackgroundPainter.forId(bg['id']!),
                        size: Size.infinite,
                      ),
                      // Overlay label at the bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: Text(
                            bg['name']!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _tunnelEnabled = true;
  String _tunnelUrl = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingKeys = false;
  String _timeOffset = '0';
  String _pendingOffset = '0';
  DateTime? _serverTime;
  DateTime? _serverUtcTime;
  Timer? _timeTimer;

  final TextEditingController _openrouterController = TextEditingController();
  final TextEditingController _openaiController = TextEditingController();
  final TextEditingController _anthropicController = TextEditingController();
  final TextEditingController _geminiController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _syncTime();
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncTime() async {
    final data = await ApiService().getServerTime();
    if (data != null && mounted) {
      setState(() {
        try {
          final rawUtcStr =
              (data['serverUtcTime'] ?? data['datetime'] ?? data['time'])
                  .toString();
          _serverUtcTime = DateTime.parse(rawUtcStr);
          _timeOffset = data['offset']?.toString() ?? '0';
          _pendingOffset = _timeOffset;
          _updateDisplayedTimes();
          _startTimeTicker();
        } catch (e) {
          debugPrint('Error parsing server time: $e');
          _serverUtcTime = DateTime.now().toUtc();
          _updateDisplayedTimes();
        }
      });
    } else if (mounted) {
      setState(() {
        _serverUtcTime ??= DateTime.now().toUtc();
        _updateDisplayedTimes();
      });
    }
  }

  void _updateDisplayedTimes() {
    if (_serverUtcTime == null) return;
    final offset = int.tryParse(_timeOffset) ?? 0;
    // System time is raw server UTC + the user's defined offset
    _serverTime = _serverUtcTime!.toUtc().add(Duration(hours: offset));
  }

  void _startTimeTicker() {
    _timeTimer?.cancel();
    _timeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _serverUtcTime != null) {
        setState(() {
          _serverUtcTime = _serverUtcTime!.add(const Duration(seconds: 1));
          _updateDisplayedTimes();
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    final api = ApiService();
    try {
      final settings = await api.getSettings();
      if (settings != null && mounted) {
        setState(() {
          _tunnelEnabled =
              settings['tunnelEnabled'] == true ||
              settings['tunnelEnabled'] == 'true';
          _tunnelUrl = settings['tunnelURL'] ?? '';
          _timeOffset = settings['timeOffset']?.toString() ?? '0';
          // Update text fields with actual key values from server
          final openrouterKey = settings['openrouterKey']?.toString() ?? '';
          final openaiKey = settings['openaiKey']?.toString() ?? '';
          final anthropicKey = settings['anthropicKey']?.toString() ?? '';
          final geminiKey = settings['geminiKey']?.toString() ?? '';

          if (openrouterKey.isNotEmpty) {
            _openrouterController.text = openrouterKey;
          }
          if (openaiKey.isNotEmpty) {
            _openaiController.text = openaiKey;
          }
          if (anthropicKey.isNotEmpty) {
            _anthropicController.text = anthropicKey;
          }
          if (geminiKey.isNotEmpty) {
            _geminiController.text = geminiKey;
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final List<Map<String, String>> _timePresets = [
    {'label': 'UTC', 'value': '0', 'desc': 'London'},
    {'label': '+8h', 'value': '8', 'desc': 'Manila'},
    {'label': '+9h', 'value': '9', 'desc': 'Tokyo'},
    {'label': '+1h', 'value': '1', 'desc': 'Paris'},
    {'label': '-5h', 'value': '-5', 'desc': 'New York'},
    {'label': '-8h', 'value': '-8', 'desc': 'Los Angeles'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text(
            'settings',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _buildPublicUrlSection(),
                const SizedBox(height: 16),
                _buildTimeSettingsSection(),
                const SizedBox(height: 16),
                _buildApiKeysSection(),
                const SizedBox(height: 16),
                _buildCredentialsSection(),
                const SizedBox(height: 16),
                _buildSessionSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF09090B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(
                title.toLowerCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildPublicUrlSection() {
    return _buildSectionCard(
      title: 'Cloudflare Tunnel',
      icon: LucideIcons.globe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Enable Cloudflare Tunnel',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Switch(
                value: _tunnelEnabled,
                activeTrackColor: const Color(
                  0xFF10B981,
                ).withValues(alpha: 0.5),
                activeThumbColor: const Color(0xFF10B981),
                onChanged: _isLoading
                    ? null
                    : (val) async {
                        setState(() => _isLoading = true);
                        final success = await ApiService().updateSettings({
                          'tunnelEnabled': val,
                        });
                        if (success) {
                          setState(() {
                            _tunnelEnabled = val;
                            _isLoading = false;
                          });
                        } else {
                          setState(() => _isLoading = false);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Allows external access to the dashboard and apps.',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          if (_tunnelEnabled && _tunnelUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF09090B),
                border: Border.all(color: const Color(0xFF27272A)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.link,
                    size: 16,
                    color: Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _tunnelUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF10B981),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiKeysSection() {
    return _buildSectionCard(
      title: 'API Keys',
      icon: LucideIcons.key,
      child: Column(
        children: [
          _buildTextField(
            'OpenRouter API Key (Free Models)',
            'sk-or-...',
            obscure: true,
            controller: _openrouterController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'OpenAI API Key',
            'sk-...',
            obscure: true,
            controller: _openaiController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Anthropic API Key',
            'sk-ant-...',
            obscure: true,
            controller: _anthropicController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Gemini API Key',
            'AIza...',
            obscure: true,
            controller: _geminiController,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isSavingKeys = true);
                      final success = await ApiService().updateSettings({
                        'openrouterKey': _openrouterController.text,
                        'openaiKey': _openaiController.text,
                        'anthropicKey': _anthropicController.text,
                        'geminiKey': _geminiController.text,
                      });
                      if (mounted) {
                        setState(() => _isSavingKeys = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success ? 'API Keys updated' : 'Update failed',
                            ),
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSavingKeys
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text(
                      'Save Keys',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSettingsSection() {
    final now = _serverTime;
    final preview = _serverUtcTime?.add(
      Duration(hours: int.tryParse(_pendingOffset) ?? 0),
    );

    String formatTime(DateTime? t) {
      if (t == null) return "--:--:--";
      final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
      final ampm = t.hour >= 12 ? 'PM' : 'AM';
      return "${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')} $ampm";
    }

    return _buildSectionCard(
      title: 'System Time',
      icon: LucideIcons.clock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTimeCard(
                  label: 'GLOBAL SYSTEM TIME',
                  time: formatTime(now),
                  color: const Color(0xFF10B981),
                  isActive: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeCard(
                  label: 'PREVIEW (+${_pendingOffset}h)',
                  time: formatTime(preview),
                  color: const Color(0xFF3B82F6),
                  isActive: _pendingOffset != _timeOffset,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.globe,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  'SERVER OFFSET: UTC${int.parse(_timeOffset) >= 0 ? '+' : ''}${_timeOffset}h',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1E293B)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CUSTOM OFFSET',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF71717A),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${int.tryParse(_pendingOffset) ?? 0}h',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF3B82F6),
              inactiveTrackColor: const Color(0xFF1E293B),
              thumbColor: Colors.white,
              overlayColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
              trackHeight: 4.0,
            ),
            child: Slider(
              value: (int.tryParse(_pendingOffset) ?? 0).toDouble(),
              min: -12,
              max: 14,
              divisions: 26,
              onChanged: (value) {
                setState(() {
                  _pendingOffset = value.toInt().toString();
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'PRESETS',
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF71717A),
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.8,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _timePresets.length,
            itemBuilder: (context, index) {
              final preset = _timePresets[index];
              final isSelected = _pendingOffset == preset['value'];
              final isCurrent = _timeOffset == preset['value'];

              return GestureDetector(
                onTap: () {
                  setState(() => _pendingOffset = preset['value']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF09090B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3B82F6)
                          : (isCurrent
                                ? const Color(0xFF10B981)
                                : const Color(0xFF27272A)),
                      width: isSelected || isCurrent ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        preset['label']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                      ),
                      Text(
                        preset['desc']!,
                        style: TextStyle(
                          fontSize: 9,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          if (_pendingOffset != _timeOffset)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        final success = await ApiService().updateSettings({
                          'timeOffset': _pendingOffset,
                        });
                        if (success) {
                          await _syncTime();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('System time synchronized'),
                              ),
                            );
                          }
                        }
                        if (mounted) setState(() => _isSaving = false);
                      },
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(LucideIcons.save, size: 16),
                label: const Text(
                  'Save Sync',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeCard({
    required String label,
    required String time,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.1)
            : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.withValues(alpha: 0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: isActive ? color : const Color(0xFF64748B),
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              time,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: isActive ? color : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return _buildSectionCard(
      title: 'Account Credentials',
      icon: LucideIcons.user,
      child: Column(
        children: [
          _buildTextField(
            'New Username',
            'Enter new username',
            obscure: false,
            controller: _usernameController,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'New Password',
            'Enter new password',
            obscure: true,
            controller: _passwordController,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      // Implement creditial update logic if needed
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Update Credentials',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Backup & Restore section removed for mobile optimization.
  // Use the Web Dashboard for full backups.

  Widget _buildSessionSection() {
    return _buildSectionCard(
      title: 'Session',
      icon: LucideIcons.logOut,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onLogout,
          icon: const Icon(LucideIcons.logOut, size: 16),
          label: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF450A0A),
            foregroundColor: const Color(0xFFF87171),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    required bool obscure,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF52525B),
              letterSpacing: 1.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF3F3F46)),
            filled: true,
            fillColor: Colors.black,
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<dynamic> _apps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchApps();
  }

  Future<void> _fetchApps() async {
    final apps = await ApiService().getApps();
    if (mounted) {
      setState(() {
        _apps = apps;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }
    if (_apps.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.layoutGrid,
              size: 48,
              color: Color(0xFF52525B),
            ),
            const SizedBox(height: 16),
            Text(
              'No apps found',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Text(
            'apps',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _apps.length,
            itemBuilder: (context, index) {
              final app = _apps[index];
              return Card(
                color: const Color(0xFF09090B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF27272A)),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF27272A),
                    radius: 24,
                    child: Icon(LucideIcons.layoutGrid, color: Colors.white),
                  ),
                  title: Text(
                    app['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Text(
                    'Agent: ${app['agentName']} | Container: ${app['containerId']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: const Icon(
                    LucideIcons.chevronRight,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppViewerScreen(
                          appName: app['name'],
                          url: '${ApiService().baseUrl}${app['url']}',
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class AppViewerScreen extends StatefulWidget {
  final String appName;
  final String url;
  const AppViewerScreen({super.key, required this.appName, required this.url});

  @override
  State<AppViewerScreen> createState() => _AppViewerScreenState();
}

class _AppViewerScreenState extends State<AppViewerScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appName),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
