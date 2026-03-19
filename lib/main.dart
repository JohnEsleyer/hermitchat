import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  runApp(const HermitChatApp());
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

  Agent({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.model,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? 'Unknown',
      role: json['role']?.toString() ?? 'assistant',
      status: json['status']?.toString() ?? 'standby',
      model: json['model']?.toString() ?? 'unknown',
    );
  }
}

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });
}

final List<Agent> mockAgents = [
  Agent(
    id: '1',
    name: 'Ralph',
    role: 'code assistant',
    status: 'running',
    model: 'openai/gpt-4o',
  ),
  Agent(
    id: '2',
    name: 'Ava',
    role: 'data analyst',
    status: 'standby',
    model: 'anthropic/claude-3.5',
  ),
  Agent(
    id: '3',
    name: 'System',
    role: 'orchestrator',
    status: 'running',
    model: 'internal',
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
        const SnackBar(content: Text('Login failed. Check server URL and credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: const Color(0xFF09090B),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HermitMascot(size: 80, showGlow: true),
                const SizedBox(height: 24),
                const Text(
                  'hermitchat',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const Text(
                  'agent orchestration client',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 40),
                _buildTextField(
                  'Server IP / URL',
                  'e.g., http://192.168.1.5:3000',
                  false,
                  _ipCtrl,
                ),
                const SizedBox(height: 16),
                _buildTextField('Username', 'admin', false, _userCtrl),
                const SizedBox(height: 16),
                _buildTextField('Password', '••••••••', true, _passCtrl),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
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
                              fontSize: 16,
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

  Widget _buildTextField(String label, String hint, bool isPassword, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF52525B)),
            filled: true,
            fillColor: Colors.black,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: const BorderSide(color: Colors.white),
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
    const AgentsScreen(),
    const DashboardScreen(),
    SettingsScreen(onLogout: _handleLogout),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              icon: Icon(LucideIcons.settings),
              label: 'settings',
            ),
          ],
        ),
      ),
    );
  }
}

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  List<Agent> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final data = await ApiService().getAgents();
    if (mounted) {
      setState(() {
        _agents = data.map((json) => Agent.fromJson(json)).toList();
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
          child: Row(
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
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: const Icon(LucideIcons.search, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _agents.length,
            itemBuilder: (context, index) {
              final agent = _agents[index];
              final isRunning = agent.status == 'running';
              final lastMsg = ChatMessage(
                role: 'system', 
                content: 'Active connection to OS', 
                timestamp: DateTime.now(), 
                isRead: true
              );

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatScreen(agent: agent)),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1A1A1A), width: 0.5),
                    ),
                  ),
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
                            child: Text(
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
                                  color: const Color(0xFF10B981),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  agent.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '12:${30 + index} PM',
                                  style: const TextStyle(
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
                                    lastMsg.content.length > 40
                                        ? '${lastMsg.content.substring(0, 40)}...'
                                        : lastMsg.content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: lastMsg.isRead
                                          ? const Color(0xFF71717A)
                                          : Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!lastMsg.isRead)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'new',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              agent.model,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF52525B),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
  final List<ChatMessage> _messages = [];

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
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
    
    final response = await ApiService().sendMessage(widget.agent.id, text);
    if (!mounted) return;
    
    setState(() {
      if (response != null) {
        _messages.add(
          ChatMessage(
            role: 'assistant',
            content: response,
            timestamp: DateTime.now(),
            isRead: true,
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
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour == 0 ? 12 : hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

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
              alignment: Alignment.center,
              child: Text(
                widget.agent.name[0],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
            icon: const Icon(LucideIcons.moreVertical, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    Color tailColor;

    if (isUser) {
      bgColor = const Color(0xFF1A1A1A);
      textColor = Colors.white;
      tailColor = const Color(0xFF1A1A1A);
    } else if (isSystem) {
      bgColor = const Color(0xFF0A2A1A);
      textColor = const Color(0xFF6EE7B7);
      tailColor = const Color(0xFF0A2A1A);
    } else {
      bgColor = const Color(0xFF0F0F0F);
      textColor = const Color(0xFFE4E4E7);
      tailColor = const Color(0xFF0F0F0F);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 60 : 12,
        right: isUser ? 12 : 60,
        top: isFirst ? 8 : 2,
        bottom: 2,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
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
          ),
        ],
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
                  'XML',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF52525B),
                    letterSpacing: 1,
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
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      style: TextStyle(
                        fontFamily: _takeoverMode ? 'monospace' : null,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: _takeoverMode
                            ? 'Enter XML command...'
                            : 'Message...',
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
          ],
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _metrics;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
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
                      Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMetricCard(
                      'RAM',
                      memStr,
                      'gb',
                      LucideIcons.memoryStick,
                      Colors.white,
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
                    final c = containers[index];
                    final name = c['name']?.toString() ?? 'unknown';
                    final cCpu = c['cpu'] ?? 0.0;
                    final cMem = c['memory'] ?? 0.0;
                    
                    final cCpuStr = (cCpu is num) ? cCpu.toStringAsFixed(1) + '%' : '0.0%';
                    final cMemStr = (cMem is num) ? cMem.toStringAsFixed(0) + ' MB' : '0 MB';
                    
                    return _buildContainerRow(name, cCpuStr, cMemStr);
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

  Widget _buildContainerRow(String name, String cpu, String ram) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.box, size: 16, color: Colors.grey),
              const SizedBox(width: 12),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
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
  String _urlMode = 'tunnel';
  String _timeOffset = '0';

  final List<Map<String, String>> _timePresets = [
    {'label': 'UTC', 'value': '0', 'desc': 'London'},
    {'label': '+8h', 'value': '8', 'desc': 'Philippines'},
    {'label': '+9h', 'value': '9', 'desc': 'Tokyo'},
    {'label': '+1h', 'value': '1', 'desc': 'Paris'},
    {'label': '-5h', 'value': '-5', 'desc': 'New York'},
    {'label': '-8h', 'value': '-8', 'desc': 'Los Angeles'},
    {'label': '+5h', 'value': '5', 'desc': 'Dubai'},
    {'label': '+3h', 'value': '3', 'desc': 'Moscow'},
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
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _buildPublicUrlSection(),
                const SizedBox(height: 24),
                _buildApiKeysSection(),
                const SizedBox(height: 24),
                _buildTimeSettingsSection(),
                const SizedBox(height: 24),
                _buildCredentialsSection(),
                const SizedBox(height: 24),
                _buildBackupRestoreSection(),
                const SizedBox(height: 24),
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
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                title.toLowerCase(),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildPublicUrlSection() {
    return _buildSectionCard(
      title: 'Public URL Configuration',
      icon: LucideIcons.globe,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _urlMode = 'tunnel'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _urlMode == 'tunnel'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _urlMode == 'tunnel'
                            ? Colors.white
                            : const Color(0xFF27272A),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Cloudflare Tunnel',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _urlMode == 'tunnel'
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _urlMode = 'domain'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _urlMode == 'domain'
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _urlMode == 'domain'
                            ? Colors.white
                            : const Color(0xFF27272A),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Custom Domain',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _urlMode == 'domain'
                            ? Colors.black
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_urlMode == 'tunnel') ...[
            const Text(
              'The system automatically orchestrates cloudflared CLI to create a tunnel URL for the dashboard and agents.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT TUNNEL URL',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'https://mock-tunnel.trycloudflare.com',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.refreshCw,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Text(
              'Use your own domain or subdomain. The system will automatically configure Let\'s Encrypt for HTTPS.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            _buildTextField('Base Domain', 'e.g. mydomain.com', obscure: false),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Verify & Save',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
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
          ),
          const SizedBox(height: 16),
          _buildTextField('OpenAI API Key', 'sk-...', obscure: true),
          const SizedBox(height: 16),
          _buildTextField('Anthropic API Key', 'sk-ant-...', obscure: true),
          const SizedBox(height: 16),
          _buildTextField('Gemini API Key', 'AIza...', obscure: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
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
    return _buildSectionCard(
      title: 'System Time',
      icon: LucideIcons.clock,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'YOUR LOCAL TIME',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '10:42 AM',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF34D399),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PREVIEW (OFFSET)',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF93C5FD),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '10:42 AM',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          color: Color(0xFF93C5FD),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'SELECT YOUR TIMEZONE OFFSET FROM UTC',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _timePresets.length,
            itemBuilder: (context, index) {
              final preset = _timePresets[index];
              final isSelected = _timeOffset == preset['value'];
              return GestureDetector(
                onTap: () => setState(() => _timeOffset = preset['value']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset['label']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white,
                        ),
                      ),
                      Text(
                        preset['desc']!,
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white70 : Colors.grey,
                        ),
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

  Widget _buildCredentialsSection() {
    return _buildSectionCard(
      title: 'Account Credentials',
      icon: LucideIcons.user,
      child: Column(
        children: [
          _buildTextField('New Username', 'Enter new username', obscure: false),
          const SizedBox(height: 16),
          _buildTextField('New Password', 'Enter new password', obscure: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildBackupRestoreSection() {
    return _buildSectionCard(
      title: 'Backup & Restore',
      icon: LucideIcons.archive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.download, size: 16, color: Color(0xFF34D399)),
              SizedBox(width: 8),
              Text(
                'Export Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Download all your data including database, images, skills, agent configurations, and logs as a .zip file.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.download, size: 16),
            label: const Text(
              'Download Backup',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: Color(0xFF27272A)),
          ),
          const Row(
            children: [
              Icon(LucideIcons.upload, size: 16, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text(
                'Import Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  size: 16,
                  color: Color(0xFFFBBF24),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Warning: Importing a backup will overwrite existing data. This action cannot be undone.',
                    style: TextStyle(color: Color(0xFFFDE68A), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            'Your Password (required for security)',
            'Enter your password',
            obscure: true,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(LucideIcons.upload, size: 16),
            label: const Text(
              'Import Backup',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildTextField(String label, String hint, {required bool obscure}) {
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
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        TextField(
          obscureText: obscure,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF52525B)),
            filled: true,
            fillColor: Colors.black,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
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
