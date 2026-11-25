import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/settings_service.dart';

class AnonymousChatSheet extends StatefulWidget {
  const AnonymousChatSheet({super.key});

  @override
  State<AnonymousChatSheet> createState() => _AnonymousChatSheetState();
}

class _AnonymousChatSheetState extends State<AnonymousChatSheet> {
  final ApiService _api = ApiService();

  String _currentChannel = 'general';
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  late final TextEditingController _userCtrl;
  final TextEditingController _routeCtrl = TextEditingController();
  final TextEditingController _msgCtrl = TextEditingController();
  String _selectedStatus = 'Normal';
  bool _isPosting = false;

  final List<Map<String, String>> _channels = [
    {'id': 'general', 'name': '# ALL KOLKATA'},
    {'id': 'howrah', 'name': '# HOWRAH'},
    {'id': 'sealdah', 'name': '# SEALDAH & BYPASS'},
    {'id': 'metro', 'name': '# METRO ALERTS'},
    {'id': 'airport', 'name': '# AIRPORT / NORTH'},
  ];

  final List<Map<String, dynamic>> _statusTags = [
    {'name': 'Normal', 'label': '🟢 Smooth', 'color': Color(0xFF2E7D32)},
    {'name': 'Heavy Jam', 'label': '🔴 Heavy Jam', 'color': Color(0xFFC62828)},
    {'name': 'Bus Arrived', 'label': '🔵 Bus Arrived', 'color': Color(0xFF0277BD)},
    {'name': 'Crowded', 'label': '🟠 Huge Rush', 'color': Color(0xFFEF6C00)},
  ];

  @override
  void initState() {
    super.initState();
    // Default anonymous commuter handle (no login needed)
    final randId = (100 + (DateTime.now().millisecondsSinceEpoch % 900));
    _userCtrl = TextEditingController(text: 'Passenger_$randId');
    _loadMessages();
  }

  void _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await _api.getChatMessages(_currentChannel);
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);

    final success = await _api.postChatMessage(
      channel: _currentChannel,
      userName: _userCtrl.text.trim().isEmpty ? 'Passenger' : _userCtrl.text.trim(),
      routeRef: _routeCtrl.text.trim(),
      statusTag: _selectedStatus,
      message: text,
    );

    if (success) {
      _msgCtrl.clear();
      _loadMessages();
    }

    setState(() => _isPosting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SettingsService().currentTheme.lightBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.forum, color: SettingsService().currentTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Anonymous Commuter Chat', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          const SizedBox(width: 6),
                          Icon(Icons.shield_outlined, size: 14, color: SettingsService().currentTheme.primary),
                        ],
                      ),
                      const Text('No login required • Real-time Kolkata traffic & bus feed', style: TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Channel pills strip
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _channels.map((ch) {
                final active = _currentChannel == ch['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      setState(() => _currentChannel = ch['id']!);
                      _loadMessages();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? SettingsService().currentTheme.primary : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        ch['name']!,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 12),

          // Messages Feed
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: SettingsService().currentTheme.primary))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text('No alerts in #${_currentChannel.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Text('Be the first passenger to post traffic status below.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        itemCount: _messages.length,
                        itemBuilder: (context, idx) {
                          final m = _messages[idx];
                          Color statusColor = const Color(0xFF2E7D32);
                          Color statusBg = const Color(0xFFE8F5E9);

                          if (m.statusTag == 'Heavy Jam') {
                            statusColor = const Color(0xFFC62828);
                            statusBg = const Color(0xFFFFEBEE);
                          } else if (m.statusTag == 'Bus Arrived') {
                            statusColor = const Color(0xFF0277BD);
                            statusBg = const Color(0xFFE1F5FE);
                          } else if (m.statusTag == 'Crowded') {
                            statusColor = const Color(0xFFEF6C00);
                            statusBg = const Color(0xFFFFF3E0);
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0.8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Colors.grey[200]!),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 10,
                                            backgroundColor: SettingsService().currentTheme.primary.withAlpha(30),
                                            child: Icon(Icons.person, size: 12, color: SettingsService().currentTheme.primary),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(m.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                          const SizedBox(width: 4),
                                          Text('• ${m.timeStr}', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(4)),
                                        child: Text(m.statusTag, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                      ),
                                    ],
                                  ),
                                  if (m.routeRef.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(3)),
                                      child: Text('# ${m.routeRef}', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 10)),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(m.message, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Composer Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            hintText: 'Handle',
                            prefixIcon: Icon(Icons.badge_outlined, size: 14, color: Colors.grey),
                            prefixIconConstraints: BoxConstraints(minWidth: 20, minHeight: 20),
                          ),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _routeCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 6),
                            border: InputBorder.none,
                            hintText: 'Bus / Place (e.g. 215A, Ruby)',
                            hintStyle: TextStyle(fontSize: 11),
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Status Tag selector chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusTags.map((st) {
                      final isSel = _selectedStatus == st['name'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          onTap: () => setState(() => _selectedStatus = st['name']),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSel ? SettingsService().currentTheme.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isSel ? SettingsService().currentTheme.primary : Colors.grey[300]!),
                            ),
                            child: Text(
                              st['label'],
                              style: TextStyle(
                                color: isSel ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Message Text & Send Button
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: SettingsService().currentTheme.primary),
                        ),
                        child: TextField(
                          controller: _msgCtrl,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                            border: InputBorder.none,
                            hintText: 'Post live alert (e.g. 215A arrived at Howrah Bay 2)...',
                            hintStyle: TextStyle(fontSize: 12),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _isPosting ? null : _sendMessage,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: SettingsService().currentTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: _isPosting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
