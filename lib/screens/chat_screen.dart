import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/pharmacy_provider.dart';
import '../models/medicine.dart';
import 'medicine_detail_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import 'register_medicine_dialog.dart';
import 'report_screen.dart';
import 'audit_screen.dart';
import 'home_screen.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  _ChatMessage({required this.text, required this.isUser});
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
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
          'This assistant provides general medicine suggestions only. Consult a pharmacist or doctor.',
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

  Widget _buildMessageBubble(_ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: message.isUser ? const Color(0xFF007BFF) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: GoogleFonts.montserrat(
                color: message.isUser ? Colors.white : Colors.black,
                fontSize: 14,
              ),
            ),
            if (!message.isUser && message.text.contains('Medicine Name:'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ElevatedButton(
                  onPressed: () {
                    final lines = message.text.split('\n');
                    final medicineNameLine = lines.firstWhere(
                      (l) => l.startsWith('Medicine Name:'),
                      orElse: () => '',
                    );
                    if (medicineNameLine.isNotEmpty) {
                      final medName = medicineNameLine
                          .replaceFirst('Medicine Name:', '')
                          .trim();
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
              ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Describe symptoms (e.g., headache, fever)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _sendMessage,
            mini: true,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isLoading = true;
      _messageController.clear();
    });
    _scrollToBottom();

    try {
      final provider = context.read<PharmacyProvider>();
      final response = await provider.recommendFromSymptoms(text.toLowerCase());
      setState(() {
        _messages.add(_ChatMessage(text: response, isUser: false));
      });
    } catch (_) {
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                "I'm not confident recommending a medicine. Please consult a pharmacist or doctor.",
            isUser: false,
          ),
        );
      });
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
