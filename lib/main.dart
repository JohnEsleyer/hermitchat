import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'api_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<CalendarEventModel> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final data = await ApiService().getCalendarEvents();
    if (mounted) {
      setState(() {
        _events = data.map((e) => CalendarEventModel.fromJson(e)).toList();
        _events.sort((a, b) {
          final timeA = a.date + a.time;
          final timeB = b.date + b.time;
          return timeA.compareTo(timeB);
        });
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteEvent(int id) async {
    final success = await ApiService().deleteCalendarEvent(id);
    if (success) {
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
          ? const Center(
              child: Text(
                'No upcoming events',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return Card(
                  color: const Color(0xFF09090B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFF27272A)),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: event.executed
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFF3F3F46),
                      child: Icon(
                        event.executed
                            ? LucideIcons.check
                            : LucideIcons.calendar,
                        color: event.executed
                            ? const Color(0xFF10B981)
                            : Colors.white,
                      ),
                    ),
                    title: Text(
                      event.prompt,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${event.date} at ${event.time} • Agent: ${event.agent}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteEvent(event.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;
  final String token;
  const _VideoPlayerWidget({required this.url, required this.token});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(
            Uri.parse(widget.url),
            httpHeaders: {'Authorization': 'Bearer ${widget.token}'},
          )
          ..initialize().then((_) {
            setState(() {});
          });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_controller),
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: Colors.red),
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
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isRead;
  final List<String>? files;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isRead = false,
    this.files,
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

  @override
  void initState() {
    super.initState();
    _loadAgents();
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
      setState(() {
        _agents = data.map((json) => Agent.fromJson(json)).toList();
        _filteredAgents = _agents;
        _isLoading = false;
      });
    }
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
                    final lastMsg = ChatMessage(
                      role: 'system',
                      content: isTelegram
                          ? 'Limited: Telegram Mode'
                          : 'Active connection to OS',
                      timestamp: DateTime.now(),
                      isRead: true,
                    );

                    return GestureDetector(
                      onTap: isTelegram
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(agent: agent),
                              ),
                            ),
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
                                            isTelegram
                                                ? 'Managed via Telegram'
                                                : lastMsg.content,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isTelegram
                                                  ? Colors.blueGrey
                                                  : const Color(0xFF71717A),
                                            ),
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
  final List<ChatMessage> _messages = [];
  StreamSubscription? _wsSubscription;

  static final RegExp _tagPattern = RegExp(
    r'<([a-zA-Z_][a-zA-Z0-9_]*)>.*?</\1>',
    multiLine: true,
  );

  static const List<Map<String, String>> _commands = [
    {'command': '/status', 'description': 'Show agent configuration & health'},
    {'command': '/reset', 'description': 'Restart agent container'},
    {'command': '/clear', 'description': 'Clear chat context'},
  ];

  bool _containsTags(String text) {
    return _tagPattern.hasMatch(text);
  }

  void _rejectTagsWithEnd(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'system',
          content: 'Tag rejected: Tags are not allowed in current mode. $text',
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
    _scrollToBottom();
  }

  void _sendCommand(String command) async {
    setState(() {
      _messages.add(
        ChatMessage(
          role: 'user',
          content: command,
          timestamp: DateTime.now(),
          isRead: true,
        ),
      );
    });
    _scrollToBottom();

    final response = await ApiService().sendMessage(
      widget.agent.id.toString(),
      command,
    );
    if (!mounted) return;

    if (response != null) {
      final message =
          response['message'] as String? ??
          response['response'] as String? ??
          '';
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: message,
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      });
    } else {
      setState(() {
        _messages.add(
          ChatMessage(
            role: 'system',
            content: 'Command executed.',
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      });
    }
    _scrollToBottom();
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
    _loadMessages();

    _wsSubscription = ApiService().messageStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'new_message' &&
          data['agent_id'].toString() == widget.agent.id.toString()) {
        setState(() {
          // Check if message already exists
          if (!_messages.any(
            (m) => m.content == data['content'] && m.role == data['role'],
          )) {
            _messages.add(
              ChatMessage(
                role: data['role'],
                content: data['content'],
                timestamp: DateTime.now(),
                isRead: true,
              ),
            );
            _scrollToBottom();
          }
        });

        if (data['role'] == 'assistant') {
          _showNotification(data['content']);
        }
      }
    });
  }

  Future<void> _loadMessages() async {
    // We could fetch actual history here if we had an endpoint for it in ApiService
    // For now, it's enough to clear and wait for new ones or we can mock it
  }

  Future<void> _showNotification(String body) async {
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

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

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
      _controller.clear();
    });
    _scrollToBottom();

    final response = await ApiService().sendMessage(
      widget.agent.id.toString(),
      text,
    );
    if (!mounted) return;

    setState(() {
      _isSending = false;
      if (response != null) {
        String message =
            response['message'] as String? ??
            response['response'] as String? ??
            '';

        if (_takeoverMode && _containsTags(message)) {
          message = message.replaceAll(_tagPattern, '[Tag rejected]');
          _messages.add(
            ChatMessage(
              role: 'system',
              content: '<end>',
              timestamp: DateTime.now(),
              isRead: true,
            ),
          );
        }

        final filesDynamic = response['files'] as List<dynamic>? ?? [];
        final files = filesDynamic.map((f) => f.toString()).toList();

        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: message,
            timestamp: DateTime.now(),
            isRead: true,
            files: files.isNotEmpty ? files : null,
          ),
        );
      } else {
        _messages.add(
          ChatMessage(
            role: 'system',
            content: 'Error: Failed to reach the agent.',
            timestamp: DateTime.now(),
            isRead: true,
          ),
        );
      }
    });
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
                  );
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
          CustomPaint(painter: _DoodleBackgroundPainter(), size: Size.infinite),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg.role == 'user';
                    final isSystem = msg.role == 'system';
                    final isFirst =
                        index == 0 || _messages[index - 1].role != msg.role;
                    return _buildMessageBubble(msg, isUser, isSystem, isFirst);
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
    bool isFirst,
  ) {
    Color bgColor;
    Color textColor;

    if (isUser) {
      bgColor = const Color(0xFF1A1A1A);
      textColor = Colors.white;
    } else if (isSystem) {
      bgColor = const Color(0xFF0A2A1A);
      textColor = const Color(0xFF6EE7B7);
    } else {
      bgColor = const Color(0xFF0F0F0F);
      textColor = const Color(0xFFE4E4E7);
    }

    final baseUrl = ApiService().baseUrl ?? '';
    final avatarUrl = widget.agent.profilePic != null
        ? '$baseUrl${widget.agent.profilePic}'
        : null;

    Widget bubbleContent = Container(
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
          if (msg.content.isNotEmpty)
            Text(
              msg.content,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
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
                  color: msg.isRead
                      ? const Color(0xFF10B981)
                      : textColor.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (msg.files != null && msg.files!.isNotEmpty) {
      List<Widget> fileWidgets = [];
      for (final file in msg.files!) {
        final containerId =
            'agent-${widget.agent.name.toLowerCase().replaceAll(' ', '')}';
        final fileUrl =
            '$baseUrl/api/containers/$containerId/download?file=$file';
        final ext = file.split('.').last.toLowerCase();

        if (['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  fileUrl,
                  headers: {'Authorization': 'Bearer ${ApiService().token}'},
                ),
              ),
            ),
          );
        } else if (['mp4', 'webm'].contains(ext)) {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _VideoPlayerWidget(
                  url: fileUrl,
                  token: ApiService().token ?? '',
                ),
              ),
            ),
          );
        } else {
          fileWidgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.file, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(file, style: const TextStyle(color: Colors.blue)),
                ],
              ),
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

    if (!isUser && !isSystem) {
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
                  color: const Color(0xFF1A1A1A),
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
                            style: const TextStyle(fontSize: 10),
                          ),
                        )
                      : Center(
                          child: Text(
                            widget.agent.name[0],
                            style: const TextStyle(fontSize: 10),
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
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: isFirst ? 8 : 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: bubbleContent,
      ),
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
                          'When takeover mode is ON, you can directly control the system with commands like <terminal>ls -la</terminal>. The AI agent will not process commands.\n\nWhen OFF (default), only the AI agent can execute commands.',
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
            if (_showCommands) _buildCommandPalette(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandPalette() {
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
          ...List.generate(_commands.length, (index) {
            final cmd = _commands[index];
            return InkWell(
              onTap: () {
                _controller.text = cmd['command']!;
                setState(() => _showCommands = false);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(
                      cmd['command']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
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

class _DoodleBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), blackPaint);

    final lightPaint1 = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.2),
      size.width * 0.4,
      lightPaint1,
    );

    final lightPaint2 = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.7),
      size.width * 0.5,
      lightPaint2,
    );

    final lightPaint3 = Paint()
      ..color = const Color(0x08FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 1.0),
      size.width * 0.3,
      lightPaint3,
    );

    final doodlePaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path1 = Path();
    path1.moveTo(size.width * 0.1, size.height * 0.15);
    path1.lineTo(size.width * 0.3, size.height * 0.15);
    path1.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.15,
      size.width * 0.38,
      size.height * 0.21,
    );
    path1.lineTo(size.width * 0.38, size.height * 0.25);
    path1.quadraticBezierTo(
      size.width * 0.38,
      size.height * 0.31,
      size.width * 0.3,
      size.height * 0.31,
    );
    path1.lineTo(size.width * 0.18, size.height * 0.35);
    path1.lineTo(size.width * 0.12, size.height * 0.4);
    path1.lineTo(size.width * 0.18, size.height * 0.4);
    path1.lineTo(size.width * 0.26, size.height * 0.35);
    path1.quadraticBezierTo(
      size.width * 0.26,
      size.height * 0.31,
      size.width * 0.3,
      size.height * 0.31,
    );
    canvas.drawPath(path1, doodlePaint);

    final rectPaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.65,
          size.height * 0.08,
          size.width * 0.09,
          size.height * 0.09,
        ),
        const Radius.circular(2),
      ),
      rectPaint,
    );

    final triPath = Path();
    triPath.moveTo(size.width * 0.68, size.height * 0.55);
    triPath.lineTo(size.width * 0.75, size.height * 0.65);
    triPath.lineTo(size.width * 0.61, size.height * 0.65);
    triPath.close();
    canvas.drawPath(triPath, doodlePaint);

    final wavePath = Path();
    wavePath.moveTo(size.width * 0.05, size.height * 0.75);
    wavePath.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.7,
      size.width * 0.15,
      size.height * 0.75,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.8,
      size.width * 0.25,
      size.height * 0.75,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.7,
      size.width * 0.35,
      size.height * 0.75,
    );
    canvas.drawPath(wavePath, doodlePaint);

    final dotPaint = Paint()..color = const Color(0x14FFFFFF);
    canvas.drawCircle(
      Offset(size.width * 0.75, size.height * 0.35),
      2,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.35, size.height * 0.1),
      1.8,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.55),
      1.8,
      dotPaint,
    );

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.55, size.height * 0.75);
    checkPath.lineTo(size.width * 0.58, size.height * 0.78);
    checkPath.lineTo(size.width * 0.63, size.height * 0.68);
    canvas.drawPath(checkPath, doodlePaint);
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
  String? _profilePicUrl;
  String? _bannerUrl;
  bool _isDeploying = false;
  bool _isResetting = false;
  bool _isDeleting = false;
  final ImagePicker _picker = ImagePicker();

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
    _profilePicUrl = widget.existingAgent?.profilePic;
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
    };

    if (_platform == 'telegram') {
      payload['telegramToken'] = _tokenCtrl.text.trim();
    }

    bool success = false;
    if (widget.existingAgent != null) {
      success = await ApiService().updateAgent(
        widget.existingAgent!.id,
        payload,
      );
    } else {
      final result = await ApiService().createAgent(payload);
      success = result != null && result['success'] == true;
    }

    if (!mounted) return;
    setState(() => _isDeploying = false);

    if (success) {
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
          _openrouterController.text = settings['openrouterKey'] ?? '';
          _openaiController.text = settings['openaiKey'] ?? '';
          _anthropicController.text = settings['anthropicKey'] ?? '';
          _geminiController.text = settings['geminiKey'] ?? '';
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
