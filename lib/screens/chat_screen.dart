import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';

import '../providers/pharmacy_provider.dart';
import '../models/medicine.dart';
import 'medicine_detail_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'register_medicine_dialog.dart';
import 'report_screen.dart';
import 'audit_screen.dart';
import 'home_screen.dart';

enum MessageType { text, medicineCard }

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final MessageType type;

  _ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.type = MessageType.text,
  }) : timestamp = timestamp ?? DateTime.now();
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  int _selectedNavIndex = 1;
  bool _isLoading = false;
  Box<dynamic>? _chatBox;

  @override
  void initState() {
    super.initState();
    _loadCachedMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatBox?.close();
    super.dispose();
  }

  void _showDisclaimer() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Disclaimer',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This assistant provides inventory and sales information only. It cannot diagnose or recommend dosages. Consult a pharmacist or doctor for medical advice.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // chat persistence helpers
  // ---------------------------------------------------------------------------

  Future<void> _loadCachedMessages() async {
    _chatBox = await Hive.openBox('chat');
    final stored = _chatBox?.get('messages', defaultValue: <dynamic>[]) as List;
    if (stored.isNotEmpty) {
      setState(() {
        _messages.clear();
        for (final m in stored) {
          if (m is Map) {
            _messages.add(_messageFromMap(Map<String, dynamic>.from(m)));
          }
        }
      });
      _scrollToBottom();
    }
  }

  Map<String, dynamic> _messageToMap(_ChatMessage msg) {
    return {
      'text': msg.text,
      'isUser': msg.isUser,
      'timestamp': msg.timestamp.toIso8601String(),
      'type': msg.type.index,
    };
  }

  _ChatMessage _messageFromMap(Map<String, dynamic> map) {
    return _ChatMessage(
      text: map['text'] as String,
      isUser: map['isUser'] as bool,
      timestamp: DateTime.parse(map['timestamp'] as String),
      type: MessageType.values[map['type'] as int],
    );
  }

  void _saveMessages() {
    if (_chatBox == null) return;
    final list = _messages.map(_messageToMap).toList();
    _chatBox!.put('messages', list);
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final theme = Theme.of(context);
    final color = message.isUser ? const Color(0xFF007BFF) : Colors.grey[200]!;
    final textColor = message.isUser ? Colors.white : Colors.black;
    final time = DateFormat.Hm().format(message.timestamp);

    Widget bubbleContent() {
      if (message.type == MessageType.medicineCard) {
        // parse the response lines and render key/value pairs clearly
        final lines = message.text
            .split('\n')
            .map((l) => l.trim())
            .where((l) => l.isNotEmpty)
            .toList();
        final entries = lines.map((l) {
          if (l.contains(':')) {
            final idx = l.indexOf(':');
            return MapEntry(
              l.substring(0, idx).trim(),
              l.substring(idx + 1).trim(),
            );
          }
          return MapEntry('', l);
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: textColor,
                    ),
                    children: [
                      if (e.key.isNotEmpty)
                        TextSpan(
                          text: '${e.key}: ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      TextSpan(text: e.value),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.montserrat(
                fontSize: 10,
                color: message.isUser ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarkdownBody(
            data: message.text,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: GoogleFonts.montserrat(fontSize: 14, color: textColor),
            ),
            onTapLink: (text, href, title) {
              if (href != null) {
                launchUrl(Uri.parse(href));
              }
            },
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              color: message.isUser ? Colors.white70 : Colors.black54,
            ),
          ),
          if (!message.isUser &&
              (message.text.contains('Medicine Name:') ||
                  message.text.contains('Medicine:')))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      final lines = message.text.split('\n');
                      final medicineNameLine = lines.firstWhere(
                        (l) =>
                            l.startsWith('Medicine Name:') ||
                            l.startsWith('Medicine:'),
                        orElse: () => '',
                      );
                      if (medicineNameLine.isNotEmpty) {
                        var medName = medicineNameLine;
                        if (medName.startsWith('Medicine Name:')) {
                          medName = medName
                              .replaceFirst('Medicine Name:', '')
                              .trim();
                        } else if (medName.startsWith('Medicine:')) {
                          medName = medName
                              .replaceFirst('Medicine:', '')
                              .trim();
                          medName = medName.split('(barcode:').first.trim();
                        }
                        final provider = context.read<PharmacyProvider>();
                        final medicine = provider.medicines.firstWhere(
                          (m) => m.name == medName,
                          orElse: () => Medicine(
                            id: '',
                            name: '',
                            totalQty: 0,
                            buyPrice: 0,
                            sellPrice: 0,
                          ),
                        );
                        if (medicine.id.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  MedicineDetailScreen(medicine: medicine),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      'View Medicine',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      final lines = message.text.split('\n');
                      final medicineNameLine = lines.firstWhere(
                        (l) =>
                            l.startsWith('Medicine Name:') ||
                            l.startsWith('Medicine:'),
                        orElse: () => '',
                      );
                      if (medicineNameLine.isNotEmpty) {
                        var medName = medicineNameLine;
                        if (medName.startsWith('Medicine Name:')) {
                          medName = medName
                              .replaceFirst('Medicine Name:', '')
                              .trim();
                        } else if (medName.startsWith('Medicine:')) {
                          medName = medName
                              .replaceFirst('Medicine:', '')
                              .trim();
                          medName = medName.split('(barcode:').first.trim();
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ReportScreen()),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0069D9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                    ),
                    child: Text(
                      'Show Sales',
                      style: GoogleFonts.montserrat(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1),
      duration: const Duration(milliseconds: 250),
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            const CircleAvatar(
              radius: 12,
              child: Icon(Icons.android, size: 16),
            ),
            const SizedBox(width: 4),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(message.isUser ? 16 : 0),
                    bottomRight: Radius.circular(message.isUser ? 0 : 16),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: bubbleContent(),
              ),
              Positioned(
                bottom: 4,
                left: message.isUser ? null : -6,
                right: message.isUser ? -6 : null,
                child: CustomPaint(
                  size: const Size(12, 16),
                  painter: _TrianglePainter(
                    color: color,
                    isUser: message.isUser,
                  ),
                ),
              ),
            ],
          ),
          if (message.isUser) ...[
            const SizedBox(width: 4),
            const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 16)),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingMessage() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Thinking...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color.fromARGB(255, 8, 0, 21) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return context
                    .read<PharmacyProvider>()
                    .medicines
                    .map((m) => m.name)
                    .where(
                      (name) => name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                // keep controllers in sync
                controller.text = _messageController.text;
                controller.selection = _messageController.selection;
                controller.addListener(() {
                  _messageController.text = controller.text;
                  _messageController.selection = controller.selection;
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isDark
                        ? const Color.fromARGB(255, 232, 230, 230)
                        : const Color.fromRGBO(9, 1, 29, 1),
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'Describe medicine names or scan barcode (e.g. paracetamol)',
                    hintStyle: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: isDark
                          ? const Color.fromARGB(255, 241, 238, 238)
                          : const Color.fromARGB(255, 14, 14, 14),
                    ),
                    filled: !isDark,
                    fillColor: isDark ? Colors.transparent : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: isDark ? Colors.grey[500]! : Colors.grey[400]!,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                );
              },
              onSelected: (selection) {
                _messageController.text = selection;
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scan barcode',
            onPressed: _scanBarcode,
          ),
          const SizedBox(width: 4),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final messenger = ScaffoldMessenger.of(context);

    var status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for barcode scanning'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (context) => Dialog(
          child: SizedBox(
            height: 400,
            child: MobileScanner(
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final barcode = barcodes.first.rawValue;
                  if (barcode != null) {
                    Navigator.of(context).pop(barcode);
                  }
                }
              },
            ),
          ),
        ),
      );

      if (result != null) {
        // directly process the scanned string as a chat query
        _messageController.text = result;
        _sendMessage();
      }
    } catch (_) {
      // ignore scanner errors for now
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _messageController.clear();
    });
    _saveMessages();
    _scrollToBottom();

    try {
      final provider = context.read<PharmacyProvider>();
      final response = await provider.chatReply(text);
      final respType =
          (response.contains('Medicine Name:') ||
              response.contains('Medicine:'))
          ? MessageType.medicineCard
          : MessageType.text;
      setState(() {
        _messages.add(
          _ChatMessage(text: response, isUser: false, type: respType),
        );
      });
      _saveMessages();
    } catch (_) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text: 'There was an error processing your request.',
            isUser: false,
          ),
        );
      });
      _saveMessages();
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Medicine Assistant', style: GoogleFonts.montserrat()),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDisclaimer,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingMessage();
                }
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
      // register button is rendered inline inside CustomBottomNavBar
      bottomNavigationBar: CustomBottomNavBar(
        pharmacyProvider: context.watch<PharmacyProvider>(),
        selectedIndex: _selectedNavIndex,
        onSelect: (i) => setState(() => _selectedNavIndex = i),
        onHome: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        },
        onRegister: () {
          showModalBottomSheet<String>(
            context: context,
            isScrollControlled: true,
            builder: (context) => RegisterMedicineDialog(),
          );
        },
        onChat: () {},
        onReports: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportScreen()),
          );
        },
        onAudit: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AuditScreen()),
          );
        },
      ),
    );
  }
}

// small triangle tail painter used by bubbles
class _TrianglePainter extends CustomPainter {
  final bool isUser;
  final Color color;

  _TrianglePainter({required this.isUser, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isUser) {
      path.moveTo(0, 0);
      path.lineTo(size.width, size.height / 2);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(0, size.height / 2);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) {
    return old.color != color || old.isUser != isUser;
  }
}
